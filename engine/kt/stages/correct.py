from __future__ import annotations

import json
import re

from ..subtitle import normalize_cue_timeline

from ..events import EmitFn
from ..models import AppSettings, CorrectionSettings, Cue


SYSTEM_PROMPT = """你是 ASR 文本保守纠错器。输入包含完整歌词上下文和当前目标批次，均为正文 JSON 字符串数组。仅修正目标批次正文中的高置信度 ASR 错误。

核心原则（优先级递减）：
1. 文本结构不可变性 > 文本正确性：宁可保留错误，也不要破坏条目结构。
2. 确定性 > 覆盖率：仅 100% 确定的错误才修正；同时必须有充分文本、语音或上下文证据，不确定就保持原样。
3. 零添加原则：不解释、不标记、不翻译、不润色、不删减、不净化。

输入规则：
- 完整歌词上下文包含全部歌词，仅供理解语义和判断前后关系，禁止修改和输出。
- 当前目标批次通常为 10 条，末批以实际条目数为准；只能处理和输出当前目标批次。
- 时间轴已由本地程序整理，输入不包含时间戳；不要生成、猜测或修改时间戳。
- 输入数组中的同时间字幕已经按本地规则合并；不要再次拆分或重排。

可修正范围（必须有明确证据）：
- 同音异义字，且语境、角色身份或场景明确指向唯一写法。
- 助词混淆：を/は、に/と、て/で、が/か。
- 长音（ー）、促音（っ）、拨音（ん/ン）以及清浊音的明确误识。
- 形近假名：い/り、つ/っ、へ/ベ/ペ、れ/ね/わ。
- 片假名乱码中混入明显日语助词或语法成分时，可按固定搭配重构，例如“デヒトトビ”在明确语境下还原为“でひとっ飛び”。
- 固定搭配明显错误时，只有正确写法唯一且证据充分才修正，例如“バチ当たり”。

禁止修正：
- 角色口音、方言、故意口误和口语缩约（如“ですぅ”“ますぅ”“～りゅ”“～てゅ”“それそう”“うれしゅ”），除非有明确证据证明是 ASR 误识。
- 喘息、呻吟、语气词（んんっ、あぁぁ、はぁ、んっ）。
- 拟声拟态、重复、口吃、断句、双关、暗示和非常规表达。
- 没有明确词表或上下文支持的专名。
- 任何可能只是表达风格差异的改写。

输出约束：
- 只输出目标批次对应的 JSON 字符串数组，不要输出解释、序号、字段名或 Markdown 代码块。
- 输出数组长度、元素顺序必须与目标批次完全一致。
- 每个输入元素必须对应一个输出元素，禁止合并、拆分、删除或重排。
- 禁止输出空字符串；元素内部的换行必须保留为同一字符串中的 JSON 转义。
- 保留正文原有标点、全半角、空白和换行，除非它们本身是有明确证据的 ASR 错误。

自检：
- 数组条目数与目标批次完全一致。
- 只修改高置信度 ASR 错误，其余文本逐字保持原样。
- 没有输出时间戳、解释、标记、翻译、代码块或额外内容。

示例：
目标批次：["こんにちは", "ありがとうございます"]
输出：["こんにちは", "ありがとうございます"]
"""


# Keep each correction response small enough for providers with conservative
# context/output limits. The original cue timestamps are retained when the
# batches are merged below.
CORRECTION_BATCH_SIZE = 10
CORRECTION_MAX_TOKENS = 4096


