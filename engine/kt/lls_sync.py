"""Upload completed Kikoeta translation outputs to Kikoeta-LLS."""

from __future__ import annotations

import base64
import json
import re
from pathlib import Path
from typing import Any
from urllib.error import HTTPError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen

from .models import OutputSettings


_WORK_ID = re.compile(r"(?:RJ|VJ|BJ)[0-9]+", re.IGNORECASE)
_KEY = re.compile(r"[A-Za-z0-9]{12}")
_INVALID_PART = re.compile(r'[<>:"/\\|?*\x00-\x1f]')
_LYRIC_EXTS = {".lrc", ".srt", ".vtt", ".ass", ".ssa", ".txt"}
_MAX_FILE_BYTES = 8 * 1024 * 1024


def _safe_part(value: str) -> str:
    return _INVALID_PART.sub("_", value).rstrip(". ").strip()


def lyric_path(track_path: str, extension: str) -> str:
    """Match Kikoeta's track-to-lyrics path, without the work ID prefix."""
    parts = [_safe_part(part) for part in track_path.replace("\\", "/").split("/")
             if part and part not in {".", ".."}]
    parts = [part for part in parts if part]
    leaf = parts.pop() if parts else "track"
    stem = leaf.rsplit(".", 1)[0] if "." in leaf[1:] else leaf
    parts.append(f"{stem or 'track'}.zh{extension}")
    return "/".join(parts)


def _endpoint(value: str) -> str:
    base = value.strip() or "http://127.0.0.1:2378"
    parsed = urlsplit(base)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname or parsed.username or parsed.password or parsed.query or parsed.fragment:
        raise ValueError("Kikoeta-LLS 地址必须是 HTTP 或 HTTPS 服务地址")
    return base.rstrip("/") + "/api/v1/lyrics"


def _authorization(output: OutputSettings) -> str:
    if output.lls_auth_mode == "basic":
        if not output.lls_username or not output.lls_password:
            raise ValueError("请配置 Kikoeta-LLS 上传账号和密码")
        token = base64.b64encode(f"{output.lls_username}:{output.lls_password}".encode()).decode("ascii")
        return f"Basic {token}"
    if not _KEY.fullmatch(output.lls_key):
        raise ValueError("请配置 12 位 Kikoeta-LLS 上传密钥")
    return f"Bearer {output.lls_key}"


def sync_completed_job(job: Any, output: OutputSettings) -> int:
    if not output.lls_sync or job.source != "kikoeta" or job.status != "completed":
        return 0
    work_id = str(job.cache_context.get("work_id") or "").strip().upper()
    track_paths = job.cache_context.get("track_paths")
    if not _WORK_ID.fullmatch(work_id) or not isinstance(track_paths, list):
        raise ValueError("Kikoeta 请求缺少有效作品号或曲目路径，无法同步到 LLS")
    endpoint = _endpoint(output.lls_url)
    authorization = _authorization(output)
    uploaded = 0
    for index, result in enumerate(job.results):
        track_path = str(track_paths[index]) if index < len(track_paths) else ""
        if not track_path:
            continue
        used_paths: set[str] = set()
        for output_path in result.outputs:
            source = Path(output_path)
            extension = source.suffix.lower()
            if extension not in _LYRIC_EXTS or not source.is_file():
                continue
            relative_path = lyric_path(track_path, extension)
            if relative_path in used_paths:
                relative_path = relative_path[: -len(extension)] + f"-{len(used_paths)}{extension}"
            used_paths.add(relative_path)
            content = source.read_bytes()
            if not content or len(content) > _MAX_FILE_BYTES:
                raise ValueError(f"歌词文件大小无效：{source.name}")
            payload = json.dumps({
                "workId": work_id,
                "files": [{"relativePath": relative_path, "content": base64.b64encode(content).decode("ascii")}],
            }).encode("utf-8")
            request = Request(endpoint, data=payload, headers={
                "Content-Type": "application/json", "Authorization": authorization,
            }, method="POST")
            try:
                with urlopen(request, timeout=60) as response:
                    response.read(4096)
            except HTTPError as exc:
                raise RuntimeError(f"Kikoeta-LLS 上传失败（HTTP {exc.code}）") from exc
            uploaded += 1
    return uploaded
