from __future__ import annotations

import argparse
import base64
import json
import sys
import threading
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from kt.jobs import Job, JobManager
from kt.models import AppSettings, JobRequest, StageFlags
from kt.settings import load_settings, save_settings
from kt.stages.correct import test_correct
from kt.tools import catalog, list_crispasr_models, list_openai_models, list_uvr_models, resolve_ffmpeg
from kt.paths import WORK_DIR


MANAGER = JobManager()
HOST = "127.0.0.1"
PORT = 18765
PUBLIC_PORT = 2370


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format: str, *args) -> None:
        sys.stderr.write("%s - %s\n" % (self.address_string(), format % args))

    def do_OPTIONS(self) -> None:
        self._send(204, b"", content_type="text/plain")

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/") or "/"
        query = parse_qs(parsed.query)
        if path == "/api/v1/health":
            self._json({"ok": True, "name": "kikoeta-transl", "revision": 3, "service": "remote"})
            return
        if path.startswith("/api/v1/jobs/"):
            self._remote_job_get(path, query)
            return
        if path == "/api/health":
            self._json({"ok": True, "name": "kikoeta-transl", "revision": 3})
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
        if parsed.path.rstrip("/") == "/api/settings":
            payload = self._read_json()
            settings = AppSettings.from_dict(payload)
            save_settings(settings)
            self._json(settings.to_dict())
            return
        self._error(404, "not found")

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        if path == "/api/v1/jobs":
            try:
                payload = self._read_json()
                files = _materialize_remote_files(payload.get("files") or [])
                flags_raw = payload.get("flags") or {}
                request = JobRequest(
                    files=files,
                    flags=StageFlags(
                        enable_uvr=bool(flags_raw.get("enable_uvr", False)),
                        enable_correct=bool(flags_raw.get("enable_correct", False)),
                        enable_translate=bool(flags_raw.get("enable_translate", True)),
                    ),
                    settings_override=payload.get("settings") or {},
                )
                job = MANAGER.create(request)
            except (ValueError, OSError, TypeError, base64.binascii.Error) as exc:
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
                    enable_uvr=bool(flags_raw.get("enable_uvr", False)),
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
            if not settings.translate.openai.base_url and "sakura" not in settings.translate.translator:
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

    def _json(self, payload: dict, status: int = 200) -> None:
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self._send(status, data, content_type="application/json; charset=utf-8")

    def _error(self, status: int, message: str) -> None:
        self._json({"error": message}, status=status)

    def _send(self, status: int, body: bytes, content_type: str) -> None:
        self.send_response(status)
        self.send_header("content-type", content_type)
        self.send_header("content-length", str(len(body)))
        self.send_header("access-control-allow-origin", "*")
        self.send_header("access-control-allow-methods", "GET,POST,PUT,OPTIONS")
        self.send_header("access-control-allow-headers", "content-type")
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
        uvr_models = list_uvr_models(settings)
    except Exception:
        uvr_models = []
    payload = {
        "ffmpeg": ffmpeg,
        "ffprobe": ffprobe,
        "ffmpeg_error": ffmpeg_error,
        "asr": asr,
        "uvr_models": uvr_models,
    }
    try:
        payload.update(catalog())
    except Exception as exc:
        payload["gt_dicts"] = []
        payload["dict_error"] = str(exc)
    return payload


def main() -> None:
    parser = argparse.ArgumentParser(description="Kikoeta Transl engine")
    parser.add_argument("--host", default=HOST)
    parser.add_argument("--port", type=int, default=PORT)
    args = parser.parse_args()
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    settings = load_settings()
    public_host = "0.0.0.0" if settings.remote_access else "127.0.0.1"
    try:
        public_server = ThreadingHTTPServer((public_host, PUBLIC_PORT), Handler)
        threading.Thread(target=public_server.serve_forever, daemon=True).start()
        print(f"kt service listening on http://{public_host}:{PUBLIC_PORT}", flush=True)
    except OSError as exc:
        print(f"kt service unavailable on {public_host}:{PUBLIC_PORT}: {exc}", file=sys.stderr, flush=True)
    print(f"kt engine listening on http://{args.host}:{args.port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


def _materialize_remote_files(items: object) -> list[str]:
    if not isinstance(items, list):
        raise ValueError("files must be a list")
    upload_dir = WORK_DIR / "remote" / uuid.uuid4().hex
    paths: list[str] = []
    for index, item in enumerate(items):
        if isinstance(item, str) and item.strip():
            paths.append(item)
            continue
        if not isinstance(item, dict):
            raise ValueError(f"invalid file at index {index}")
        name = Path(str(item.get("name") or f"input_{index}")).name
        encoded = str(item.get("content_base64") or "")
        if not encoded:
            raise ValueError(f"file {name} has no content_base64")
        content = base64.b64decode(encoded, validate=True)
        upload_dir.mkdir(parents=True, exist_ok=True)
        target = upload_dir / name
        target.write_bytes(content)
        paths.append(str(target))
    if not paths:
        raise ValueError("没有输入文件")
    return paths


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