def correct_cues(
    cues: list[Cue],
    settings: AppSettings,
    *,
    emit: EmitFn | None = None,
    file: str | None = None,
) -> list[Cue]:
    endpoint = settings.correct
    if not endpoint.base_url or not endpoint.model:
        raise RuntimeError("未配置矫正模型的 API 地址与模型名")

    if not cues:
        _emit_log(emit, file, "矫正跳过：没有可用字幕条目")
        return []

    original_count = len(cues)
    cues = normalize_cue_timeline(cues)
    _emit_log(emit, file, f"本地时间轴整理完成：按开始时间排序，合并 {original_count - len(cues)} 条同时间字幕，剩余 {len(cues)} 条")

    total_batches = (len(cues) + CORRECTION_BATCH_SIZE - 1) // CORRECTION_BATCH_SIZE
    _emit_log(
        emit,
        file,
        f"矫正开始：共 {len(cues)} 条字幕，分为 {total_batches} 批，模型 {endpoint.model}",
    )
    messages: list[str] = []
    changed_total = 0
    for offset in range(0, len(cues), CORRECTION_BATCH_SIZE):
        batch = cues[offset : offset + CORRECTION_BATCH_SIZE]
        full_context = _full_context(cues, messages)
        batch_number = offset // CORRECTION_BATCH_SIZE + 1
        first = offset + 1
        last = offset + len(batch)
        _emit_log(
            emit,
            file,
            f"正在请求矫正模型：第 {batch_number}/{total_batches} 批，字幕 {first}-{last}",
        )
        try:
            user_text = _build_correction_input(full_context, batch, offset)
            content = _chat(endpoint, user_text, settings.proxy)
            _emit_log(
                emit,
                file,
                f"已收到矫正响应：第 {batch_number}/{total_batches} 批，约 {len(content)} 字符，正在校验格式",
            )
            corrected = _extract_corrected_messages(
                content, batch, start_index=offset + 1
            )
            changed = sum(
                source.message != result
                for source, result in zip(batch, corrected)
            )
            changed_total += changed
            messages.extend(corrected)
            _emit_log(
                emit,
                file,
                f"矫正批次完成：第 {batch_number}/{total_batches} 批，校验 {len(batch)} 条，修改 {changed} 条",
            )
        except Exception as exc:
            _emit_log(
                emit,
                file,
                f"矫正批次失败：第 {batch_number}/{total_batches} 批，字幕 {first}-{last}，{exc}",
            )
            raise RuntimeError(f"矫正第 {first}-{last} 条字幕失败：{exc}") from exc

    _emit_log(
        emit,
        file,
        f"矫正完成：共处理 {len(cues)} 条字幕，实际修改 {changed_total} 条，其余保持原样",
    )
    return [
        Cue(
            start=cue.start,
            end=cue.end,
            message=message,
            src_message=cue.src_message or cue.message,
        )
        for cue, message in zip(cues, messages)
    ]


def _emit_log(emit: EmitFn | None, file: str | None, message: str) -> None:
    if emit is None:
        return
    payload = {"message": message}
    if file:
        payload["file"] = file
    emit("log", **payload)


def test_correct(settings: AppSettings) -> str:
    endpoint = settings.correct
    if not endpoint.base_url or not endpoint.model:
        raise RuntimeError("未配置矫正模型")
    cues = [Cue(start=0, end=1, message="こんにちは")]
    content = _chat(
        endpoint,
        _build_correction_input(cues, cues, 0),
        settings.proxy,
    )
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
        # Kimi gateways can time out while buffering a thinking response.
        "stream": "kimi" in endpoint.model.lower(),
        "messages": [
            {"role": "system", "content": (endpoint.prompt.strip() + "\n\n" + SYSTEM_PROMPT) if endpoint.prompt.strip() else SYSTEM_PROMPT},
            {"role": "user", "content": user_text},
        ],
    }
    if any(name in endpoint.model.lower() for name in ("kimi-k2.5", "kimi-k2.6")):
        # Let Kimi choose the temperature appropriate for its thinking mode.
        # A generic 0.2 is not supported by all Kimi providers.
        body.pop("temperature", None)
    body["max_tokens"] = endpoint.max_tokens
    if endpoint.enable_thinking is not None:
        body["thinking"] = {
            "type": "enabled" if endpoint.enable_thinking else "disabled"
        }
    import httpx
    kwargs = {"timeout": 120.0}
    if proxy:
        kwargs["proxy"] = proxy
    response = _post_chat(url, headers, body, kwargs)
    data = _response_json_or_raise(response)
    finish_reason = data.get("choices", [{}])[0].get("finish_reason")

    # DeepSeek counts hidden reasoning tokens against max_tokens. If an
    # explicitly enabled-thinking request spends the whole budget before it
    # emits the subtitle body, retry once in non-thinking mode so a correct
    # batch is still recoverable.
    if finish_reason == "length" and endpoint.enable_thinking is not False:
        fallback_body = dict(body)
        fallback_body["thinking"] = {"type": "disabled"}
        response = _post_chat(url, headers, fallback_body, kwargs)
        data = _response_json_or_raise(response)

    return _extract_chat_content(data)


def _post_chat(url: str, headers: dict[str, str], body: dict, kwargs: dict):
    import time

    import httpx

    response = None
    for attempt in range(2):
        response = _send_chat(url, headers, body, kwargs)
        if response.status_code not in {408, 425, 429, 500, 502, 503, 504}:
            break
        if attempt == 0:
            time.sleep(1.0)
    assert response is not None
    if response.status_code == 400:
        # Some OpenAI-compatible gateways reject optional generation fields
        # for particular routed models. Retry once with the documented minimum
        # chat-completions payload before reporting the provider error.
        minimal_body = {
            "model": body["model"],
            "messages": body["messages"],
            "stream": body.get("stream", False),
        }
        if "thinking" in body:
            minimal_body["thinking"] = body["thinking"]
        if body != minimal_body:
            response = _send_chat(url, headers, minimal_body, kwargs)
    return response


