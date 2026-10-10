"""Remove only highly repetitive punctuation artifacts from ASR output."""
from __future__ import annotations

import json
import math
import unicodedata
from pathlib import Path

from ..models import Cue


_MIN_REPEATED_CHARS = 16
_MIN_REPETITIONS = 6
_MAX_PATTERN_CHARS = 4


def cleanup_asr_cues(cues: list[Cue]) -> tuple[list[Cue], list[dict]]:
    """Drop symbol-only repetitions and trim equally clear repeated suffixes.

    Changed cue text is what downstream correction and export receive. The
    report preserves original text; other punctuation-heavy cues remain intact
    and are reported for review.
    """
    cleaned: list[Cue] = []
    entries: list[dict] = []

    for index, cue in enumerate(cues, start=1):
        original = cue.message
        stripped = original.strip()
        source_message = cue.src_message or original

        if "\ufffd" in stripped:
            cleaned.append(Cue(cue.start, cue.end, original, source_message))
            if _is_repeated_pattern(stripped):
                entries.append(_entry(index, cue, original, original, "review_only"))
            continue

        if _is_symbol_only(stripped) and _is_repeated_pattern(stripped):
            entries.append(_entry(index, cue, original, "", "removed_symbol_noise"))
            continue

        suffix_start = _trailing_repeated_symbol_start(stripped)
        if suffix_start is not None:
            processed = stripped[:suffix_start].rstrip()
            if processed:
                cleaned.append(Cue(cue.start, cue.end, processed, processed))
                entries.append(_entry(index, cue, original, processed, "trimmed_repeated_symbol_suffix"))
                continue

        cleaned.append(Cue(cue.start, cue.end, original, original))
        if _symbol_count(stripped) >= _MIN_REPEATED_CHARS and not _is_repeated_pattern(stripped):
            entries.append(_entry(index, cue, original, original, "review_only"))

    return cleaned, entries


def write_asr_cleanup_report(subtitle_path: str | Path, entries: list[dict]) -> str:
    destination = Path(subtitle_path).with_suffix(".asr-cleanup.json")
    payload = {
        "schema_version": 1,
        "mode": "repeated_symbol_cleanup",
        "note": "仅自动处理高置信度的重复符号噪声；review_only 条目保持原文。",
        "rule": {
            "minimum_repeated_symbols": _MIN_REPEATED_CHARS,
            "minimum_repetitions": _MIN_REPETITIONS,
            "maximum_repeated_pattern_chars": _MAX_PATTERN_CHARS,
        },
        "entries": entries,
    }
    destination.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2, allow_nan=False) + "\n",
        encoding="utf-8",
    )
    return str(destination)


def _entry(index: int, cue: Cue, original: str, processed: str, action: str) -> dict:
    return {
        "index": index,
        "start": cue.start if math.isfinite(cue.start) else None,
        "end": cue.end if math.isfinite(cue.end) else None,
        "action": action,
        "original": original,
        "processed": processed,
    }


def _is_symbol_only(text: str) -> bool:
    return bool(text) and all(
        char.isspace() or unicodedata.category(char)[0] in {"P", "S"}
        for char in text
    )


def _symbol_count(text: str) -> int:
    return sum(unicodedata.category(char)[0] in {"P", "S"} for char in text)


def _is_repeated_pattern(text: str) -> bool:
    compact = "".join(char for char in text if not char.isspace())
    if len(compact) < _MIN_REPEATED_CHARS:
        return False
    for width in range(1, _MAX_PATTERN_CHARS + 1):
        if len(compact) % width:
            continue
        repetitions = len(compact) // width
        if repetitions >= _MIN_REPETITIONS and compact == compact[:width] * repetitions:
            return True
    return False


def _trailing_repeated_symbol_start(text: str) -> int | None:
    start = len(text)
    while start > 0 and unicodedata.category(text[start - 1])[0] in {"P", "S"}:
        start -= 1
    suffix = text[start:]
    if (
        start > 0
        and len(suffix) >= _MIN_REPEATED_CHARS
        and _is_repeated_pattern(suffix)
    ):
        return start
    return None
