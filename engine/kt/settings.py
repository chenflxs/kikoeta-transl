from __future__ import annotations

import json
import os
from pathlib import Path
from tempfile import NamedTemporaryFile
from threading import Lock

from .models import AppSettings
from .paths import DATA_DIR


SETTINGS_PATH = DATA_DIR / "settings.json"
DEFAULT_REMOTE_PASSWORD = AppSettings().remote_password
_SETTINGS_FILE_LOCK = Lock()


def load_settings() -> AppSettings:
    with _SETTINGS_FILE_LOCK:
        try:
            raw = SETTINGS_PATH.read_text(encoding="utf-8")
        except FileNotFoundError:
            return AppSettings()
    data = json.loads(raw)
    return AppSettings.from_dict(data)


def save_settings(settings: AppSettings) -> AppSettings:
    SETTINGS_PATH.parent.mkdir(parents=True, exist_ok=True)
    temporary: Path | None = None
    try:
        with NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=SETTINGS_PATH.parent,
            prefix=f".{SETTINGS_PATH.name}.", suffix=".tmp", delete=False,
        ) as file:
            temporary = Path(file.name)
            json.dump(settings.to_dict(), file, ensure_ascii=False, indent=2)
            file.flush()
            os.fsync(file.fileno())
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