def _send_chat(url: str, headers: dict[str, str], body: dict, kwargs: dict):
    import httpx

    if not body.get("stream"):
        return httpx.post(url, headers=headers, json=body, **kwargs)
    with httpx.stream("POST", url, headers=headers, json=body, **kwargs) as response:
        if response.is_error or "text/event-stream" not in response.headers.get("content-type", ""):
            response.read()
            return response
        data = _collect_chat_stream(response.iter_lines())
        return httpx.Response(200, json=data, request=response.request)


def _collect_chat_stream(lines) -> dict:
    """Reassemble SSE text, keeping reasoning separate from subtitle output."""
    import time

    started = time.monotonic()
    content: list[str] = []
    reasoning: list[str] = []
    refusal: list[str] = []
    finish_reason = None
    usage = None
    event_lines: list[str] = []
    done = False

    def consume() -> None:
        nonlocal finish_reason, usage, done
        raw = "\n".join(event_lines)
        event_lines.clear()
        if not raw:
            return
        if raw.strip() == "[DONE]":
            done = True
            return
        try:
            chunk = json.loads(raw)
        except ValueError as exc:
            raise RuntimeError("矫正 API 返回无效的流式 JSON") from exc
        if not isinstance(chunk, dict):
            raise RuntimeError("矫正 API 返回无效的流式事件")
        if chunk.get("error"):
            raise RuntimeError("矫正 API 在流式响应中报告错误")
        if chunk.get("usage"):
            usage = chunk["usage"]
        for choice in chunk.get("choices") or []:
            if choice.get("index", 0) != 0:
                continue
            delta = choice.get("delta") or {}
            for field, destination in (
                ("content", content), ("reasoning_content", reasoning), ("refusal", refusal)
            ):
                value = delta.get(field)
                if isinstance(value, str):
                    destination.append(value)
            finish_reason = choice.get("finish_reason") or finish_reason

    for line in lines:
        if time.monotonic() - started > 600:
            raise RuntimeError("矫正 API 流式响应超过 10 分钟，已停止等待")
        if not line:
            consume()
            if done:
                break
        elif line.startswith("data:"):
            event_lines.append(line[5:].lstrip(" "))
    if event_lines:
        consume()
    if not done and finish_reason is None:
        raise RuntimeError("矫正 API 流式响应中断，未收到结束标记")
    return {
        "choices": [{
            "finish_reason": finish_reason,
            "message": {
                "content": "".join(content),
                "reasoning_content": "".join(reasoning),
                "refusal": "".join(refusal),
            },
        }],
        "usage": usage,
    }


def _response_json_or_raise(response) -> dict:
    import httpx

    try:
        response.raise_for_status()
    except httpx.HTTPStatusError as exc:
        detail = _response_error_detail(exc.response)
        raise RuntimeError(
            f"矫正 API 请求失败（HTTP {exc.response.status_code}）：{detail}"
        ) from exc
    data = response.json()
    if not isinstance(data, dict):
        raise RuntimeError("矫正 API 返回格式无效")
    return data


def _extract_chat_content(data: dict) -> str:
    try:
        message = data["choices"][0]["message"]
    except (KeyError, IndexError, TypeError) as exc:
        raise RuntimeError("矫正 API 返回格式不包含 choices[0].message.content") from exc
    if not isinstance(message, dict):
        raise RuntimeError("矫正 API 返回格式不包含有效的 message 对象")
    finish_reason = data.get("choices", [{}])[0].get("finish_reason")
    if finish_reason == "content_filter":
        raise RuntimeError("矫正模型因内容安全策略拒绝该批次")
    content = message.get("content")
    if isinstance(content, str) and content.strip():
        return content
    refusal = message.get("refusal")
    if refusal:
        raise RuntimeError(f"矫正模型拒绝请求：{str(refusal)[:300]}")
    if finish_reason == "length":
        raise RuntimeError("矫正模型输出上限耗尽，未返回字幕正文；请提高 max_tokens")
    reasoning = message.get("reasoning_content")
    reasoning_length = len(reasoning) if isinstance(reasoning, str) else 0
    raise RuntimeError(
        f"矫正模型返回空内容（finish_reason={finish_reason!r}，"
        f"推理字符数={reasoning_length}）；请检查网关思考开关及模型输出预算"
    )


def _response_error_detail(response) -> str:
    """Extract a useful provider error without exposing request secrets."""
    try:
        payload = response.json()
    except (ValueError, TypeError):
        payload = None
    if isinstance(payload, dict):
        error = payload.get("error")
        if isinstance(error, dict):
            detail = error.get("message") or error.get("detail") or error.get("code")
        else:
            detail = error or payload.get("message") or payload.get("detail")
        if detail:
            trace_id = payload.get("traceId") or payload.get("trace_id")
            suffix = f" (traceId: {trace_id})" if trace_id else ""
            return f"{str(detail)[:1000]}{suffix}"
    text = (getattr(response, "text", "") or "").strip()
    return text[:1000] or "服务端未返回错误详情"


