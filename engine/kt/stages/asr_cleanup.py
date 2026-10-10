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
_MAX_RETAINED_REPETITIONS = 3


def cleanup_asr_cues(cues: list[Cue]) -> tuple[list[Cue], list[dict]]:
    """Cap long repeated punctuation/symbol runs without calling a model.

    Changed cue text is what downstream correction and export receive. The
    report preserves original text; ambiguous punctuation-heavy cues remain
    intact and are reported for review.
    """
    cleaned: list[Cue] = []
    entries: list[dict] = []

    for index, cue in enumerate(cues, start=1):
        original = cue.message
        stripped = original.strip()

        processed = _cap_repeated_symbol_runs(original)
        if processed != original:
            cleaned.append(Cue(cue.start, cue.end, processed, processed))
            entries.append(_entry(index, cue, original, processed, "capped_repeated_symbol_runs"))
            continue

        cleaned.append(Cue(cue.start, cue.end, original, original))
        if _symbol_count(stripped) >= _MIN_REPEATED_CHARS:
            entries.append(_entry(index, cue, original, original, "review_only"))

    return cleaned, entries


def write_asr_cleanup_report(subtitle_path: str | Path, entries: list[dict]) -> str:
    destination = Path(subtitle_path).with_suffix(".asr-cleanup.json")
    payload = {
        "schema_version": 1,
        "mode": "repeated_symbol_cap",
        "note": "超阈值的标点/符号重复串最多保留前 3 次；review_only 条目保持原文。",
        "rule": {
            "minimum_repeated_symbols": _MIN_REPEATED_CHARS,
            "minimum_repetitions": _MIN_REPETITIONS,
            "maximum_repeated_pattern_chars": _MAX_PATTERN_CHARS,
            "maximum_retained_repetitions": _MAX_RETAINED_REPETITIONS,
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


def _symbol_count(text: str) -> int:
    return sum(unicodedata.category(char)[0] in {"P", "S"} for char in text)


def _cap_repeated_symbol_runs(text: str) -> str:
    """Cap long repeated symbol motifs while preserving surrounding text."""
    parts: list[str] = []
    index = 0
    while index < len(text):
        char = text[index]
        if char == "\ufffd" or unicodedata.category(char)[0] not in {"P", "S"}:
            parts.append(char)
            index += 1
            continue

        run_end = index + 1
        while run_end < len(text):
            current = text[run_end]
            if current == "\ufffd" or unicodedata.category(current)[0] not in {"P", "S"}:
                break
            run_end += 1
        run = text[index:run_end]
        parts.append(_cap_repeated_run(run))
        index = run_end
    return "".join(parts)


def _cap_repeated_run(run: str) -> str:
    """Find repeated motifs in O(pattern_limit * run_length) time."""
    length = len(run)
    if length < _MIN_REPEATED_CHARS:
        return run

    best_end = [0] * length
    best_width = [0] * length

    # For each possible motif width, compute the common-prefix length of
    # run[i:] and run[i + width:] in one backwards pass.
    for width in range(1, min(_MAX_PATTERN_CHARS, length // _MIN_REPETITIONS) + 1):
        following_match = 0
        for start in range(length - 1, -1, -1):
            if start + width < length and run[start] == run[start + width]:
                following_match += 1
            else:
                following_match = 0

            repetitions = 1 + following_match // width
            repeated_length = repetitions * width
            if repetitions < _MIN_REPETITIONS or repeated_length < _MIN_REPEATED_CHARS:
                continue

            end = start + repeated_length
            previous_length = best_end[start] - start
            if repeated_length > previous_length or (
                repeated_length == previous_length
                and (best_width[start] == 0 or width < best_width[start])
            ):
                best_end[start] = end
                best_width[start] = width

    parts: list[str] = []
    cursor = 0
    start = 0
    while start < length:
        end = best_end[start]
        if end == 0:
            start += 1
            continue

        width = best_width[start]
        repetitions = (end - start) // width
        parts.append(run[cursor:start])
        parts.append(run[start:start + width] * min(repetitions, _MAX_RETAINED_REPETITIONS))
        cursor = end
        start = end

    parts.append(run[cursor:])
    return "".join(parts)
