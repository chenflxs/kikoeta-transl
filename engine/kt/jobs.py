from __future__ import annotations

import hashlib
import json
import uuid
from contextlib import nullcontext
from dataclasses import asdict, dataclass, field, replace
from datetime import datetime, timezone
from pathlib import Path
from threading import Event, RLock, Thread
from typing import Any

from .cleanup import cleanup_intermediates
from .events import EventBus
from .job_checkpoint import load_checkpoints, save_checkpoint
from .kikoeta_cache import cache_completed_job
from .llama_runtime import LLAMA_RUNTIME
from .lls_sync import sync_completed_job
from .models import AppSettings, FileResult, JobRequest, OutputSettings, StageFlags
from .paths import SUBTITLE_EXTS, WORK_DIR
from .pipeline import process_file
from .recent import record_finished_job
from .settings import load_settings, merge_settings


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _pending_result(path: str) -> FileResult:
    kind = "subtitle" if Path(path).suffix.lower() in SUBTITLE_EXTS else "media"
    return FileResult(path=path, kind=kind)


@dataclass
class Job:
    job_id: str
    files: list[str]
    flags: StageFlags
    settings: AppSettings
    source: str = "desktop"
    cache_context: dict[str, Any] = field(default_factory=dict)
    lls_output: OutputSettings | None = None
    cleanup_paths: list[str] = field(default_factory=list)
    status: str = "queued"
    created_at: str = field(default_factory=_now)
    results: list[FileResult] = field(default_factory=list)
    error: str = ""
    bus: EventBus = field(default_factory=EventBus)
    stop_event: Event = field(default_factory=Event)
    _finalizing: bool = field(default=False, repr=False)

    @property
    def is_unfinished(self) -> bool:
        return self._finalizing or self.status in {"queued", "running", "pausing", "paused", "cancelling"}

    def to_dict(self) -> dict[str, Any]:
        return {
            "job_id": self.job_id,
            "files": self.files,
            "flags": asdict(self.flags),
            "source": self.source,
            "status": "running" if self._finalizing else self.status,
            "created_at": self.created_at,
            "results": [item.to_dict() for item in self.results],
            "error": self.error,
            "work_id": str(self.cache_context.get("work_id") or ""),
            "completed_files": sum(item.status == "done" for item in self.results),
            "total_files": len(self.files),
            "event_cursor": self.bus.cursor,
        }


def _resume_key(job: Job) -> str:
    paths = job.cache_context.get("track_paths")
    work_id = str(job.cache_context.get("work_id") or "").strip().upper()
    if job.source == "kikoeta":
        if not work_id or not isinstance(paths, list) or len(paths) != len(job.files):
            return ""
    else:
        paths = [str(Path(path).resolve()) for path in job.files]
    settings = job.settings.to_dict()
    # Presentation and listener credentials do not affect generated subtitles.
    for key in ("theme", "remote_access", "remote_username", "remote_password"):
        settings.pop(key, None)
    raw = [job.source, work_id, paths, asdict(job.flags), settings]
    return hashlib.sha256(json.dumps(raw, sort_keys=True, ensure_ascii=False).encode()).hexdigest()


