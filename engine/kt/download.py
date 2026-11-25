from __future__ import annotations

import http.client
import ipaddress
import socket
from pathlib import Path
from urllib.parse import urlsplit
from urllib.request import (
    HTTPHandler,
    HTTPRedirectHandler,
    HTTPSHandler,
    ProxyHandler,
    Request,
    build_opener,
)


DOWNLOAD_TIMEOUT_SECONDS = 60.0
DOWNLOAD_MAX_BYTES = 2 * 1024 * 1024 * 1024
DOWNLOAD_CHUNK_BYTES = 1024 * 1024


_ALLOWED_HEADERS = {"authorization", "cookie"}
_LAN_NETWORKS = tuple(
    ipaddress.ip_network(cidr)
    for cidr in ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "fc00::/7")
)


def _origin(url: str) -> tuple[str, str, int]:
    parsed = urlsplit(url)
    if (
        parsed.scheme not in {"http", "https"}
        or not parsed.hostname
        or parsed.username is not None
        or "%" in parsed.hostname
    ):
        raise ValueError("url must be an absolute http or https URL without credentials")
    port = parsed.port
    if port == 0:
        raise ValueError("download port must be between 1 and 65535")
    return parsed.scheme, parsed.hostname, port or (443 if parsed.scheme == "https" else 80)


def _ip(address: str) -> ipaddress.IPv4Address | ipaddress.IPv6Address:
    ip = ipaddress.ip_address(address)
    return getattr(ip, "ipv4_mapped", None) or ip


def _allowed_address(ip: ipaddress.IPv4Address | ipaddress.IPv6Address) -> bool:
    return not (ip.is_loopback or ip.is_link_local or ip.is_multicast or ip.is_reserved) and (
        ip.is_global or any(ip in network for network in _LAN_NETWORKS)
    )


def _uses_proxy_dns(addresses) -> bool:
    """FlClash fake-IP DNS answers are only meaningful to its HTTP proxy."""
    fake_network = ipaddress.ip_network("198.18.0.0/15")
    return bool(addresses) and all(
        _ip(item[4][0]) in fake_network for item in addresses
    )


def _connect(address, timeout, source_address):
    # Validate the exact addresses passed to connect(), with no second DNS lookup.
    resolved = socket.getaddrinfo(*address, type=socket.SOCK_STREAM)
    addresses = [
        item for item in resolved
        if _allowed_address(_ip(item[4][0]))
    ]
    if not addresses:
        raise ValueError("downloads to this network address are blocked")
    last_error = None
    for family, kind, protocol, _, destination in addresses:
        sock = socket.socket(family, kind, protocol)
        try:
            sock.settimeout(timeout)
            if source_address:
                sock.bind(source_address)
            sock.connect(destination)
            if _ip(sock.getsockname()[0]) == _ip(sock.getpeername()[0]):
                raise ValueError("downloads from this computer are blocked")
            return sock
        except OSError as exc:
            last_error = exc
            sock.close()
        except BaseException:
            sock.close()
            raise
    raise last_error


class _CheckedHTTPConnection(http.client.HTTPConnection):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._create_connection = _connect


class _CheckedHTTPSConnection(http.client.HTTPSConnection):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # HTTPSConnection still verifies TLS against the original hostname.
        self._create_connection = _connect


class _CheckedHTTPHandler(HTTPHandler):
    def http_open(self, req):
        return self.do_open(_CheckedHTTPConnection, req)


class _CheckedHTTPSHandler(HTTPSHandler):
    def https_open(self, req):
        return self.do_open(_CheckedHTTPSConnection, req)


class _DownloadRedirectHandler(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        try:
            changed_origin = _origin(newurl) != _origin(req.full_url)
            _, hostname, port = _origin(newurl)
            resolved = socket.getaddrinfo(hostname, port, type=socket.SOCK_STREAM)
            if not any(_allowed_address(_ip(item[4][0])) for item in resolved):
                if not _uses_proxy_dns(resolved):
                    raise ValueError("downloads to this network address are blocked")
            redirect = super().redirect_request(req, fp, code, msg, headers, newurl)
        except ValueError:
            fp.close()
            raise
        if redirect is not None and changed_origin:
            for header in _ALLOWED_HEADERS:
                redirect.remove_header(header.title())
        return redirect


def download_http_file(
    source_url: str,
    target: Path,
    headers: dict[str, str] | None = None,
    proxy: str = "",
) -> None:
    """Stream an HTTP(S) resource to a task-owned temporary file."""
    _origin(source_url)
    request_headers = {"User-Agent": "kikoeta-transl/1.0"}
    for key, value in (headers or {}).items():
        normalized = str(key).strip().lower()
        if normalized not in _ALLOWED_HEADERS:
            raise ValueError(f"unsupported download header: {key}")
        request_headers[key] = str(value)
    request = Request(source_url, headers=request_headers)
    parsed = urlsplit(source_url)
    host = parsed.hostname
    port = parsed.port or (443 if parsed.scheme == "https" else 80)
    try:
        addresses = socket.getaddrinfo(host, port, type=socket.SOCK_STREAM)
    except OSError:
        addresses = []
    if proxy and _uses_proxy_dns(addresses):
        opener = build_opener(
            ProxyHandler({"http": proxy, "https": proxy}),
            _DownloadRedirectHandler(),
        )
    else:
        # Direct connections pin the validated DNS result at connect time.
        if not addresses:
            raise OSError(f"could not resolve download host: {host}")
        if not any(_allowed_address(_ip(item[4][0])) for item in addresses):
            raise ValueError("downloads to this network address are blocked")
        opener = build_opener(
            ProxyHandler({}), _CheckedHTTPHandler(), _CheckedHTTPSHandler(),
            _DownloadRedirectHandler(),
        )
    with opener.open(request, timeout=DOWNLOAD_TIMEOUT_SECONDS) as response:
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
