"""Atomic, local checkpoints for interrupted workflows.

Checkpoints contain the full job settings, so secret fields are encrypted with
the same per-installation master key as settings.json.
"""

from __future__ import annotations

import copy
import json
import os
import re
import sys
from pathlib import Path
from typing import Any

from .secure_store import (
    CHECKPOINT_LLS_SECRET_PATHS,
    CHECKPOINT_SECRET_PATHS,
    SecretStoreError,
    encryption_available,
    protect_mapping,
    restrict_file_permissions,
    unprotect_mapping,
)


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
        # Version 3 stores the secret fields encrypted; 1 and 2 kept them in
        # plaintext and are migrated by load_checkpoints().
        "version": 3,
        "job_id": job.job_id,
        "files": job.files,
        "flags": vars(job.flags),
        "settings": _protect(job.settings.to_dict(), CHECKPOINT_SECRET_PATHS),
        "source": job.source,
        "cache_context": job.cache_context,
        "lls_output": (
            _protect(vars(job.lls_output), CHECKPOINT_LLS_SECRET_PATHS)
            if job.lls_output is not None else None
        ),
        "cleanup_paths": job.cleanup_paths,
        "created_at": job.created_at,
        "status": job.status,
        "results": [result.to_dict() for result in job.results],
    }
    if job.additional_context:
        payload["additional_context"] = job.additional_context
    temporary = folder / (NAME + ".tmp")
    temporary.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
    restrict_file_permissions(temporary)
    os.replace(temporary, target)


def _protect(data: dict[str, Any], paths: tuple[tuple[str, ...], ...]) -> dict[str, Any]:
    """Encrypt the secret fields of a checkpoint payload.

    A missing master key must not silently write plaintext, nor stop a running
    job from checkpointing: the affected credentials are omitted instead and a
    warning names the reason. Non-secret job state is always preserved.
    """
    try:
        return protect_mapping(data, paths)
    except SecretStoreError as exc:
        print(
            f"[secrets] 检查点中的凭据未保存（{exc}）",
            file=sys.stderr, flush=True,
        )
        cleaned = copy.deepcopy(data)
        for path in paths:
            _blank_path(cleaned, path)
        return cleaned


def _blank_path(data: dict[str, Any], path: tuple[str, ...]) -> None:
    current: Any = data
    for key in path[:-1]:
        if not isinstance(current, dict) or not isinstance(current.get(key), dict):
            return
        current = current[key]
    if isinstance(current, dict) and path[-1] in current:
        current[path[-1]] = ""


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
            if (not isinstance(raw, dict) or raw.get("version") not in (1, 2, 3)
                    or raw.get("job_id") != folder.name
                    or raw.get("status") not in {"queued", "running", "pausing", "paused"}
                    or not isinstance(raw.get("files"), list)
                    or not raw["files"]
                    or not all(isinstance(path, str) and path for path in raw["files"])):
                continue
            raw["settings"] = unprotect_mapping(raw.get("settings"), CHECKPOINT_SECRET_PATHS)
            if isinstance(raw.get("lls_output"), dict):
                raw["lls_output"] = unprotect_mapping(
                    raw["lls_output"], CHECKPOINT_LLS_SECRET_PATHS
                )
            checkpoints.append(raw)
        except (OSError, ValueError, TypeError):
            continue
    return checkpoints


def clear_checkpoint_secrets(work_dir: Path) -> int:
    """Re-save every checkpoint so legacy plaintext settings are encrypted."""
    updated = 0
    if not encryption_available() or not work_dir.is_dir():
        return 0
    for path in work_dir.rglob(NAME):
        try:
            raw = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(raw, dict):
                continue
            changed = False
            if isinstance(raw.get("settings"), dict):
                cleaned = protect_mapping(raw["settings"], CHECKPOINT_SECRET_PATHS)
                if cleaned != raw["settings"]:
                    raw["settings"] = cleaned
                    changed = True
            if isinstance(raw.get("lls_output"), dict):
                cleaned = protect_mapping(raw["lls_output"], CHECKPOINT_LLS_SECRET_PATHS)
                if cleaned != raw["lls_output"]:
                    raw["lls_output"] = cleaned
                    changed = True
            if not changed:
                continue
            raw["version"] = 3
            temporary = path.with_name(path.name + ".tmp")
            temporary.write_text(json.dumps(raw, ensure_ascii=False), encoding="utf-8")
            restrict_file_permissions(temporary)
            os.replace(temporary, path)
            updated += 1
        except SecretStoreError:
            # The master key is unavailable, so a plaintext checkpoint must not
            # be rewritten with blank credentials. Keep it for a later retry.
            continue
        except (OSError, ValueError, TypeError):
            continue
    return updated