class JobManager:
    def __init__(self) -> None:
        self._jobs: dict[str, Job] = {}
        self._lock = RLock()
        self._active: Job | None = None
        self._closing = False
        for raw in load_checkpoints(WORK_DIR):
            try:
                job = Job(
                    job_id=raw["job_id"], files=raw["files"],
                    flags=StageFlags(**raw["flags"]),
                    settings=AppSettings.from_dict(raw["settings"]),
                    source=raw.get("source", "desktop"),
                    cache_context=dict(raw.get("cache_context") or {}),
                    lls_output=OutputSettings(**raw["lls_output"]) if raw.get("lls_output") else None,
                    cleanup_paths=list(raw.get("cleanup_paths") or []),
                    created_at=raw["created_at"], status="paused",
                    results=[FileResult(**item) for item in raw.get("results", [])],
                )
                self._repair_results(job)
                job.bus.close()
                self._jobs[job.job_id] = job
            except (KeyError, TypeError, ValueError):
                continue

    def create(self, request: JobRequest, *, source: str = "desktop", resume_existing: bool = True) -> Job:
        files = [path for path in request.files if str(path).strip()]
        if not files:
            raise ValueError("没有输入文件")
        saved_settings = load_settings()
        candidate = Job(
            job_id=uuid.uuid4().hex[:12], files=files, flags=request.flags,
            settings=merge_settings(saved_settings, request.settings_override), source=source,
            cache_context=dict(request.cache_context),
            lls_output=saved_settings.output if source == "kikoeta" else None,
            cleanup_paths=list(request.cleanup_paths),
            results=[_pending_result(path) for path in files],
        )
        with self._lock:
            self._ensure_available()
            job = candidate
            if resume_existing:
                key = _resume_key(candidate)
                job = next((item for item in self._jobs.values()
                            if item.status == "paused" and key and _resume_key(item) == key), candidate)
            self._repair_results(job)
            if job is not candidate:
                self._reuse_uploads(job, candidate)
            self._jobs[job.job_id] = job
            self._start(job)
            return job

    def resume(self, job_id: str) -> Job:
        with self._lock:
            job = self._require(job_id)
            self._ensure_available()
            if job.status != "paused":
                raise RuntimeError("只有已暂存的任务可以继续")
            self._repair_results(job)
            if any(result.status not in {"done", "failed"} and not Path(result.path).is_file()
                   for result in job.results):
                raise ValueError("暂存任务的输入文件已丢失，请重新导入")
            self._start(job)
            return job

    def get(self, job_id: str) -> Job | None:
        with self._lock:
            return self._jobs.get(job_id)

    def list(self) -> list[Job]:
        with self._lock:
            return list(self._jobs.values())

    def shutdown(self) -> None:
        """Preserve the interrupted workflow when the engine exits."""
        with self._lock:
            self._closing = True
            if self._active is not None and self._active.status in {"running", "queued"}:
                self.preempt(self._active.job_id)

    def preempt(self, job_id: str) -> Job:
        with self._lock:
            job = self._require(job_id)
            if job.status in {"pausing", "paused"}:
                return job
            if job is not self._active or job.status not in {"running", "queued"}:
                raise RuntimeError("任务已结束，无法暂存")
            job.status = "pausing"
            job.stop_event.set()
            job.bus.emit("status", stage="pausing", message="正在暂存当前任务")
            save_checkpoint(job, WORK_DIR)
            return job

    def cancel(self, job_id: str) -> Job:
        with self._lock:
            job = self._require(job_id)
            if job.status in {"completed", "failed", "cancelled"}:
                return job
            job.stop_event.set()
            if job is self._active:
                job.status = "cancelling"
                job.bus.emit("status", stage="cancelling", message="正在停止当前阶段")
            else:
                job.status = "cancelled"
                self._finish(job)
            return job

    def _require(self, job_id: str) -> Job:
        job = self._jobs.get(job_id)
        if job is None:
            raise KeyError(job_id)
        return job

    def _ensure_available(self) -> None:
        if self._closing:
            raise RuntimeError("引擎正在关闭")
        if self._active is not None:
            raise RuntimeError("已有工作流正在处理，请先暂存或取消当前工作流")

    def _start(self, job: Job) -> None:
        job.stop_event.clear()
        job.bus.reopen()
        job.status = "running"
        job.error = ""
        save_checkpoint(job, WORK_DIR)
        self._active = job
        Thread(target=self._run, args=(job,), daemon=True, name=f"workflow-{job.job_id}").start()

    @staticmethod
    def _repair_results(job: Job) -> None:
        while len(job.results) < len(job.files):
            job.results.append(_pending_result(job.files[len(job.results)]))
        for index, result in enumerate(job.results):
            if (result.status not in {"done", "failed"}
                    or (result.status == "done" and any(not Path(path).is_file() for path in result.outputs))):
                job.results[index] = _pending_result(job.files[index])

    @staticmethod
    def _reuse_uploads(job: Job, candidate: Job) -> None:
        old_paths = job.cleanup_paths
        if any(result.status not in {"done", "failed"} and not Path(result.path).is_file()
               for result in job.results):
            # A new request can restore inputs deleted outside the application.
            job.files = candidate.files
            job.cleanup_paths = candidate.cleanup_paths
            for index, result in enumerate(job.results):
                result.path = job.files[index]
            obsolete = [path for path in old_paths if path not in job.cleanup_paths]
        else:
            obsolete = [path for path in candidate.cleanup_paths if path not in old_paths]
        cleanup_intermediates(*obsolete)

    def _run(self, job: Job) -> None:
        # Also supports the existing direct runner used by CLI-level tests.
        try:
            with self._lock:
                if not job.stop_event.is_set():
                    job.status = "running"
                self._repair_results(job)
                save_checkpoint(job, WORK_DIR)
            if not job.stop_event.is_set():
                job.bus.emit("status", stage="running", message="任务开始")
            job_dir = WORK_DIR / job.job_id
            job_dir.mkdir(parents=True, exist_ok=True)
            uses_local_llama = (
                (job.flags.enable_translate and job.settings.translate.provider == "local_llama")
                or (job.flags.enable_correct and (
                    job.settings.correct.provider == "local_llama"
                    or job.settings.translate.provider == "local_llama")))
            with LLAMA_RUNTIME.job_scope() if uses_local_llama else nullcontext():
                for index, path in enumerate(job.files):
                    if job.stop_event.is_set():
                        break
                    if job.results[index].status in {"done", "failed"}:
                        continue
                    file_dir = job_dir / f"{index:04d}_{Path(path).stem}"
                    file_dir.mkdir(parents=True, exist_ok=True)
                    settings = job.settings
                    if job.cleanup_paths:
                        settings = replace(settings, output=replace(settings.output, directory=str(file_dir / "outputs")))
                    result = process_file(path=path, settings=settings, flags=job.flags,
                                          job_dir=file_dir, emit=job.bus.emit, stop_event=job.stop_event)
                    with self._lock:
                        if result.status != "cancelled" or job.status != "pausing":
                            job.results[index] = result
                        save_checkpoint(job, WORK_DIR)
            with self._lock:
                pending = any(item.status not in {"done", "failed"} for item in job.results)
                if pending and job.status == "pausing":
                    # Remain pausing until checkpoint and event finalization finish.
                    pass
                elif job.stop_event.is_set() and pending:
                    job.status = "cancelled"
                elif any(item.status == "failed" for item in job.results):
                    job.status = "failed"
                else:
                    job.status = "completed"
                job._finalizing = job.status in {"completed", "failed", "cancelled"}
        except Exception as exc:
            with self._lock:
                if job.status != "pausing":
                    job.status = "failed"
                    job._finalizing = True
                job.error = str(exc)
            job.bus.emit("log", message=str(exc))
        finally:
            self._finish(job)

    def _finish(self, job: Job) -> None:
        with self._lock:
            if job.status == "cancelling":
                job.status = "cancelled"
                job._finalizing = True
            if job.status == "pausing":
                # Publish paused only after the workflow has stopped touching
                # its state. A new create/cancel may act on it immediately.
                job.status = "paused"
                self._close_run(job)
                return
        if job.status != "paused":
            try:
                cached = cache_completed_job(job)
                if cached:
                    job.bus.emit("log", message=f"已缓存 {cached} 个 kikoeta 歌词结果")
            except Exception as exc:
                job.bus.emit("log", message=f"保存 kikoeta 缓存失败：{exc}")
            try:
                uploaded = sync_completed_job(job, job.lls_output) if job.lls_output is not None else 0
                if uploaded:
                    job.bus.emit("log", message=f"已同步 {uploaded} 个歌词文件到 Kikoeta-LLS")
            except Exception as exc:
                job.bus.emit("log", message=f"同步到 Kikoeta-LLS 失败：{exc}")
            try:
                record_finished_job(job)
            except Exception as exc:
                job.bus.emit("log", message=f"保存最近任务记录失败：{exc}")
            cleanup_intermediates(*job.cleanup_paths)
        with self._lock:
            self._close_run(job)

    def _close_run(self, job: Job) -> None:
        try:
            save_checkpoint(job, WORK_DIR)
        finally:
            if self._active is job:
                self._active = None
            job._finalizing = False
            job.bus.emit("job_done", status=job.status)
            job.bus.close()
