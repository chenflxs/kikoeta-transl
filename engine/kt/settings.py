from __future__ import annotations

import json
import os
from pathlib import Path
from tempfile import NamedTemporaryFile
from threading import Lock

from .models import AppSettings
from .paths import DATA_DIR
from .secure_store import (
    SETTINGS_SECRET_PATHS,
    SecretStoreError,
    encryption_available,
    needs_encryption,
    protect_with_fallback,
    restrict_file_permissions,
    unprotect_mapping,
)


SETTINGS_PATH = DATA_DIR / "settings.json"
DEFAULT_REMOTE_PASSWORD = AppSettings().remote_password
_SETTINGS_FILE_LOCK = Lock()


def load_settings() -> AppSettings:
    with _SETTINGS_FILE_LOCK:
        try:
            raw = SETTINGS_PATH.read_text(encoding="utf-8")
        except FileNotFoundError:
            return AppSettings()
    try:
        data = json.loads(raw)
    except ValueError:
        return AppSettings()
    if not isinstance(data, dict):
        return AppSettings()
    plaintext = encryption_available() and needs_encryption(data, SETTINGS_SECRET_PATHS)
    settings = AppSettings.from_dict(unprotect_mapping(data, SETTINGS_SECRET_PATHS))
    if plaintext:
        # Migrate an older plaintext file in place so the secrets are covered
        # from the first read instead of only after the next UI save.
        try:
            save_settings(settings)
        except (OSError, SecretStoreError):
            pass
    return settings


def _read_stored() -> dict:
    """Read the current on-disk settings, used to preserve unreadable secrets."""
    with _SETTINGS_FILE_LOCK:
        try:
            raw = SETTINGS_PATH.read_text(encoding="utf-8")
        except OSError:
            return {}
    try:
        data = json.loads(raw)
    except ValueError:
        return {}
    return data if isinstance(data, dict) else {}


def save_settings(settings: AppSettings) -> AppSettings:
    SETTINGS_PATH.parent.mkdir(parents=True, exist_ok=True)
    payload = protect_with_fallback(
        settings.to_dict(), SETTINGS_SECRET_PATHS, _read_stored(),
    )
    temporary: Path | None = None
    try:
        with NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=SETTINGS_PATH.parent,
            prefix=f".{SETTINGS_PATH.name}.", suffix=".tmp", delete=False,
        ) as file:
            temporary = Path(file.name)
            json.dump(payload, file, ensure_ascii=False, indent=2)
            file.flush()
            os.fsync(file.fileno())
        restrict_file_permissions(temporary)
        # Windows can reject replacement while another thread reads or replaces
        # the destination. The temporary file itself is private to this save.
        with _SETTINGS_FILE_LOCK:
            os.replace(temporary, SETTINGS_PATH)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    return settings


def merge_settings(base: AppSettings, override: dict | None) -> AppSettings:
    if not override:
        return base
    merged = base.to_dict()
    _deep_update(merged, override)
    return AppSettings.from_dict(merged)


def _deep_update(target: dict, extra: dict) -> None:
    for key, value in extra.items():
        if isinstance(value, dict) and isinstance(target.get(key), dict):
            _deep_update(target[key], value)
        else:
            target[key] = value
