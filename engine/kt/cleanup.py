from __future__ import annotations

import shutil
from pathlib import Path


def remove_path(path: str | Path) -> None:
    target = Path(path)
    try:
        if target.is_file():
            target.unlink()
        elif target.is_dir():
            shutil.rmtree(target, ignore_errors=True)
    except OSError:
        pass


def cleanup_intermediates(*paths: str | Path) -> None:
    for path in paths:
        if path:
            remove_path(path)
