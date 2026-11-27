from __future__ import annotations

import argparse
import base64
import hmac
import json
import re
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
from kt.lls_sync import sync_cached_lyric
from kt.cleanup import cleanup_intermediates
from kt.download import download_http_file
from kt.crispasr_update import CrispAsrUpdater, local_status as crispasr_status
from kt.models import AppSettings, JobRequest, OUTPUT_PRESETS, StageFlags
from kt.recent import (
    delete_all_recent_jobs,
    delete_recent_job,
    delete_translation_cache,
    list_recent_jobs,
)
from kt.settings import DEFAULT_REMOTE_PASSWORD, load_settings, save_settings
from kt.secure_store import SecretStoreError
from kt.stages.correct import test_correct
from kt.llama_runtime import LLAMA_RUNTIME
from kt.tools import (
    SOURCE_LANGS, TARGET_LANGS, catalog, list_crispasr_models,
    list_llama_models, list_openai_models, resolve_ffmpeg,
)
from kt.paths import WORK_DIR


MANAGER = JobManager()
CRISPASR_UPDATER = CrispAsrUpdater(MANAGER.tool_update_guard)
HOST = "127.0.0.1"
PORT = 18765
PUBLIC_PORT = 2370
API_REVISION = 8
CONTROL_JSON_MAX_BYTES = 2 * 1024 * 1024
REMOTE_JOB_JSON_MAX_BYTES = 64 * 1024 * 1024
JSON_READ_TIMEOUT_SECONDS = 30
_LOOPBACK_HOSTS = {"127.0.0.1", "localhost"}
_REMOTE_LANGUAGE_VALUES = {
    "source_lang": {value["id"] for value in SOURCE_LANGS},
    "target_lang": {value["id"] for value in TARGET_LANGS},
}
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

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/") or "/"
        query = parse_qs(parsed.query)
        if not self._allow_request(path):
            return
        if path == "/api/v1/health":
            self._json({"ok": True, "name": "kikoeta-transl", "revision": API_REVISION, "service": "remote"})
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
            self._json({"ok": True, "name": "kikoeta-transl", "revision": API_REVISION})
            return
        if path == "/api/client-heartbeat":
            self._heartbeat()
            return
        if path == "/api/settings":
            self._json(load_settings().to_dict())
            return
        if path in {"/api/crispasr", "/api/crispasr/releases", "/api/crispasr/update"}:
            if self.client_address[0] not in {"127.0.0.1", "::1"}:
                self._error(403, "CrispASR management is only available from localhost")
                return
            try:
                if path.endswith("/releases"):
                    payload = CRISPASR_UPDATER.releases(load_settings())
                elif path.endswith("/update"):
                    payload = CRISPASR_UPDATER.status()
                else:
                    payload = crispasr_status(load_settings())
                self._json(payload)
            except Exception as exc:
                self._error(400, str(exc))
            return
        if path == "/api/lls/cache":
            self._json({"entries": list_cached_results()})
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
        if path == "/api/recent":
            if self.client_address[0] not in {"127.0.0.1", "::1"}:
                self._error(403, "recent jobs are only available from localhost")
                return
            active = {job.job_id for job in MANAGER.list()
                      if job.is_unfinished}
            self._json({"entries": list_recent_jobs(active)})
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
            if payload is None:
                return
            settings = AppSettings.from_dict(payload)
            try:
                save_settings(settings)
            except SecretStoreError as exc:
                self._error(500, f"无法加密保存设置：{exc}")
                return
            self._json(settings.to_dict())
            return
        self._error(404, "not found")

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        if not self._allow_request(path):
            return
        if path.startswith("/api/lls/cache/"):
            parts = path.split("/")
            if len(parts) != 7 or parts[5] != "files":
                self._error(404, "not found")
                return
            try:
                sync_cached_lyric(unquote(parts[4]), int(parts[6]), load_settings().output)
            except FileNotFoundError:
                self._error(404, "缓存已失效或文件不存在，请重新推送")
            except ValueError as exc:
                self._error(400, str(exc))
            except (OSError, RuntimeError) as exc:
                self._error(502, f"推送失败：{exc}")
            else:
                self._json({"uploaded": 1})
            return
        if path in {"/api/crispasr/update", "/api/crispasr/cancel"}:
            if self.client_address[0] not in {"127.0.0.1", "::1"}:
                self._error(403, "CrispASR management is only available from localhost")
                return
            try:
                if path.endswith("/cancel"):
                    payload = CRISPASR_UPDATER.cancel()
                else:
                    body = self._read_json()
                    if body is None:
                        return
                    with MANAGER.tool_update_guard():
                        pass
                    payload = CRISPASR_UPDATER.start(load_settings(), int(body["asset_id"]))
                self._json(payload)
            except RuntimeError as exc:
                self._error(409, str(exc))
            except Exception as exc:
                self._error(400, str(exc))
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
                payload = self._read_json(REMOTE_JOB_JSON_MAX_BYTES)
                if payload is None:
                    return
                override = _remote_settings_override(payload.get("settings"))
                cache_context = _remote_cache_context(payload)
                flags_raw = payload.get("flags") or {}
                if not isinstance(flags_raw, dict):
                    raise ValueError("flags must be an object")
                files, cleanup_paths = _materialize_remote_files(payload.get("files"))
                request = JobRequest(
                    files=files,
                    flags=StageFlags(
                        enable_correct=True,
                        enable_translate=bool(flags_raw.get("enable_translate", True)),
                    ),
                    settings_override=override,
                    cleanup_paths=cleanup_paths,
                    cache_context=cache_context,
                )
                job = MANAGER.create(
                    request, source="kikoeta",
                    resume_existing=payload.get("resume_existing") is not False,
                )
            except RuntimeError as exc:
                cleanup_intermediates(*cleanup_paths)
                self._error(409, str(exc))
                return
            except (ValueError, OSError, TypeError) as exc:
                cleanup_intermediates(*cleanup_paths)
                self._error(400, str(exc))
                return
            self._json(_remote_job_payload(job), status=201)
            return
        if self._job_action(path, remote=True):
            return
        if path == "/api/jobs":
            payload = self._read_json()
            if payload is None:
                return
            flags_raw = payload.get("flags") or {}
            additional_context = payload.get("additional_context", "")
            if not isinstance(additional_context, str):
                self._error(400, "additional_context must be text")
                return
            request = JobRequest(
                files=list(payload.get("files") or []),
                flags=StageFlags(
                    enable_correct=bool(flags_raw.get("enable_correct", True)),
                    enable_translate=bool(flags_raw.get("enable_translate", True)),
                ),
                settings_override=payload.get("settings") or {},
                additional_context=additional_context.strip(),
            )
            try:
                job = MANAGER.create(request)
            except RuntimeError as exc:
                self._error(409, str(exc))
                return
            except ValueError as exc:
                self._error(400, str(exc))
                return
            self._json(job.to_dict(), status=201)
            return
        if self._job_action(path, remote=False):
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
                if payload is None:
                    return
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
                models = list_openai_models(
                    str(base or ""),
                    str(key or ""),
                    settings.proxy,
                    index_compat=(
                        kind == "translate" and settings.translate.index_compat
                    ),
                )
            except Exception as exc:
                self._error(400, str(exc))
                return
            self._json({"ok": True, "models": models})
            return
        self._error(404, "not found")

    def _job_action(self, path: str, *, remote: bool) -> bool:
        parts = path.strip("/").split("/")
        prefix = ["api", "v1", "jobs"] if remote else ["api", "jobs"]
        if len(parts) != len(prefix) + 2 or parts[:len(prefix)] != prefix:
            return False
        job_id, action = parts[-2:]
        if action not in {"cancel", "preempt", "resume"}:
            return False
        try:
            # Drain the POST body before replying. Closing an HTTP/1.0 socket
            # with unread incoming bytes can reset an otherwise valid response.
            if self._read_json() is None:
                return True
            if remote:
                existing = MANAGER.get(job_id)
                if existing is None or existing.source != "kikoeta":
                    raise KeyError(job_id)
            if action == "preempt":
                job = MANAGER.preempt(job_id)
            elif action == "resume":
                job = MANAGER.resume(job_id)
            else:
                job = MANAGER.cancel(job_id)
        except KeyError:
            self._error(404, "job not found")
        except ValueError as exc:
            self._error(400, str(exc))
        except RuntimeError as exc:
            self._error(409, str(exc))
        else:
            self._json(_remote_job_payload(job) if remote else job.to_dict())
        return True

    def _remote_job_get(self, path: str, query: dict[str, list[str]]) -> None:
        parts = path.split("/")
        if len(parts) < 5:
            self._error(404, "job not found")
            return
        job = MANAGER.get(parts[4])
        if job is None or job.source != "kikoeta":
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

    def do_DELETE(self) -> None:
        path = urlparse(self.path).path.rstrip("/")
        if not self._allow_request(path):
            return
        parts = path.split("/")
        if parts[1:3] != ["api", "recent"]:
            self._error(404, "not found")
            return
        if self.client_address[0] not in {"127.0.0.1", "::1"}:
            self._error(403, "recent jobs are only available from localhost")
            return
        if len(parts) == 3:
            active = {job.job_id for job in MANAGER.list()
                      if job.is_unfinished}
            try:
                deleted = delete_all_recent_jobs(active)
            except OSError as exc:
                self._error(500, f"删除最近记录失败：{exc}")
                return
            self._json({"ok": True, "deleted_count": deleted})
            return
        if len(parts) == 4:
            job_id = parts[3]
            job = MANAGER.get(job_id)
            if job is not None and job.is_unfinished:
                self._error(409, "任务仍在运行或暂存，不能删除记录")
                return
            try:
                delete_recent_job(job_id)
            except (ValueError, FileNotFoundError):
                self._error(404, "recent job not found")
                return
            except OSError as exc:
                self._error(500, f"删除记录失败：{exc}")
                return
            self._json({"ok": True})
            return
        if len(parts) != 5 or parts[4] != "cache":
            self._error(404, "not found")
            return
        job_id = parts[3]
        job = MANAGER.get(job_id)
        if job is not None and job.is_unfinished:
            self._error(409, "任务仍在运行或暂存，不能清理缓存")
            return
        try:
            freed = delete_translation_cache(job_id)
        except (ValueError, FileNotFoundError):
            self._error(404, "cache not found")
            return
        except OSError as exc:
            self._error(500, f"清理缓存失败：{exc}")
            return
        self._json({"ok": True, "freed_bytes": freed})

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

    def _read_json(self, limit: int = CONTROL_JSON_MAX_BYTES) -> dict | None:
        lengths = self.headers.get_all("content-length", [])
        if self.headers.get("transfer-encoding") is not None or len(lengths) > 1:
            self._error(400, "expected a single Content-Length without Transfer-Encoding")
            return None
        if not lengths:
            return {}
        try:
            if re.fullmatch(r"[0-9]+", lengths[0].strip()) is None:
                raise ValueError
            length = int(lengths[0])
        except ValueError:
            self._error(400, "invalid Content-Length")
            return None
        if length > limit:
            self._error(413, f"JSON request exceeds the {limit // (1024 * 1024)} MiB limit")
            return None
        if length == 0:
            return {}
        original_timeout = self.connection.gettimeout()
        self.connection.settimeout(JSON_READ_TIMEOUT_SECONDS)
        try:
            raw = self.rfile.read(length)
        except TimeoutError:
            self._error(408, "timed out reading JSON request")
            return None
        finally:
            self.connection.settimeout(original_timeout)
        try:
            if len(raw) != length:
                raise ValueError
            data = json.loads(raw.decode("utf-8"))
            if not isinstance(data, dict):
                raise ValueError
        except (ValueError, RecursionError):
            self._error(400, "expected a complete JSON object")
            return None
        return data

    def _allow_request(self, path: str) -> bool:
        if self.headers.get("origin") is not None:
            self._error(403, "browser origins are not allowed")
            return False
        is_public_service = self.server is _PUBLIC_SERVER
        if not is_public_service:
            hosts = self.headers.get_all("host", [])
            port = self.server.server_address[1]
            allowed_hosts = {f"{host}:{port}" for host in _LOOPBACK_HOSTS}
            if port == 80:
                allowed_hosts.update(_LOOPBACK_HOSTS)
            if len(hosts) != 1 or hosts[0].lower() not in allowed_hosts:
                self._error(403, "invalid local engine host")
                return False
        if is_public_service and not _is_remote_api_path(path):
            self._error(404, "not found")
            return False
        if not _is_remote_api_path(path):
            return True
        settings = load_settings()
        if self.client_address[0] != HOST and not settings.remote_access:
            self._error(403, "LAN remote access is disabled")
            return False
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
        asr = list_crispasr_models(settings, probe_backends=True)
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
        encoded = header[6:].strip()
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
    parser.add_argument("--host", default=HOST, choices=sorted(_LOOPBACK_HOSTS))
    parser.add_argument("--port", type=int, default=PORT)
    args = parser.parse_args()
    server = _EngineHTTPServer((args.host, args.port), Handler)
    _LOCAL_SERVER = server
    with _CLIENT_SEEN_LOCK:
        _CLIENT_LAST_SEEN = None
    _CLIENT_WATCHDOG_STOP.clear()
    threading.Thread(target=_client_watchdog, daemon=True).start()
    settings = load_settings()
    public_host = "0.0.0.0" if settings.remote_access else HOST
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
            if not isinstance(item, dict):
                raise ValueError(f"file at index {index} must be an object containing content_base64 or url")
            encoded = item.get("content_base64", "")
            source_url = item.get("url", "")
            if not isinstance(encoded, str) or not isinstance(source_url, str):
                raise ValueError(f"content_base64 and url at index {index} must be strings")
            source_url = source_url.strip()
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
    return re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", name).rstrip(" .") or f"input_{index}"


def _remote_settings_override(raw: object) -> dict:
    if raw is None:
        return {}
    if not isinstance(raw, dict):
        raise ValueError("settings must be an object")
    for key, value in raw.items():
        if key in _REMOTE_LANGUAGE_VALUES:
            if not isinstance(value, str) or value not in _REMOTE_LANGUAGE_VALUES[key]:
                raise ValueError(f"unsupported {key}")
        elif key == "output":
            if not isinstance(value, dict):
                raise ValueError("settings.output must be an object")
            for field, option in value.items():
                if field == "preset" and option in OUTPUT_PRESETS:
                    continue
                if field == "formats" and isinstance(option, list) and option in (["lrc"], ["srt"]):
                    continue
                if field == "bilingual" and isinstance(option, bool):
                    continue
                raise ValueError(f"unsupported output setting: {field}")
        else:
            raise ValueError(f"unsupported remote setting: {key}")
    return raw


def _remote_cache_context(payload: dict) -> dict[str, object]:
    from kt.kikoeta_cache import source_base
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
        "source_base": source_base(raw.get("source_base")),
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
