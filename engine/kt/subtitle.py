from __future__ import annotations

import re
from pathlib import Path

from .models import Cue
from .paths import SUBTITLE_EXTS


_LRC_RE = re.compile(r"\[(\d{1,2}):(\d{1,2})(?:[.:](\d{1,3}))?\]")
_SRT_TIME_RE = re.compile(
    r"^\s*(\d{1,2}:\d{2}:\d{2}[,.]\d{1,3}|\d{1,2}:\d{2}[,.]\d{1,3})\s*-->\s*"
    r"(\d{1,2}:\d{2}:\d{2}[,.]\d{1,3}|\d{1,2}:\d{2}[,.]\d{1,3})"
)
_WORK_ID_RE = re.compile(r"(?:RJ|VJ|BJ)\d+", re.IGNORECASE)


def is_subtitle(path: str | Path) -> bool:
    return Path(path).suffix.lower() in SUBTITLE_EXTS


def parse_subtitle(path: str | Path, *, errors: str = "strict") -> list[Cue]:
    text = Path(path).read_text(encoding="utf-8-sig", errors=errors)
    return parse_subtitle_text(text, Path(path).suffix.lower())


def parse_subtitle_text(text: str, suffix: str) -> list[Cue]:
    normalized = text.replace("\r\n", "\n").replace("\r", "\n")
    suffix = suffix.lower()
    if suffix in {".ass", ".ssa"} or _looks_like_ass(normalized):
        cues = _parse_ass(normalized)
    elif suffix == ".lrc" or _looks_like_lrc(normalized):
        cues = _parse_lrc(normalized)
    else:
        cues = _parse_timed_blocks(normalized)
    return _fill_ends(cues)


def normalize_cue_timeline(cues: list[Cue]) -> list[Cue]:
    """Stable millisecond ordering and merging, without mutating input cues."""
    merged: list[Cue] = []
    last_key: int | None = None
    for cue in sorted(cues, key=lambda item: round(item.start * 1000)):
        key = round(cue.start * 1000)
        if merged and key == last_key:
            previous = merged[-1]
            previous.message = f"{previous.message.rstrip()} {cue.message.lstrip()}"
            previous.src_message = f"{previous.src_message.rstrip()} {(cue.src_message or cue.message).lstrip()}"
            previous.end = max(previous.end, cue.end)
        else:
            merged.append(Cue(
                start=cue.start, end=cue.end, message=cue.message,
                src_message=cue.src_message or cue.message,
            ))
            last_key = key
    return _fill_ends(merged)


def extract_work_id(*parts: str) -> str:
    found = ""
    for part in parts:
        for match in _WORK_ID_RE.findall(part.replace("\\", "/")):
            found = match.upper()
    return found


def _looks_like_ass(text: str) -> bool:
    return bool(re.search(r"^\s*\[Events\]", text, re.M) or re.search(r"^\s*Dialogue\s*:", text, re.M | re.I))


def _looks_like_lrc(text: str) -> bool:
    return bool(_LRC_RE.search(text)) and "-->" not in text


def _parse_timed_blocks(text: str) -> list[Cue]:
    cues: list[Cue] = []
    blocks = re.split(r"\n\s*\n", text.replace("WEBVTT", "", 1))
    for block in blocks:
        lines = [line for line in block.split("\n") if line.strip() and not line.strip().startswith("NOTE")]
        if not lines:
            continue
        timing_index = -1
        match = None
        for index, line in enumerate(lines):
            candidate = _SRT_TIME_RE.match(line)
            if candidate:
                timing_index = index
                match = candidate
                break
        if match is None:
            continue
        start = _parse_clock(match.group(1))
        end = _parse_clock(match.group(2))
        message = _clean_text("\n".join(lines[timing_index + 1 :]))
        if message:
            cues.append(Cue(start=start, end=end, message=message, src_message=message))
    return cues


def _parse_lrc(text: str) -> list[Cue]:
    cues: list[Cue] = []
    for raw in text.split("\n"):
        line = raw.strip()
        if not line:
            continue
        matches = list(_LRC_RE.finditer(line))
        if not matches:
            continue
        message = line[line.rfind("]") + 1 :].strip()
        if not message:
            continue
        for match in matches:
            start = int(match.group(1)) * 60 + int(match.group(2)) + _frac(match.group(3))
            cues.append(Cue(start=start, end=start, message=message, src_message=message))
    cues.sort(key=lambda item: item.start)
    return cues


def _parse_ass(text: str) -> list[Cue]:
    cues: list[Cue] = []
    for raw in text.split("\n"):
        line = raw.strip()
        if not line.lower().startswith("dialogue:"):
            continue
        fields = line.split(":", 1)[1].split(",")
        if len(fields) < 10:
            continue
        start = _parse_ass_clock(fields[1].strip())
        end = _parse_ass_clock(fields[2].strip())
        message = _clean_text(",".join(fields[9:]))
        if message:
            cues.append(Cue(start=start, end=end, message=message, src_message=message))
    return cues


def _fill_ends(cues: list[Cue]) -> list[Cue]:
    filled: list[Cue] = []
    for index, cue in enumerate(cues):
        end = cue.end
        if end <= cue.start:
            if index + 1 < len(cues):
                end = max(cues[index + 1].start, cue.start)
            else:
                end = cue.start + 3.0
        filled.append(Cue(start=cue.start, end=end, message=cue.message, src_message=cue.src_message or cue.message))
    return filled


def _parse_clock(value: str) -> float:
    text = value.strip().replace(",", ".")
    parts = text.split(":")
    if len(parts) == 2:
        parts = ["0", *parts]
    if len(parts) != 3:
        return 0.0
    hours = int(parts[0])
    minutes = int(parts[1])
    seconds = float(parts[2])
    return hours * 3600 + minutes * 60 + seconds


def _parse_ass_clock(value: str) -> float:
    text = value.strip().replace(",", ".")
    parts = text.split(":")
    if len(parts) != 3:
        return 0.0
    return int(parts[0]) * 3600 + int(parts[1]) * 60 + float(parts[2])


def _frac(raw: str | None) -> float:
    if not raw:
        return 0.0
    if len(raw) == 1:
        return int(raw) / 10
    if len(raw) == 2:
        return int(raw) / 100
    return int(raw[:3]) / 1000


def _clean_text(text: str) -> str:
    cleaned = re.sub(r"<[^>]+>", "", text)
    cleaned = re.sub(r"\{[^}]*\}", "", cleaned)
    cleaned = cleaned.replace("\\N", "\n").replace("\\n", "\n")
    return cleaned.strip()
