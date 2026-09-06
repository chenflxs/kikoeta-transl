from __future__ import annotations

import re

from ..models import AppSettings, CorrectionSettings, Cue


SYSTEM_PROMPT = """你是字幕文件纠错器。输入为 ASR 模型 qwen3-asr-anime-jp 对日文音声作品听写后生成的 SRT/LRC 文本。没有人工审核，纠正结果会直接写回原字幕并进入下一个工作流。因此必须保守、确定、可自动落盘。

硬性规则：
1. 只输出纠错后的字幕全文，格式必须与输入一致；不要输出代码块、JSON、解释、diff 或“已修正”等字样。
2. 不得改动时间轴：SRT 的序号与 `HH:MM:SS,mmm --> HH:MM:SS,mmm`，LRC 的 `[mm:ss.xx]`/`[mm:ss.xxx]` 标签、空白行结构、行序、CRLF/LF 风格均保持原样。
3. 不合并、不拆分字幕条目；不判断或修正音画同步、时间偏移。
4. 只修正文本内容中的高置信度 ASR 错误：同音/近音误字、助词误识、长音/促音/拨音、明显标点错误、明显片假名外来语误写。必须能由上下文、专名词表或常见固定表达直接判断。
5. 无人工审核：低置信度、专名不确定、疑似漏句/多句、语气或角色风格有歧义时，一律保持原样；不要插入【不明】、注记、括号说明或标记。
6. 保留语气词、重复、口吃、笑声、气息、拟声词、口语缩约与角色口吻；不翻译成中文，不改写成书面语，不补写舞台指示。
7. 专名只使用【专名词表】；词表没有时不造读音/写法。已有汉字、片假名、罗马音写法不强行统一。
8. 标点统一日文标点：、。！？〜…；禁止中文/英文标点进入台词正文。SRT 条目内可多行时保留原有断行逻辑，只改字词。
9. 若整个文件非 SRT/LRC 或时间轴已损坏，原样返回，不做重构。

处理顺序：先识别格式并锁定所有时间轴/序号；再逐条只改文本；最后自检：时间轴逐字节一致、条目数一致、无占位符、无中文标点、无新增解释。"""


def correct_cues(cues: list[Cue], settings: AppSettings) -> list[Cue]:
    endpoint = settings.correct
    if not endpoint.base_url or not endpoint.model:
        raise RuntimeError("未配置矫正模型的 API 地址与模型名")
    subtitle = _to_srt(cues)
    content = _chat(endpoint, subtitle, settings.proxy)
    messages = _extract_corrected_messages(content, cues)
    return [
        Cue(
            start=cue.start,
            end=cue.end,
            message=message,
            src_message=cue.src_message or cue.message,
        )
        for cue, message in zip(cues, messages)
    ]


def test_correct(settings: AppSettings) -> str:
    endpoint = settings.correct
    if not endpoint.base_url or not endpoint.model:
        raise RuntimeError("未配置矫正模型")
    cues = [Cue(start=0, end=1, message="こんにちは")]
    content = _chat(endpoint, _to_srt(cues), settings.proxy)
    _extract_corrected_messages(content, cues)
    return "ok"


def _chat(endpoint: CorrectionSettings, user_text: str, proxy: str) -> str:
    url = _completions_url(endpoint.base_url)
    headers = {"content-type": "application/json"}
    if endpoint.api_key:
        headers["authorization"] = f"Bearer {endpoint.api_key}"
    body = {
        "model": endpoint.model,
        "temperature": endpoint.temperature,
        "messages": [
            {"role": "system", "content": endpoint.prompt.strip() or SYSTEM_PROMPT},
            {"role": "user", "content": user_text},
        ],
    }
    if endpoint.max_tokens > 0:
        body["max_tokens"] = endpoint.max_tokens
    import httpx
    kwargs = {"timeout": 120.0}
    if proxy:
        kwargs["proxy"] = proxy
    response = httpx.post(url, headers=headers, json=body, **kwargs)
    response.raise_for_status()
    data = response.json()
    return str(data["choices"][0]["message"]["content"])


def _completions_url(base: str) -> str:
    text = base.rstrip("/")
    if text.endswith("/chat/completions"):
        return text
    if text.endswith("/v1"):
        return text + "/chat/completions"
    return text + "/v1/chat/completions"


def _to_srt(cues: list[Cue]) -> str:
    blocks = []
    for index, cue in enumerate(cues, start=1):
        blocks.append(f"{index}\n{_srt_time(cue.start)} --> {_srt_time(cue.end)}\n{cue.message}\n")
    return "\n".join(blocks)


def _extract_corrected_messages(text: str, source: list[Cue]) -> list[str]:
    normalized = text.replace("\r\n", "\n").replace("\r", "\n").strip()
    blocks = re.split(r"\n[ \t]*\n", normalized)
    if len(blocks) != len(source):
        raise RuntimeError("矫正模型改变了字幕条目数")
    messages: list[str] = []
    for index, (block, cue) in enumerate(zip(blocks, source), start=1):
        lines = block.split("\n")
        if len(lines) < 3 or lines[0].strip() != str(index):
            raise RuntimeError("矫正模型改变了字幕序号或格式")
        expected_time = f"{_srt_time(cue.start)} --> {_srt_time(cue.end)}"
        if lines[1] != expected_time:
            raise RuntimeError("矫正模型改变了字幕时间轴")
        message = "\n".join(lines[2:])
        if not message.strip():
            raise RuntimeError("矫正模型输出了空字幕文本")
        messages.append(message)
    return messages


def _srt_time(value: float) -> str:
    hours, rem = divmod(max(value, 0), 3600)
    minutes, seconds = divmod(rem, 60)
    millis = int(round((seconds - int(seconds)) * 1000))
    return f"{int(hours):02d}:{int(minutes):02d}:{int(seconds):02d},{millis:03d}"
