from __future__ import annotations

from pathlib import Path

from ..models import (
    AppSettings,
    Cue,
    normalize_output_preset,
    preset_bilingual,
    preset_format,
    preset_source_first,
)


def export_cues(
    cues: list[Cue],
    source_path: str | Path,
    settings: AppSettings,
    src_cues: list[Cue] | None = None,
) -> list[str]:
    source = Path(source_path)
    stem = source.stem
    if stem.endswith(".16k"):
        stem = stem[:-4]
    output_dir = resolve_output_dir(source, settings)
    output_dir.mkdir(parents=True, exist_ok=True)
    preset = normalize_output_preset(
        settings.output.preset,
        settings.output.formats,
        settings.output.bilingual,
    )
    fmt = preset_format(preset)
    bilingual = preset_bilingual(preset)
    source_first = preset_source_first(preset)
    suffix = str(settings.output.suffix or "").strip()
    if suffix and not suffix.startswith("."):
        suffix = "." + suffix
    output_stem = f"{stem}{suffix}"
    dest = output_dir / f"{output_stem}.{fmt}"
    if bilingual and src_cues:
        _write_bilingual(dest, src_cues, cues, fmt, source_first=source_first)
    else:
        _write_file(dest, cues, fmt)
    return [str(dest)]


def resolve_output_dir(source: Path, settings: AppSettings) -> Path:
    directory = str(settings.output.directory or "").strip()
    if directory:
        return Path(directory)
    return source.parent


def _write_file(path: Path, cues: list[Cue], fmt: str) -> None:
    if fmt == "lrc":
        path.write_text(_to_lrc(cues), encoding="utf-8")
    elif fmt == "vtt":
        path.write_text(_to_vtt(cues), encoding="utf-8")
    else:
        path.write_text(_to_srt(cues), encoding="utf-8")


def _write_bilingual(
    path: Path,
    src: list[Cue],
    dst: list[Cue],
    fmt: str,
    *,
    source_first: bool = False,
) -> None:
    merged: list[Cue] = []
    for left, right in zip(src, dst):
        first, second = (left, right) if source_first else (right, left)
        message = f"{first.message}\n{second.message}" if fmt != "lrc" else f"{first.message} {second.message}"
        merged.append(Cue(start=right.start, end=right.end, message=message, src_message=left.message))
    _write_file(path, merged, fmt)


def _to_srt(cues: list[Cue]) -> str:
    blocks = []
    for index, cue in enumerate(cues, start=1):
        blocks.append(f"{index}\n{_srt_time(cue.start)} --> {_srt_time(cue.end)}\n{cue.message}\n")
    return "\n".join(blocks) + ("\n" if blocks else "")


def _to_vtt(cues: list[Cue]) -> str:
    lines = ["WEBVTT", ""]
    for cue in cues:
        lines.append(f"{_vtt_time(cue.start)} --> {_vtt_time(cue.end)}")
        lines.append(cue.message)
        lines.append("")
    return "\n".join(lines)


def _to_lrc(cues: list[Cue]) -> str:
    lines = [f"[{_lrc_time(cue.start)}] {cue.message}" for cue in cues]
    return "\n".join(lines) + ("\n" if lines else "")


def _srt_time(value: float) -> str:
    hours, rem = divmod(max(value, 0), 3600)
    minutes, seconds = divmod(rem, 60)
    millis = int(round((seconds - int(seconds)) * 1000))
    return f"{int(hours):02d}:{int(minutes):02d}:{int(seconds):02d},{millis:03d}"


def _vtt_time(value: float) -> str:
    return _srt_time(value).replace(",", ".")


def _lrc_time(value: float) -> str:
    minutes, seconds = divmod(max(value, 0), 60)
    millis = int(round((seconds - int(seconds)) * 1000))
    return f"{int(minutes):02d}:{int(seconds):02d}.{millis:03d}"