def _completions_url(base: str) -> str:
    text = base.rstrip("/")
    if text.endswith("/chat/completions"):
        return text
    if text.endswith("/v1"):
        return text + "/chat/completions"
    return text + "/v1/chat/completions"


def _full_context(cues: list[Cue], corrected_messages: list[str]) -> list[Cue]:
    """Render every cue as context, using completed corrections where available."""
    context: list[Cue] = []
    for index in range(len(cues)):
        cue = cues[index]
        message = cue.message
        if index < len(corrected_messages):
            message = corrected_messages[index]
        context.append(
            Cue(
                start=cue.start,
                end=cue.end,
                message=message,
                src_message=cue.src_message,
            )
        )
    return context


def _build_correction_input(
    full_context: list[Cue],
    target: list[Cue],
    target_offset: int,
) -> str:
    return (
        f"完整歌词上下文（{len(full_context)} 条，仅参考，禁止修改和输出）：\n"
        f"{_to_prompt_lines(full_context)}\n\n"
        f">>> 当前目标批次（第 {target_offset + 1}-{target_offset + len(target)} 条，共 {len(target)} 条，需纠正且仅输出本段）：\n"
        f"{_to_prompt_lines(target)}\n\n"
        "只输出当前目标批次的 JSON 字符串数组。"
    )


def _to_prompt_lines(cues: list[Cue]) -> str:
    """Serialize only cue text, including embedded newlines, without timing data."""
    return json.dumps([cue.message for cue in cues], ensure_ascii=False)


def _to_srt(cues: list[Cue], *, start_index: int = 1) -> str:
    blocks = []
    for index, cue in enumerate(cues, start=start_index):
        blocks.append(f"{index}\n{_srt_time(cue.start)} --> {_srt_time(cue.end)}\n{cue.message}\n")
    return "\n".join(blocks)


def _extract_corrected_messages(
    text: str, source: list[Cue], *, start_index: int = 1
) -> list[str]:
    normalized = text.replace("\r\n", "\n").replace("\r", "\n").strip()
    if not normalized:
        raise RuntimeError("矫正模型返回空内容")

    if normalized.startswith("["):
        try:
            payload = json.loads(normalized)
        except json.JSONDecodeError:
            payload = None
        if payload is not None:
            if not isinstance(payload, list) or len(payload) != len(source):
                raise RuntimeError("矫正模型改变了字幕条目数")
            if any(not isinstance(item, str) or not item.strip() for item in payload):
                raise RuntimeError("矫正模型输出了空字幕文本或非字符串条目")
            return payload

    # Legacy responses remain readable for existing custom prompts.
    # The previous prompt uses one LRC-style timestamp line per cue.  Timestamps
    # are intentionally accepted and discarded here: the caller always keeps
    # the source Cue timings, while this parser only extracts corrected text.
    lines = normalized.split("\n")
    if len(lines) == len(source) and all(
        re.match(r"^\s*\[[^\]\r\n]+\] [^\r\n]+$", line) for line in lines
    ):
        messages = []
        for line in lines:
            match = re.match(r"^\s*\[[^\]\r\n]+\] ([^\r\n]+)$", line)
            assert match is not None
            message = match.group(1)
            if not message.strip():
                raise RuntimeError("矫正模型输出了空字幕文本")
            messages.append(message)
        return messages

    # Keep accepting the previous SRT-shaped response for compatibility with
    # already-configured providers and older queued requests.
    blocks = re.split(r"\n[ \t]*\n", normalized)
    if len(blocks) != len(source):
        if not re.search(r"(?m)^\s*1\s*$", normalized):
            preview = " ".join(normalized.split())[:300]
            raise RuntimeError(f"矫正模型返回了非字幕内容：{preview}")
        raise RuntimeError("矫正模型改变了字幕条目数")
    messages: list[str] = []
    for index, (block, cue) in enumerate(
        zip(blocks, source), start=start_index
    ):
        lines = block.split("\n")
        if len(lines) < 3 or lines[0].strip() != str(index):
            raise RuntimeError("矫正模型改变了字幕序号或格式")
        # The returned timestamps are deliberately not trusted.  The caller
        # always rebuilds Cue objects from the source timestamps, so accepting
        # a harmless timestamp reformat here prevents one malformed timestamp
        # from discarding an otherwise useful correction batch.
        if "-->" not in lines[1]:
            raise RuntimeError("矫正模型改变了字幕结构")
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


def _lrc_time(value: float) -> str:
    total_millis = max(0, int(round(value * 1000)))
    minutes, rem = divmod(total_millis, 60_000)
    seconds, millis = divmod(rem, 1000)
    return f"[{minutes:02d}:{seconds:02d}.{millis:03d}]"
