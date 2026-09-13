from __future__ import annotations

import subprocess
from pathlib import Path
from threading import Event

from ..cancellation import TaskCancelled, raise_if_cancelled, terminate_process
from ..models import AppSettings
from ..tools import popen_kwargs, resolve_ffmpeg


def transcode_to_wav(
    input_path: str,
    work_dir: Path,
    settings: AppSettings,
    *,
    stop_event: Event | None = None,
) -> Path:
    raise_if_cancelled(stop_event)
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
    process = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        **popen_kwargs(),
    )
    while True:
        try:
            stdout, stderr = process.communicate(timeout=0.2)
            break
        except subprocess.TimeoutExpired:
            if stop_event is not None and stop_event.is_set():
                terminate_process(process)
                try:
                    output.unlink(missing_ok=True)
                except OSError:
                    pass
                raise TaskCancelled()
    if process.returncode != 0 or not output.is_file():
        detail = (stderr or stdout or "").strip()
        raise RuntimeError(f"ffmpeg 转码失败: {detail or process.returncode}")
    return output
