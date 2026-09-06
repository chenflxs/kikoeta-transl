from __future__ import annotations

import json
from .models import AppSettings
from .paths import DATA_DIR


SETTINGS_PATH = DATA_DIR / "settings.json"


def load_settings() -> AppSettings:
    if not SETTINGS_PATH.is_file():
        return AppSettings()
    data = json.loads(SETTINGS_PATH.read_text(encoding="utf-8"))
    return AppSettings.from_dict(data)


def save_settings(settings: AppSettings) -> AppSettings:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    SETTINGS_PATH.write_text(
        json.dumps(settings.to_dict(), ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
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
