"""Validate text-only corrections and keep review evidence out of subtitles."""
from __future__ import annotations

import json
import math
import re
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path

from ..models import Cue


@dataclass
class CorrectionDecision:
    text: str
    needs_review: bool = False
    reason: str = ""
    assessed: bool = False


def parse_correction_response(
    text: str, source: list[Cue], *, start_index: int = 1
) -> list[CorrectionDecision]:
    normalized = text.replace("\r\n", "\n").replace("\r", "\n").strip()
    if not normalized:
        raise RuntimeError("矫正模型返回空内容")
    try:
        payload = json.loads(normalized)
    except json.JSONDecodeError:
        payload = None
    if payload is not None:
        if not isinstance(payload, list) or len(payload) != len(source):
            raise RuntimeError("矫正模型改变了字幕条目数")
        decisions = []
        for item in payload:
            if isinstance(item, str):
                decisions.append(CorrectionDecision(item))
            elif (
                isinstance(item, dict)
                and isinstance(item.get("text"), str)
                and type(item.get("needs_review")) is bool
                and isinstance(item.get("reason", ""), str)
            ):
                decisions.append(CorrectionDecision(
                    item["text"], item["needs_review"], item.get("reason", ""), True,
                ))
            else:
                raise RuntimeError("矫正模型输出了无效的字幕条目或复核字段")
    else:
        decisions = [CorrectionDecision(message) for message in
                     _legacy_messages(normalized, source, start_index)]
    for cue, decision in zip(source, decisions):
        if not decision.text.strip():
            raise RuntimeError("矫正模型输出了空字幕文本")
        if decision.needs_review:
            decision.text = cue.message
            decision.reason = decision.reason or "模型无法仅凭文本确定原文，保留待回听"
        elif decision.text != cue.message:
            if _protected_layout(decision.text) != _protected_layout(cue.message):
                decision.text = cue.message
                decision.needs_review = True
                decision.reason = "候选修改了标点、空白或换行，未采用，需复核"
            elif _is_nonverbal(cue.message):
                decision.text = cue.message
                decision.needs_review = True
                decision.reason = "候选改写了纯气声或语气词，未采用，需回听"
            elif decision.assessed and not decision.reason.strip():
                decision.text = cue.message
                decision.needs_review = True
                decision.reason = "候选未提供纠错依据，保留原文待复核"
        if "\ufffd" in decision.text or re.search(
            r"[〔【\[](?:聞き取り不明|听不清|聽不清|听写待核)[〕】\]]", decision.text
        ):
            decision.needs_review = True
            decision.reason = decision.reason or "仍含损坏字符或听不清标记，需回听确认"
    return decisions


def _protected_layout(text: str) -> list[str | None]:
    # Word lengths may change, but punctuation/whitespace must stay between
    # the same text runs, including at the beginning and end of a line.
    layout: list[str | None] = []
    in_text = False
    for char in text:
        if char.isspace() or unicodedata.category(char).startswith("P"):
            layout.append(char)
            in_text = False
        elif not in_text:
            layout.append(None)
            in_text = True
    return layout


def _is_nonverbal(text: str) -> bool:
    letters = "".join(char for char in text
                      if not char.isspace() and not unicodedata.category(char).startswith("P"))
    return not letters or bool(re.fullmatch(r"[んンあぁアァうぅウゥえぇエェおぉオォはハふフむムっッー]+", letters))


def _review_time(value: float) -> float | None:
    # Invalid ASR times must not prevent exporting the review JSON itself.
    return value if math.isfinite(value) else None


def _legacy_messages(text: str, source: list[Cue], start_index: int) -> list[str]:
    # Older custom prompts return LRC/SRT. Returned times remain untrusted.
    lines = text.split("\n")
    matches = [re.match(r"^\s*\[[^\]\r\n]+\] ([^\r\n]+)$", line) for line in lines]
    if len(lines) == len(source) and all(matches):
        return [match.group(1) for match in matches if match is not None]
    blocks = re.split(r"\n[ \t]*\n", text)
    if len(blocks) != len(source):
        if not re.search(r"(?m)^\s*1\s*$", text):
            raise RuntimeError(f"矫正模型返回了非字幕内容：{' '.join(text.split())[:300]}")
        raise RuntimeError("矫正模型改变了字幕条目数")
    messages = []
    for index, block in enumerate(blocks, start=start_index):
        lines = block.split("\n")
        if len(lines) < 3 or lines[0].strip() != str(index):
            raise RuntimeError("矫正模型改变了字幕序号或格式")
        if "-->" not in lines[1]:
            raise RuntimeError("矫正模型改变了字幕结构")
        messages.append("\n".join(lines[2:]))
    return messages


@dataclass
class CorrectionReview:
    source_file: str = ""
    model: str = ""
    input_count: int = 0
    output_count: int = 0
    changed_count: int = 0
    review_count: int = 0
    unassessed_count: int = 0
    entries: list[dict] = field(default_factory=list)
    timing_notes: list[dict] = field(default_factory=list)

    def prepare(self, original: list[Cue], normalized: list[Cue], model: str) -> None:
        self.model = model
        self.input_count = len(original)
        self.output_count = len(normalized)
        self.changed_count = self.review_count = self.unassessed_count = 0
        self.entries.clear()
        self.timing_notes.clear()
        for index, cue in enumerate(original, 1):
            if not (math.isfinite(cue.start) and math.isfinite(cue.end)):
                issue = "时间值不是有限数"
            elif cue.start < 0 or cue.end <= cue.start:
                issue = "原始起止时间无效，本地补全不等于音频对齐"
            else:
                continue
            self.timing_notes.append(dict(index=index, index_scope="input",
                start=_review_time(cue.start), end=_review_time(cue.end), issue=issue))
        for index, (cue, following) in enumerate(zip(normalized, normalized[1:]), 1):
            if cue.end > following.start:
                self.timing_notes.append(dict(index=index, index_scope="normalized",
                    start=_review_time(cue.start), end=_review_time(cue.end),
                    issue="与下一条字幕重叠，需回听对齐；文字矫正未裁剪时间"))

    def add(self, source: list[Cue], decisions: list[CorrectionDecision], offset: int) -> None:
        for index, (cue, decision) in enumerate(zip(source, decisions), offset + 1):
            changed = decision.text != cue.message
            self.changed_count += changed
            self.review_count += decision.needs_review
            self.unassessed_count += not decision.assessed
            if changed or decision.needs_review:
                self.entries.append(dict(index=index, start=_review_time(cue.start), end=_review_time(cue.end),
                    original=cue.message, corrected=decision.text, changed=changed,
                    needs_review=decision.needs_review, reason=decision.reason,
                    review_assessed=decision.assessed))

    def write(self, subtitle_path: str | Path) -> str:
        """Save alongside the export so cleaning job caches cannot lose evidence."""
        destination = Path(subtitle_path).with_suffix(".correction.json")
        payload = dict(schema_version=1, source_file=self.source_file, model=self.model,
            mode="text_only", note="未向矫正模型发送音频；文字矫正和本地时间整理不代表音频复校。",
            input_cue_count=self.input_count, output_cue_count=self.output_count,
            changed_cue_count=self.changed_count, review_cue_count=self.review_count,
            unassessed_cue_count=self.unassessed_count,
            unassessed_note="旧格式响应未提供复核判断，未修改不代表已经确认正确。",
            entries=self.entries, timing_notes=self.timing_notes)
        destination.write_text(json.dumps(payload, ensure_ascii=False, indent=2, allow_nan=False) + "\n",
                               encoding="utf-8")
        return str(destination)
