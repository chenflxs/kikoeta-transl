from __future__ import annotations

import subprocess
from pathlib import Path

from ..models import AppSettings
from ..tools import popen_kwargs, resolve_ffmpeg


def transcode_to_wav(input_path: str, work_dir: Path, settings: AppSettings) -> Path:
    ffmpeg, _ffprobe = resolve_ffmpeg(settings)
    work_dir.mkdir(parents=True, exist_ok=True)
    output = work_dir / f"{Path(input_path).stem}.16k.wav"
    command = [
        ffmpeg,
        "-y",
        "-i",
        str(input_path),
        "-acodec",
        "pcm_s16le",
        "-ac",
        "1",
        "-ar",
        "16000",
        str(output),
    ]
    result = subprocess.run(
        command,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        **popen_kwargs(),
    )
    if result.returncode != 0 or not output.is_file():
        detail = (result.stderr or result.stdout or "").strip()
        raise RuntimeError(f"ffmpeg 转码失败: {detail or result.returncode}")
    return output
