from __future__ import annotations

import argparse
import base64
import hmac
import json
import sys
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse

ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from kt.jobs import Job, JobManager
from kt.kikoeta_cache import cached_file, list_cached_results
from kt.cleanup import cleanup_intermediates
from kt.download import download_http_file
from kt.models import AppSettings, JobRequest, StageFlags
from kt.settings import load_settings, save_settings
from kt.stages.correct import test_correct
from kt.llama_runtime import LLAMA_RUNTIME
from kt.tools import catalog, list_crispasr_models, list_llama_models, list_openai_models, resolve_ffmpeg
from kt.paths import WORK_DIR


MANAGER = JobManager()
HOST = "127.0.0.1"
PORT = 18765
PUBLIC_PORT = 2370
_LOCAL_SERVER: ThreadingHTTPServer | None = None
_PUBLIC_SERVER: ThreadingHTTPServer | None = None
_CLIENT_LAST_SEEN: float | None = None
_CLIENT_SEEN_LOCK = threading.Lock()
_CLIENT_WATCHDOG_STOP = threading.Event()
CLIENT_TIMEOUT_SECONDS = 5.0


class _EngineHTTPServer(ThreadingHTTPServer):
    """Allow the engine process to exit without waiting for long polls.

    Job event requests intentionally wait for new events for up to 20 seconds.
    They must not keep the desktop-owned engine alive after a shutdown request
    has already been accepted.
    """

    daemon_threads = True
    block_on_close = False


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format: str, *args) -> None:
        sys.stderr.write("%s - %s\n" % (self.address_string(), format % args))

    def do_OPTIONS(self) -> None:
        self._send(204, b"", content_type="text/plain")

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/") or "/"
        query = parse_qs(parsed.query)
        if not self._allow_request(path):
            return
        if path == "/api/v1/health":
            self._json({"ok": True, "name": "kikoeta-transl", "revision": 6, "service": "remote"})
            return
        if path == "/api/v1/cache":
            self._remote_cache_list()
            return
        if path.startswith("/api/v1/cache/"):
            self._remote_cache_get(path)
            return
        if path.startswith("/api/v1/jobs/"):
            self._remote_job_get(path, query)
            return
        if path == "/api/health":
            self._json({"ok": True, "name": "kikoeta-transl", "revision": 6})
            return
        if path == "/api/client-heartbeat":
            self._heartbeat()
            return
        if path == "/api/settings":
            self._json(load_settings().to_dict())
            return
        if path == "/api/tools":
            try:
                self._json(_tools())
            except Exception as exc:
                self._error(500, f"tools failed: {exc}")
            return
        if path == "/api/jobs":
            self._json({"jobs": [job.to_dict() for job in MANAGER.list()]})
            return
        if path.startswith("/api/jobs/"):
            parts = path.split("/")
            if len(parts) == 4:
                job = MANAGER.get(parts[3])
                if job is None:
                    self._error(404, "job not found")
                    return
                self._json(job.to_dict())
                return
            if len(parts) == 5 and parts[4] == "events":
                self._sse(parts[3], query)
                return
        self._error(404, "not found")

    def do_PUT(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/") or "/"
        if not self._allow_request(path):
            return
        if path == "/api/settings":
            payload = self._read_json()
            settings = AppSettings.from_dict(payload)
            save_settings(settings)
            self._json(settings.to_dict())
            return
        self._error(404, "not found")

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        if not self._allow_request(path):
            return
        if path == "/api/shutdown":
            # The local engine is owned by the desktop client.  Never expose
            # process shutdown to a remote client when remote access is on.
            if self.client_address[0] not in {"127.0.0.1", "::1"}:
                self._error(403, "shutdown is only available from localhost")
                return
            self._json({"ok": True})
            threading.Thread(target=_request_shutdown, daemon=True).start()
            return
        if path == "/api/client-heartbeat":
            self._heartbeat()
            return
        if path == "/api/v1/jobs":
            cleanup_paths: list[str] = []
            try:
                payload = self._read_json()
                files, cleanup_paths = _materialize_remote_files(payload.get("files") or [])
                flags_raw = payload.get("flags") or {}
                request = JobRequest(
                    files=files,
                    flags=StageFlags(
                        enable_correct=bool(flags_raw.get("enable_correct", False)),
                        enable_translate=bool(flags_raw.get("enable_translate", True)),
                    ),
                    settings_override=payload.get("settings") or {},
                    cleanup_paths=cleanup_paths,
                    cache_context=_remote_cache_context(payload),
                )
                job = MANAGER.create(request, source="kikoeta")
            except (ValueError, OSError, TypeError, base64.binascii.Error) as exc:
                cleanup_intermediates(*cleanup_paths)
                self._error(400, str(exc))
                return
            self._json(_remote_job_payload(job), status=201)
            return
        if path.startswith("/api/v1/jobs/") and path.endswith("/cancel"):
            job_id = path.split("/")[4]
            try:
                job = MANAGER.cancel(job_id)
            except KeyError:
                self._error(404, "job not found")
                return
            self._json(_remote_job_payload(job))
            return
        if path == "/api/jobs":
            payload = self._read_json()
            flags_raw = payload.get("flags") or {}
            request = JobRequest(
                files=list(payload.get("files") or []),
                flags=StageFlags(
                    enable_correct=bool(flags_raw.get("enable_correct", False)),
                    enable_translate=bool(flags_raw.get("enable_translate", True)),
                ),
                settings_override=payload.get("settings") or {},
            )
            try:
                job = MANAGER.create(request)
            except ValueError as exc:
                self._error(400, str(exc))
                return
            self._json(job.to_dict(), status=201)
            return
        if path.startswith("/api/jobs/") and path.endswith("/cancel"):
            job_id = path.split("/")[3]
            try:
                job = MANAGER.cancel(job_id)
            except KeyError:
                self._error(404, "job not found")
                return
            self._json(job.to_dict())
            return
        if path == "/api/test/correct":
            try:
                message = test_correct(load_settings())
                self._json({"ok": True, "message": message})
            except Exception as exc:
                self._error(400, str(exc))
            return
        if path == "/api/test/translate":
            settings = load_settings()
            if settings.translate.provider == "local_llama" and not settings.llama_model:
                self._error(400, "未选择本地 Llama 模型")
                return
            if (
                settings.translate.provider != "local_llama"
                and not settings.translate.openai.base_url
                and "sakura" not in settings.translate.translator
            ):
                self._error(400, "未配置翻译后端")
                return
            self._json({"ok": True, "message": "配置已保存，将在任务中调用翻译模块"})
            return
        if path == "/api/models/openai":
            try:
                payload = self._read_json()
                settings = load_settings()
                kind = str(payload.get("kind") or "")
                if kind == "correct":
                    base = payload.get("base_url") or settings.correct.base_url
                    key = payload.get("api_key") or settings.correct.api_key
                elif kind == "translate":
                    base = payload.get("base_url") or settings.translate.openai.base_url
                    key = payload.get("api_key") or settings.translate.openai.api_key
                else:
                    base = payload.get("base_url") or ""
                    key = payload.get("api_key") or ""
                models = list_openai_models(str(base or ""), str(key or ""), settings.proxy)
            except Exception as exc:
                self._error(400, str(exc))
                return
            self._json({"ok": True, "models": models})
            return
        self._error(404, "not found")

    def _remote_job_get(self, path: str, query: dict[str, list[str]]) -> None:
        parts = path.split("/")
        if len(parts) < 5:
            self._error(404, "job not found")
            return
        job = MANAGER.get(parts[4])
        if job is None:
            self._error(404, "job not found")
            return
        if len(parts) == 5:
            self._json(_remote_job_payload(job))
            return
        if len(parts) == 6 and parts[5] == "events":
            self._sse(parts[4], query)
            return
        if len(parts) == 6 and parts[5] == "outputs":
            outputs = [output for result in job.results for output in result.outputs]
            self._json({"job_id": job.job_id, "outputs": outputs})
            return
        if len(parts) == 7 and parts[5] == "files":
            try:
                index = int(parts[6])
                output = [output for result in job.results for output in result.outputs][index]
                file_path = Path(output).resolve()
                if not file_path.is_file():
                    raise FileNotFoundError(output)
                self._send(200, file_path.read_bytes(), content_type="application/octet-stream")
            except (ValueError, IndexError, OSError) as exc:
                self._error(404, str(exc))
            return
        self._error(404, "not found")

    def _remote_cache_list(self) -> None:
        entries = list_cached_results()
        for entry in entries:
            for index, item in enumerate(entry["files"]):
                item["download_url"] = (
                    f"/api/v1/cache/{entry['job_id']}/files/{index}"
                )
        self._json({"entries": entries})

    def _remote_cache_get(self, path: str) -> None:
        parts = path.split("/")
        if len(parts) != 7 or parts[5] != "files":
            self._error(404, "not found")
            return
        try:
            file_path = cached_file(parts[4], int(parts[6]))
            self._send(
                200,
                file_path.read_bytes(),
                content_type="application/octet-stream",
            )
        except (ValueError, OSError):
            self._error(404, "cached file not found")

    def _sse(self, job_id: str, query: dict[str, list[str]]) -> None:
        job = MANAGER.get(job_id)
        if job is None:
            self._error(404, "job not found")
            return
        after = int((query.get("after") or ["0"])[0] or 0)
        events, cursor, closed = job.bus.listen(after=after, timeout=20)
        self._json({"events": events, "cursor": cursor, "closed": closed})

    def _read_json(self) -> dict:
        length = int(self.headers.get("content-length") or 0)
        if length <= 0:
            return {}
        raw = self.rfile.read(length)
        if not raw:
            return {}
        return json.loads(raw.decode("utf-8"))

    def _allow_request(self, path: str) -> bool:
        is_public_service = self.server.server_address[1] == PUBLIC_PORT
        if is_public_service and not _is_remote_api_path(path):
            self._error(404, "not found")
            return False
        if not _is_remote_api_path(path):
            return True
        settings = load_settings()
        if _valid_remote_authorization(
            self.headers.get("authorization"),
            settings.remote_username,
            settings.remote_password,
        ):
            return True
        self._unauthorized()
        return False

    def _unauthorized(self) -> None:
        data = json.dumps({"error": "需要有效的 kikoeta-transl 用户名和密码"}, ensure_ascii=False).encode("utf-8")
        self._send(
            401,
            data,
            content_type="application/json; charset=utf-8",
            extra_headers={"www-authenticate": 'Basic realm="kikoeta-transl", charset="UTF-8"'},
        )

    def _heartbeat(self) -> None:
        if self.client_address[0] not in {"127.0.0.1", "::1"}:
            self._error(403, "client heartbeat is only available from localhost")
            return
        global _CLIENT_LAST_SEEN
        with _CLIENT_SEEN_LOCK:
            _CLIENT_LAST_SEEN = time.monotonic()
        self._json({"ok": True})

    def _json(self, payload: dict, status: int = 200) -> None:
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self._send(status, data, content_type="application/json; charset=utf-8")

    def _error(self, status: int, message: str) -> None:
        self._json({"error": message}, status=status)

    def _send(
        self,
        status: int,
        body: bytes,
        content_type: str,
        extra_headers: dict[str, str] | None = None,
    ) -> None:
        self.send_response(status)
        self.send_header("content-type", content_type)
        self.send_header("content-length", str(len(body)))
        self.send_header("access-control-allow-origin", "*")
        self.send_header("access-control-allow-methods", "GET,POST,PUT,OPTIONS")
        self.send_header("access-control-allow-headers", "content-type, authorization")
        for key, value in (extra_headers or {}).items():
            self.send_header(key, value)
        self.end_headers()
        if body:
            self.wfile.write(body)

    def end_headers(self) -> None:
        self.send_header("cache-control", "no-store")
        super().end_headers()


def _tools() -> dict:
    settings = load_settings()
    ffmpeg = ""
    ffprobe = ""
    ffmpeg_error = ""
    try:
        ffmpeg, ffprobe = resolve_ffmpeg(settings)
    except Exception as exc:
        ffmpeg_error = str(exc)
    try:
        asr = list_crispasr_models(settings)
    except Exception as exc:
        asr = {"models": [], "aligners": [], "executable": "", "backends": [], "error": str(exc)}
    try:
        llama = list_llama_models(settings)
        llama.update(LLAMA_RUNTIME.status())
    except Exception as exc:
        llama = {"models": [], "executable": "", "status": "error", "error": str(exc)}
    payload = {
        "ffmpeg": ffmpeg,
        "ffprobe": ffprobe,
        "ffmpeg_error": ffmpeg_error,
        "asr": asr,
        "llama": llama,
    }
    try:
        payload.update(catalog())
    except Exception as exc:
        payload["gt_dicts"] = []
        payload["dict_error"] = str(exc)
    return payload


def _valid_remote_authorization(
    header: str | None,
    username: str,
    password: str,
) -> bool:
    if not header or not header.lower().startswith("basic "):
        return False
    try:
        encoded = header.split(None, 1)[1].strip()
        decoded = base64.b64decode(encoded, validate=True).decode("utf-8")
        supplied_username, separator, supplied_password = decoded.partition(":")
        if not separator:
            return False
    except (ValueError, UnicodeDecodeError, base64.binascii.Error):
        return False
    username_matches = hmac.compare_digest(
        supplied_username.encode("utf-8"), username.encode("utf-8")
    )
    password_matches = hmac.compare_digest(
        supplied_password.encode("utf-8"), password.encode("utf-8")
    )
    return username_matches & password_matches


def _is_remote_api_path(path: str) -> bool:
    return path.startswith("/api/v1/")


def main() -> None:
    global _LOCAL_SERVER, _PUBLIC_SERVER, _CLIENT_LAST_SEEN
    parser = argparse.ArgumentParser(description="Kikoeta Transl engine")
    parser.add_argument("--host", default=HOST)
    parser.add_argument("--port", type=int, default=PORT)
    args = parser.parse_args()
    server = _EngineHTTPServer((args.host, args.port), Handler)
    _LOCAL_SERVER = server
    with _CLIENT_SEEN_LOCK:
        _CLIENT_LAST_SEEN = None
    _CLIENT_WATCHDOG_STOP.clear()
    threading.Thread(target=_client_watchdog, daemon=True).start()
    settings = load_settings()
    public_host = "0.0.0.0" if settings.remote_access else "127.0.0.1"
    try:
        public_server = _EngineHTTPServer((public_host, PUBLIC_PORT), Handler)
        _PUBLIC_SERVER = public_server
        threading.Thread(target=public_server.serve_forever, daemon=True).start()
        print(
            f"kikoeta-transl service listening on http://{public_host}:{PUBLIC_PORT}",
            flush=True,
        )
    except OSError as exc:
        print(
            f"kikoeta-transl service unavailable on {public_host}:{PUBLIC_PORT}: {exc}",
            file=sys.stderr,
            flush=True,
        )
    print(f"kikoeta-transl engine listening on http://{args.host}:{args.port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        _CLIENT_WATCHDOG_STOP.set()
        LLAMA_RUNTIME.shutdown()
        server.server_close()
        if _PUBLIC_SERVER is not None:
            _PUBLIC_SERVER.shutdown()
            _PUBLIC_SERVER.server_close()
            _PUBLIC_SERVER = None
        _LOCAL_SERVER = None


def _client_watchdog() -> None:
    while not _CLIENT_WATCHDOG_STOP.wait(1.0):
        with _CLIENT_SEEN_LOCK:
            last_seen = _CLIENT_LAST_SEEN
        if last_seen is None:
            continue
        if time.monotonic() - last_seen >= CLIENT_TIMEOUT_SECONDS:
            print(
                "desktop client heartbeat lost for 5 seconds; shutting down engine",
                flush=True,
            )
            threading.Thread(target=_request_shutdown, daemon=True).start()
            return


def _request_shutdown() -> None:
    """Stop active jobs and wake both HTTP server loops."""
    # Let the shutdown response finish before stopping the serving loop.
    time.sleep(0.1)
    MANAGER.shutdown()
    local_server = _LOCAL_SERVER
    if local_server is not None:
        local_server.shutdown()


def _materialize_remote_files(items: object) -> tuple[list[str], list[str]]:
    if not isinstance(items, list):
        raise ValueError("files must be a list")
    upload_dir = WORK_DIR / "remote" / uuid.uuid4().hex
    paths: list[str] = []
    cleanup_paths: list[str] = []
    try:
        for index, item in enumerate(items):
            if isinstance(item, str) and item.strip():
                paths.append(item)
                continue
            if not isinstance(item, dict):
                raise ValueError(f"invalid file at index {index}")
            encoded = str(item.get("content_base64") or "")
            source_url = str(item.get("url") or "").strip()
            if bool(encoded) == bool(source_url):
                raise ValueError(f"file at index {index} must provide exactly one of content_base64 or url")
            name = _remote_file_name(item.get("name"), source_url, index)
            upload_dir.mkdir(parents=True, exist_ok=True)
            if not cleanup_paths:
                cleanup_paths.append(str(upload_dir))
            target = upload_dir / f"{index:03d}_{name}"
            if source_url:
                headers = item.get("headers") or {}
                if not isinstance(headers, dict):
                    raise ValueError(f"headers for file at index {index} must be an object")
                download_http_file(
                    source_url,
                    target,
                    {str(key): str(value) for key, value in headers.items()},
                )
            else:
                target.write_bytes(base64.b64decode(encoded, validate=True))
            paths.append(str(target))
        if not paths:
            raise ValueError("没有输入文件")
        return paths, cleanup_paths
    except Exception:
        cleanup_intermediates(*cleanup_paths)
        raise


def _remote_file_name(value: object, source_url: str, index: int) -> str:
    name = Path(str(value or "")).name
    if not name and source_url:
        name = Path(unquote(urlparse(source_url).path)).name
    return name or f"input_{index}"


def _remote_cache_context(payload: dict) -> dict[str, object]:
    raw = payload.get("cache")
    if not isinstance(raw, dict):
        return {}
    work_id = str(raw.get("work_id") or "").strip()
    paths = raw.get("track_paths")
    if not work_id or not isinstance(paths, list):
        return {}
    return {
        "work_id": work_id,
        "track_paths": [str(path).strip() for path in paths],
    }




def _remote_job_payload(job: Job) -> dict:
    index = 0
    results = []
    for result in job.results:
        urls = [f"/api/v1/jobs/{job.job_id}/files/{index + offset}" for offset, _ in enumerate(result.outputs)]
        index += len(result.outputs)
        results.append(result.to_dict() | {"download_urls": urls})
    return job.to_dict() | {"results": results}


if __name__ == "__main__":
    main()
