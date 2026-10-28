"""Bind remote media to an operator-configured kikoeru source."""
from __future__ import annotations

import hashlib
import json
import re
from urllib.parse import unquote, urlsplit

from .models import OutputSettings

_SOURCE_ID = re.compile(r"[A-Za-z0-9_.-]{1,160}\Z")


def _url_parts(value: str) -> tuple[str, str, int, str]:
    parsed = urlsplit(value.strip())
    if (parsed.scheme not in {"http", "https"} or not parsed.hostname
            or parsed.username is not None or parsed.password is not None):
        raise ValueError("地址必须是 HTTP 或 HTTPS 服务地址")
    path = unquote(parsed.path or "/")
    if ("\\" in path or "\x00" in path or any(part in {".", ".."} for part in path.split("/"))):
        raise ValueError("地址包含无效路径")
    return parsed.scheme, parsed.hostname.lower(), parsed.port or (443 if parsed.scheme == "https" else 80), path


def delivery_endpoint(value: str) -> str:
    parsed = urlsplit(value.strip())
    _url_parts(value)
    if parsed.query or parsed.fragment:
        raise ValueError("外挂地址不能包含查询参数或片段")
    return value.strip().rstrip("/")


def output_binding(output: OutputSettings) -> str:
    endpoint = delivery_endpoint(output.kikoeru_url)
    source_id = output.kikoeru_source_id.strip()
    if not _SOURCE_ID.fullmatch(source_id):
        raise ValueError("请配置有效的 Kikoeru 外挂来源 ID")
    prefix = urlsplit(output.kikoeru_media_url_prefix.strip())
    origin = _url_parts(output.kikoeru_media_url_prefix)
    if prefix.query or prefix.fragment:
        raise ValueError("媒体 URL 前缀不能包含查询参数或片段")
    raw = [endpoint, source_id, origin]
    return hashlib.sha256(json.dumps(raw, ensure_ascii=False, separators=(",", ":")).encode()).hexdigest()


def matches_media_url(value: object, prefix: str) -> bool:
    if not isinstance(value, str):
        return False
    try:
        actual = _url_parts(value)
        expected = _url_parts(prefix)
    except (ValueError, TypeError):
        return False
    boundary = expected[3].rstrip("/")
    return actual[:3] == expected[:3] and (actual[3] == boundary or actual[3].startswith(boundary + "/"))


def bind_context(payload: dict, output: OutputSettings) -> dict[str, object]:
    cache = payload.get("cache")
    if not isinstance(cache, dict):
        return {}
    work_id = str(cache.get("work_id") or "").strip()
    paths = cache.get("track_paths")
    if not work_id or not isinstance(paths, list):
        return {}
    context: dict[str, object] = {"work_id": work_id, "track_paths": [str(path).strip() for path in paths]}
    if not output.kikoeru_sync:
        return context
    binding = output_binding(output)
    files = payload.get("files")
    if not isinstance(files, list) or len(paths) != len(files):
        raise ValueError("写回 Kikoeru 需要与输入文件一一对应的曲目路径")
    indices = [index for index, item in enumerate(files)
               if isinstance(item, dict) and matches_media_url(item.get("url"), output.kikoeru_media_url_prefix)]
    if indices:
        context.update(kikoeru_source_id=output.kikoeru_source_id.strip(), kikoeru_binding=binding,
                       kikoeru_indices=indices)
    return context
