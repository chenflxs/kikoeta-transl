from __future__ import annotations

from pathlib import Path
from urllib.parse import urlparse
from urllib.request import Request, urlopen


DOWNLOAD_TIMEOUT_SECONDS = 60.0
DOWNLOAD_MAX_BYTES = 2 * 1024 * 1024 * 1024
DOWNLOAD_CHUNK_BYTES = 1024 * 1024


_ALLOWED_HEADERS = {"authorization", "cookie"}


def download_http_file(
    source_url: str,
    target: Path,
    headers: dict[str, str] | None = None,
) -> None:
    """Stream an HTTP(S) resource to a task-owned temporary file."""
    parsed = urlparse(source_url)
    if parsed.scheme.lower() not in {"http", "https"} or not parsed.netloc:
        raise ValueError("url must be an absolute http or https URL")
    request_headers = {"User-Agent": "kikoeta-transl/1.0"}
    for key, value in (headers or {}).items():
        normalized = str(key).strip().lower()
        if normalized not in _ALLOWED_HEADERS:
            raise ValueError(f"unsupported download header: {key}")
        request_headers[key] = str(value)
    request = Request(source_url, headers=request_headers)
    with urlopen(request, timeout=DOWNLOAD_TIMEOUT_SECONDS) as response:
        final_url = urlparse(response.geturl())
        if final_url.scheme.lower() not in {"http", "https"}:
            raise ValueError("download redirect must use http or https")
        status = getattr(response, "status", 200)
        if not 200 <= status < 300:
            raise OSError(f"download failed with HTTP {status}")
        content_length = response.headers.get("Content-Length")
        if content_length and int(content_length) > DOWNLOAD_MAX_BYTES:
            raise ValueError("download exceeds the 2 GiB limit")
        written = 0
        with target.open("wb") as file:
            while chunk := response.read(DOWNLOAD_CHUNK_BYTES):
                written += len(chunk)
                if written > DOWNLOAD_MAX_BYTES:
                    raise ValueError("download exceeds the 2 GiB limit")
                file.write(chunk)
