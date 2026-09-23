from __future__ import annotations

import json
import os
import re
import shutil
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .paths import WORK_DIR


_JOB_ID = re.compile(r"[0-9a-f]{12}\Z")
_RECORD = ".recent.json"


def record_finished_job(job: Any) -> None:
    """Keep a small result index without copying exported files into the cache."""
    if not job.flags.enable_translate or not _JOB_ID.fullmatch(job.job_id):
        return
    folder = WORK_DIR / job.job_id
    if not folder.is_dir() or folder.is_symlink() or folder.resolve().parent != WORK_DIR.resolve():
        return
    outputs = [output for result in job.results for output in result.outputs]
    if not outputs and not _cache_dirs(folder):
        return
    record = {
        "job_id": job.job_id,
        "source": job.source,
        "status": job.status,
        "created_at": job.created_at,
        "finished_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "files": [Path(path).name for path in job.files],
        "outputs": outputs,
    }
    target = folder / _RECORD
    temporary = folder / f"{_RECORD}.tmp"
    temporary.write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding="utf-8")
    os.replace(temporary, target)


def list_recent_jobs(active_ids: set[str] | None = None) -> list[dict[str, Any]]:
    if not WORK_DIR.is_dir():
        return []
    entries = []
    for folder in WORK_DIR.iterdir():
        if (not folder.is_dir() or folder.is_symlink()
                or not _JOB_ID.fullmatch(folder.name)
                or folder.resolve().parent != WORK_DIR.resolve()):
            continue
        if active_ids and folder.name in active_ids:
            continue
        try:
            record = json.loads((folder / _RECORD).read_text(encoding="utf-8"))
            if not isinstance(record, dict) or record.get("job_id") != folder.name:
                record = None
        except (OSError, ValueError):
            record = None
        caches = _cache_dirs(folder)
        if record is None and not caches:
            continue
        outputs = record.get("outputs", []) if record else []
        if not isinstance(outputs, list):
            outputs = []
        # Older tasks had no result index. Their GalTransl JSON is still
        # viewable, even when the final LRC/SRT path can no longer be found.
        if record is None:
            outputs = [str(path / "gt_output" / "cues.json") for path in caches
                       if (path / "gt_output" / "cues.json").is_file()]
        entries.append({
            "job_id": folder.name,
            "source": str(record.get("source") or "") if record else "",
            "status": str(record.get("status") or "") if record else "",
            "created_at": str(record.get("created_at") or "") if record else "",
            "finished_at": str(record.get("finished_at") or "") if record else "",
            "files": record.get("files", []) if record else [path.parent.name for path in caches],
            "outputs": [
                {"path": path, "exists": Path(path).is_file()}
                for path in outputs if isinstance(path, str) and path
            ],
            "cache_bytes": sum(_directory_bytes(path) for path in caches),
            "cache_dir_count": len(caches),
            "sort_time": (record.get("finished_at") if record else None)
                         or datetime.fromtimestamp(folder.stat().st_mtime, timezone.utc).isoformat(),
        })
    entries.sort(key=lambda entry: entry["sort_time"], reverse=True)
    for entry in entries:
        del entry["sort_time"]
    return entries


def delete_translation_cache(job_id: str) -> int:
    if not _JOB_ID.fullmatch(job_id):
        raise ValueError("invalid job id")
    folder = WORK_DIR / job_id
    if not folder.is_dir() or folder.is_symlink() or folder.resolve().parent != WORK_DIR.resolve():
        raise FileNotFoundError(job_id)
    caches = _cache_dirs(folder)
    if not caches and not (folder / _RECORD).is_file():
        raise FileNotFoundError(job_id)
    freed = sum(_directory_bytes(path) for path in caches)
    for path in caches:
        shutil.rmtree(path)
    return freed


def _cache_dirs(folder: Path) -> list[Path]:
    root = folder.resolve()
    caches = []
    for child in folder.iterdir():
        if not child.is_dir() or child.is_symlink():
            continue
        if child.resolve().parent != root:
            continue
        target = child / "gt"
        if not target.is_dir() or target.is_symlink():
            continue
        if target.resolve() != child.resolve() / "gt":
            continue
        caches.append(target)
    return caches


def _directory_bytes(folder: Path) -> int:
    size = 0
    for root, dirs, files in os.walk(folder, followlinks=False):
        dirs[:] = [name for name in dirs if not (Path(root) / name).is_symlink()]
        for name in files:
            path = Path(root) / name
            if not path.is_symlink():
                try:
                    size += path.stat().st_size
                except OSError:
                    pass
    return size
