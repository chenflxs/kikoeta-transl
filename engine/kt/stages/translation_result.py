"""Match backend rows to source cues and detect untranslated text."""
from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path
from threading import Lock

from ..models import AppSettings, Cue


def merge_translation_items(items: list[dict], cues: list[Cue]) -> list[Cue]:
    # An absent row remains empty so it can be retried, even for numbers or
    # nonverbal text that would otherwise be allowed to stay unchanged.
    out = [Cue(c.start, c.end, "", c.src_message or c.message) for c in cues]
    used: set[int] = set()
    for position, item in enumerate(items):
        if not isinstance(item, dict):
            continue
        match = None
        if "index" in item:
            index = item["index"]
            if type(index) is not int or not 1 <= index <= len(cues):
                continue
            match = index - 1
        else:
            original = item.get("src_message") or item.get("org_message") or item.get("src_msg")
            candidates = [index for index, cue in enumerate(cues) if index not in used]
            if original:
                candidates = [index for index in candidates
                              if original in (cues[index].message, cues[index].src_message)]
            if "start" in item:
                try:
                    start = float(item["start"])
                    end = float(item.get("end", start))
                except (TypeError, ValueError):
                    continue
                candidates = [index for index in candidates
                              if abs(cues[index].start - start) < 0.01
                              and abs(cues[index].end - end) < 0.01]
            if original or "start" in item:
                match = next(iter(candidates), None)
            elif len(items) == len(cues):
                match = position
        if match is None or match in used:
            continue
        used.add(match)
        message = item.get("message")
        if isinstance(message, str):
            out[match].message = message
    return out


# Exclude Japanese punctuation such as ・ and the shared long-vowel mark ー.
_KANA_RE = re.compile(r"[ぁ-ゖゝ-ゟァ-ヺヽ-ヿㇰ-ㇿ]")
_CONTENT_RE = re.compile(r"(?:[^\W\d_]|[\u3400-\u9fff])", re.UNICODE)
_BREATH_RE = re.compile(r"[んンあぁアァうぅウゥえぇエェおぉオォはハふフむムっッー]+")


def _is_breath(text: str) -> bool:
    letters = "".join(char for char in text if not char.isspace()
                      and unicodedata.category(char)[0] not in {"P", "S"})
    return bool(_BREATH_RE.fullmatch(letters))


def looks_untranslated(source: Cue, result: Cue, settings: AppSettings) -> bool:
    # message is the actual translation input; src_message may be pre-correction.
    original, translated = source.message, result.message
    if not translated.strip():
        return True
    source_lang = language_code(settings.source_lang)
    target_lang = language_code(settings.target_lang)
    if source_lang == target_lang:
        return False
    if source_lang == "ja" and _is_breath(original) and _is_breath(translated):
        return False
    if " ".join(original.split()).casefold() == " ".join(translated.split()).casefold():
        # Shared kanji nouns can be valid Chinese without changing spelling.
        # Character checks cannot establish that such a translation is wrong.
        if source_lang == "ja" and target_lang == "zh" and not _KANA_RE.search(original):
            if not any(char.isalpha() and not "\u3400" <= char <= "\u9fff" for char in original):
                return False
        return bool(_CONTENT_RE.search(original))
    # A single residual particle is still untranslated; do not dilute it by
    # the length of the original sentence or require kana in the original.
    return source_lang == "ja" and target_lang == "zh" and bool(_KANA_RE.search(translated))


def language_code(value: str) -> str:
    language = (value or "").strip().lower().replace("_", "-")
    if language.startswith("zh-"):
        return "zh"
    if language.startswith("ja-"):
        return "ja"
    return language


_REPORT_LOCK = Lock()
UNTRANSLATED_REPORT_NAME = "未翻译记录.txt"


@dataclass
class TranslationReview:
    source_file: str = ""
    entries: list[dict] = field(default_factory=list)

    def add(self, index: int, source: Cue, result: Cue, attempts: int) -> None:
        self.entries.append(dict(index=index, start=source.start, end=source.end,
            original=source.message, output=result.message, attempts=attempts))

    def write(self, subtitle_path: str | Path) -> str | None:
        if not self.entries:
            return None
        subtitle = Path(subtitle_path)
        destination = subtitle.parent / UNTRANSLATED_REPORT_NAME
        timestamp = datetime.now(timezone(timedelta(hours=8))).strftime("%Y-%m-%d %H:%M:%S")
        lines = [f"记录时间：{timestamp}（北京时间）", f"原文件：{self.source_file}",
                 f"输出歌词：{subtitle}", f"未翻译条目：{len(self.entries)}"]
        for entry in self.entries:
            lines.extend([
                f"  第 {entry['index']} 条，时间 {entry['start']:.3f}s → {entry['end']:.3f}s，"
                f"补译 {entry['attempts']} 次后仍疑似未翻译",
                f"    原文：{entry['original']}", f"    输出：{entry['output']}",
            ])
        block = "\n".join(lines) + "\n\n"
        # Jobs process their files sequentially. Protect whole append blocks
        # when several job threads finish files in the same output directory.
        with _REPORT_LOCK:
            header = "" if destination.exists() and destination.stat().st_size else "未翻译位置记录（按处理顺序追加）\n\n"
            with destination.open("a", encoding="utf-8", newline="\n") as stream:
                stream.write(header + block)
        return str(destination)
