from __future__ import annotations

import json

from ..models import AppSettings, CorrectionSettings, Cue


SYSTEM_PROMPT = (
    "你是日语 ASR 听写校对器。只修正识别错误、明显错字和同音误识别。"
    "不要翻译，不要改变说话风格，不要增删句子，不要合并或拆分条目。"
    "保留原有标点和语气词。输入是 JSON 数组，每项含 index 与 message。"
    "只输出同样结构的 JSON 数组，不要解释。"
)


def correct_cues(cues: list[Cue], settings: AppSettings) -> list[Cue]:
    endpoint = settings.correct
    if not endpoint.base_url or not endpoint.model:
        raise RuntimeError("未配置矫正模型的 API 地址与模型名")
    payload = [{"index": index, "message": cue.message} for index, cue in enumerate(cues)]
    content = _chat(endpoint, json.dumps(payload, ensure_ascii=False), settings.proxy)
    parsed = _extract_json(content)
    if not isinstance(parsed, list):
        raise RuntimeError("矫正模型未返回 JSON 数组")
    by_index = {}
    for item in parsed:
        if not isinstance(item, dict):
            continue
        by_index[int(item.get("index", -1))] = str(item.get("message") or "")
    out: list[Cue] = []
    for index, cue in enumerate(cues):
        message = by_index.get(index, cue.message).strip() or cue.message
        out.append(Cue(start=cue.start, end=cue.end, message=message, src_message=cue.src_message or cue.message))
    return out


def test_correct(settings: AppSettings) -> str:
    endpoint = settings.correct
    if not endpoint.base_url or not endpoint.model:
        raise RuntimeError("未配置矫正模型")
    content = _chat(endpoint, '[{"index":0,"message":"こんにちは"}]', settings.proxy)
    return content[:200] or "ok"


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


def _extract_json(text: str):
    stripped = text.strip()
    if stripped.startswith("```"):
        stripped = stripped.strip("`")
        if stripped.startswith("json"):
            stripped = stripped[4:]
        stripped = stripped.strip()
    start = stripped.find("[")
    end = stripped.rfind("]")
    if start < 0 or end < 0:
        raise RuntimeError("矫正模型输出无法解析为 JSON")
    return json.loads(stripped[start : end + 1])
