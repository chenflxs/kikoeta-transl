from __future__ import annotations

import json
import os
import shutil
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from threading import RLock
from typing import Any

from .paths import DATA_DIR


CACHE_DIR = DATA_DIR / "kikoeta_cache"
INDEX_PATH = CACHE_DIR / "index.json"
CACHE_LIMIT = 5
_LOCK = RLock()


def cache_completed_job(job: Any) -> int:
    """Persist LRC outputs for a completed task submitted by kikoeta."""
    if job.source != "kikoeta" or job.status != "completed":
        return 0

    work_id = str(job.cache_context.get("work_id") or "").strip().upper()
    track_paths = job.cache_context.get("track_paths")
    if not work_id or not isinstance(track_paths, list):
        return 0

    with _LOCK:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        temporary: Path | None = Path(
            tempfile.mkdtemp(prefix=f".{job.job_id}-", dir=CACHE_DIR)
        )
        files: list[dict[str, str]] = []
        try:
            for result_index, result in enumerate(job.results):
                track_path = (
                    str(track_paths[result_index])
                    if result_index < len(track_paths)
                    else ""
                )
                if not track_path:
                    continue
                for output_index, output in enumerate(result.outputs):
                    source = Path(output)
                    if source.suffix.lower() != ".lrc" or not source.is_file():
                        continue
                    stored_name = (
                        f"{result_index:03d}-{output_index:03d}-{_safe_name(source.name)}"
                    )
                    shutil.copy2(source, temporary / stored_name)
                    files.append(
                        {
                            "track_path": track_path,
                            "name": source.name,
                            "stored_name": stored_name,
                        }
                    )
            if not files:
                return 0

            destination = CACHE_DIR / job.job_id
            if destination.exists():
                shutil.rmtree(destination)
            os.replace(temporary, destination)
            temporary = None

            records = [
                record
                for record in _load_records()
                if record.get("job_id") != job.job_id
            ]
            records.insert(
                0,
                {
                    "job_id": job.job_id,
                    "work_id": work_id,
                    "completed_at": datetime.now(timezone.utc).isoformat(
                        timespec="seconds"
                    ),
                    "files": files,
                },
            )
            for record in records[CACHE_LIMIT:]:
                _remove_job_files(str(record.get("job_id") or ""))
            _save_records(records[:CACHE_LIMIT])
            return len(files)
        finally:
            if temporary is not None and temporary.exists():
                shutil.rmtree(temporary, ignore_errors=True)


def list_cached_results() -> list[dict[str, Any]]:
    with _LOCK:
        records = _load_records()
        valid = [record for record in records if _valid_record(record)]
        if valid != records:
            _save_records(valid)
        return [
            {
                "job_id": record["job_id"],
                "work_id": record["work_id"],
                "completed_at": record["completed_at"],
                "files": [
                    {
                        "track_path": item["track_path"],
                        "name": item["name"],
                    }
                    for item in record["files"]
                ],
            }
            for record in valid
        ]


def cached_file(job_id: str, index: int) -> Path:
    with _LOCK:
        for record in _load_records():
            if record.get("job_id") != job_id or not _valid_record(record):
                continue
            files = record["files"]
            if index < 0 or index >= len(files):
                break
            target = (CACHE_DIR / job_id / files[index]["stored_name"]).resolve()
            root = (CACHE_DIR / job_id).resolve()
            if root not in target.parents or not target.is_file():
                break
            return target
    raise FileNotFoundError(job_id)


def _load_records() -> list[dict[str, Any]]:
    try:
        raw = json.loads(INDEX_PATH.read_text(encoding="utf-8"))
        return raw if isinstance(raw, list) else []
    except (OSError, ValueError):
        return []


def _save_records(records: list[dict[str, Any]]) -> None:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    temporary = INDEX_PATH.with_suffix(".tmp")
    temporary.write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding="utf-8")
    os.replace(temporary, INDEX_PATH)


def _valid_record(record: object) -> bool:
    if not isinstance(record, dict):
        return False
    job_id = record.get("job_id")
    work_id = record.get("work_id")
    completed_at = record.get("completed_at")
    files = record.get("files")
    if not all(isinstance(value, str) and value for value in (job_id, work_id, completed_at)):
        return False
    if not isinstance(files, list) or not files:
        return False
    for item in files:
        if not isinstance(item, dict):
            return False
        if not all(isinstance(item.get(key), str) and item[key] for key in ("track_path", "name", "stored_name")):
            return False
        target = (CACHE_DIR / job_id / item["stored_name"]).resolve()
        root = (CACHE_DIR / job_id).resolve()
        if root not in target.parents or not target.is_file():
            return False
    return True


def _remove_job_files(job_id: str) -> None:
    if job_id and "/" not in job_id and "\\" not in job_id:
        shutil.rmtree(CACHE_DIR / job_id, ignore_errors=True)


def _safe_name(value: str) -> str:
    return "".join("_" if char in '<>:"/\\|?*' else char for char in value)
