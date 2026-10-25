"""Atomic, local checkpoints for interrupted workflows."""

from __future__ import annotations

import json
import os
import re
from pathlib import Path
from typing import Any


NAME = ".checkpoint.json"
_JOB_ID = re.compile(r"[0-9a-f]{12}\Z")


def save_checkpoint(job: Any, work_dir: Path) -> None:
    # Tests and old callers may run an ad-hoc job without a managed ID.
    if not _JOB_ID.fullmatch(job.job_id):
        return
    folder = work_dir / job.job_id
    folder.mkdir(parents=True, exist_ok=True)
    target = folder / NAME
    if job.status in {"completed", "failed", "cancelled"}:
        target.unlink(missing_ok=True)
        return
    payload = {
        "version": 1,
        "job_id": job.job_id,
        "files": job.files,
        "flags": vars(job.flags),
        "settings": job.settings.to_dict(),
        "source": job.source,
        "cache_context": job.cache_context,
        "lls_output": vars(job.lls_output) if job.lls_output is not None else None,
        "cleanup_paths": job.cleanup_paths,
        "created_at": job.created_at,
        "status": job.status,
        "results": [result.to_dict() for result in job.results],
    }
    temporary = folder / (NAME + ".tmp")
    temporary.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
    os.replace(temporary, target)


def load_checkpoints(work_dir: Path) -> list[dict[str, Any]]:
    if not work_dir.is_dir():
        return []
    checkpoints = []
    for folder in work_dir.iterdir():
        if (not _JOB_ID.fullmatch(folder.name) or not folder.is_dir()
                or folder.is_symlink() or folder.resolve().parent != work_dir.resolve()):
            continue
        try:
            raw = json.loads((folder / NAME).read_text(encoding="utf-8"))
            if (not isinstance(raw, dict) or raw.get("version") != 1
                    or raw.get("job_id") != folder.name
                    or raw.get("status") not in {"queued", "running", "pausing", "paused"}
                    or not isinstance(raw.get("files"), list)
                    or not raw["files"]
                    or not all(isinstance(path, str) and path for path in raw["files"])):
                continue
            checkpoints.append(raw)
        except (OSError, ValueError, TypeError):
            continue
    return checkpoints
