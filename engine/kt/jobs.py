from __future__ import annotations

import uuid
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from threading import Event, Thread
from typing import Any

from .events import EventBus
from .models import AppSettings, FileResult, JobRequest, StageFlags
from .paths import WORK_DIR
from .pipeline import process_file
from .settings import load_settings, merge_settings


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


@dataclass
class Job:
    job_id: str
    files: list[str]
    flags: StageFlags
    settings: AppSettings
    status: str = "queued"
    created_at: str = field(default_factory=_now)
    results: list[FileResult] = field(default_factory=list)
    error: str = ""
    bus: EventBus = field(default_factory=EventBus)
    stop_event: Event = field(default_factory=Event)

    def to_dict(self) -> dict[str, Any]:
        return {
            "job_id": self.job_id,
            "files": self.files,
            "flags": asdict(self.flags),
            "status": self.status,
            "created_at": self.created_at,
            "results": [item.to_dict() for item in self.results],
            "error": self.error,
        }


class JobManager:
    def __init__(self) -> None:
        self._jobs: dict[str, Job] = {}

    def create(self, request: JobRequest) -> Job:
        files = [path for path in request.files if str(path).strip()]
        if not files:
            raise ValueError("没有输入文件")
        settings = merge_settings(load_settings(), request.settings_override)
        job = Job(
            job_id=uuid.uuid4().hex[:12],
            files=files,
            flags=request.flags,
            settings=settings,
        )
        self._jobs[job.job_id] = job
        thread = Thread(target=self._run, args=(job,), daemon=True)
        thread.start()
        return job

    def get(self, job_id: str) -> Job | None:
        return self._jobs.get(job_id)

    def list(self) -> list[Job]:
        return list(self._jobs.values())

    def cancel(self, job_id: str) -> Job:
        job = self._jobs.get(job_id)
        if job is None:
            raise KeyError(job_id)
        job.stop_event.set()
        job.bus.emit("log", message="收到取消请求")
        return job

    def _run(self, job: Job) -> None:
        job.status = "running"
        job.bus.emit("status", stage="running", message="任务开始")
        job_dir = WORK_DIR / job.job_id
        job_dir.mkdir(parents=True, exist_ok=True)
        try:
            for path in job.files:
                if job.stop_event.is_set():
                    break
                file_dir = job_dir / Path(path).stem
                file_dir.mkdir(parents=True, exist_ok=True)
                result = process_file(
                    path=path,
                    settings=job.settings,
                    flags=job.flags,
                    job_dir=file_dir,
                    emit=job.bus.emit,
                    stop_event=job.stop_event,
                )
                job.results.append(result)
            if job.stop_event.is_set():
                job.status = "cancelled"
            elif any(item.status == "failed" for item in job.results):
                job.status = "failed"
            else:
                job.status = "completed"
        except Exception as exc:
            job.status = "failed"
            job.error = str(exc)
            job.bus.emit("log", message=str(exc))
        finally:
            job.bus.emit("job_done", status=job.status)
            job.bus.close()
