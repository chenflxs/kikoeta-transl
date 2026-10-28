"""Optional Windows release smoke: KT HTTP -> outbox -> sidecar -> kikoeru.

Runs only a copied executable and generated media/data in a dedicated temporary
directory. ASR/correction/translation stages are deterministic and make no model
requests. Set KIKOERU_WINDOWS_EXE and KIKOERU_SIDECAR_DIR for other locations.
"""
from __future__ import annotations

import base64
import json
import os
import shutil
import socket
import sqlite3
import subprocess
import sys
import tempfile
import threading
import time
import wave
from contextlib import ExitStack, closing
from pathlib import Path
from unittest.mock import patch
from urllib.request import Request, urlopen

ENGINE = Path(__file__).resolve().parents[1]
WORKSPACE = ENGINE.parent.parent / "kikoeru-ch"
SIDECAR = Path(os.environ.get("KIKOERU_SIDECAR_DIR", WORKSPACE / "sidecar"))
EXE = Path(os.environ.get("KIKOERU_WINDOWS_EXE", WORKSPACE / "kikoeru-win-x64-v0.6.19-20261025" / "kikoeru-express.exe"))
sys.path.insert(0, str(ENGINE))
sys.path.insert(0, str(SIDECAR))

from kikoeru_sidecar.server import SidecarApp, run_server
from kt.jobs import JobManager
from kt.kikoeru_sync import Outbox
from kt.models import AppSettings, FileResult
import server as kt_server


def json_request(base, path, payload=None, *, headers=None, timeout=10):
    body = json.dumps(payload).encode("utf-8") if payload is not None else None
    request_headers = {"Content-Type": "application/json", **(headers or {})}
    req = Request(base + path, data=body, headers=request_headers, method="POST" if payload is not None else "GET")
    with urlopen(req, timeout=timeout) as response:
        return json.load(response)


def start_http(http):
    thread = threading.Thread(target=http.serve_forever, daemon=True)
    thread.start()
    return thread


def stop_http(http, thread):
    if http is not None:
        http.shutdown()
        http.server_close()
        thread.join(timeout=3)


def main():
    if os.name != "nt" or not EXE.is_file() or not SIDECAR.is_dir():
        raise SystemExit("This optional smoke requires Windows, the kikoeru release EXE and sidecar sources")
    parent = WORKSPACE.resolve()
    temporary = Path(tempfile.mkdtemp(prefix="kt-kikoeru-smoke-", dir=parent)).resolve()
    if temporary.parent != parent or not temporary.name.startswith("kt-kikoeru-smoke-"):
        raise RuntimeError("Unexpected smoke directory")
    process = app = outbox = manager = None
    side_http = side_thread = local_http = local_thread = None
    passed = False
    stack = ExitStack()
    try:
        executable = temporary / "kikoeru-express.exe"
        shutil.copy2(EXE, executable)
        data = temporary / "data"
        library = temporary / "library"
        work = library / "RJ123456 fixture"
        audio = work / "01" / "track.wav"
        audio.parent.mkdir(parents=True)
        with wave.open(str(audio), "wb") as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(8000)
            output.writeframes(b"\0\0" * 8000)
        config = data / "config" / "config.json"
        config.parent.mkdir(parents=True)
        config.write_text(json.dumps({
            "checkUpdate": False, "enableFileWatcher": False, "auth": False,
            "production": False, "blockRemoteConnection": True,
            "rootFolders": [{"name": "fixture", "type": "local", "path": str(library)}],
        }), encoding="utf-8")
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            source_port = sock.getsockname()[1]
        env = os.environ.copy()
        env.update(KIKOERU_DATA_DIR=str(data), NODE_ENV="development", PORT=str(source_port))
        log = stack.enter_context((temporary / "kikoeru.log").open("wb"))
        process = subprocess.Popen([str(executable)], cwd=temporary, env=env,
                                   stdout=log, stderr=subprocess.STDOUT,
                                   creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        source_base = f"http://127.0.0.1:{source_port}"
        deadline = time.monotonic() + 45
        while time.monotonic() < deadline:
            if process.poll() is not None:
                raise RuntimeError(f"kikoeru exited: {process.returncode}")
            try:
                with urlopen(source_base + "/api/health", timeout=1) as response:
                    if response.status == 200:
                        break
            except OSError:
                time.sleep(.2)
        else:
            raise RuntimeError("kikoeru did not become ready")
        with closing(sqlite3.connect(data / "sqlite" / "db.sqlite3")) as db:
            with db:
                db.execute("INSERT INTO t_circle(id,name) VALUES(1,'fixture')")
                db.execute("INSERT INTO t_work(id,root_folder,dir,title,circle_id,lyric_status,memo) VALUES(123456,'fixture','RJ123456 fixture','fixture',1,'0','{}')")
        tree = json_request(source_base, "/api/tracks/123456")
        audio_node = tree[0]["children"][0]
        app = SidecarApp({"api_token": "sidecar-smoke-token", "sources": {"fixture": {
            "base_url": source_base, "token": "",
            "roots": [{"server": str(library), "local": str(library)}],
        }}}, temporary / "sidecar.sqlite")
        side_http = run_server(app, port=0)
        side_thread = start_http(side_http)
        settings = AppSettings()
        settings.output.kikoeru_sync = True
        settings.output.kikoeru_url = f"http://127.0.0.1:{side_http.server_port}"
        settings.output.kikoeru_token = "sidecar-smoke-token"
        settings.output.kikoeru_source_id = "fixture"
        settings.output.kikoeru_media_url_prefix = source_base + "/api/media"
        for target in ("kt.jobs.WORK_DIR", "server.WORK_DIR"):
            stack.enter_context(patch(target, temporary / "kt-work"))
        for target in ("kt.jobs.load_settings", "server.load_settings"):
            stack.enter_context(patch(target, return_value=settings))
        for name in ("cache_completed_job", "sync_completed_job", "record_finished_job"):
            stack.enter_context(patch("kt.jobs." + name, return_value=0))

        def deterministic_pipeline(**kwargs):
            if not Path(kwargs["path"]).read_bytes().startswith(b"RIFF"):
                raise RuntimeError("KT did not download the real fixture audio")
            lyric = kwargs["job_dir"] / "result.lrc"
            lyric.write_text("[00:01.123] KT integration fixture\n", encoding="utf-8")
            return FileResult(kwargs["path"], "media", status="done", outputs=[str(lyric)])

        stack.enter_context(patch("kt.jobs.process_file", side_effect=deterministic_pipeline))
        outbox = Outbox(temporary / "kt-outbox.sqlite", lambda: settings)
        manager = JobManager(kikoeru_outbox=outbox)
        stack.enter_context(patch("server.MANAGER", manager))
        stack.enter_context(patch("server.KIKOERU_OUTBOX", outbox))

        class QuietHandler(kt_server.Handler):
            def log_message(self, *_):
                pass

        local_http = kt_server._EngineHTTPServer(("127.0.0.1", 0), QuietHandler)
        local_thread = start_http(local_http)
        kt_base = f"http://127.0.0.1:{local_http.server_port}"
        headers = {"Authorization": "Basic " + base64.b64encode(b"admin:kikoeta").decode()}
        submitted = json_request(kt_base, "/api/v1/jobs", {
            "resume_existing": False,
            "files": [{"url": source_base + audio_node["mediaDownloadUrl"], "name": "track.wav"}],
            "cache": {"work_id": "RJ123456", "track_paths": ["01/track.wav"]},
        }, headers=headers)
        job_id = submitted["job_id"]
        job = manager.get(job_id)
        if job.cache_context.get("kikoeru_source_id") != "fixture":
            raise RuntimeError("KT HTTP ingress did not bind the configured source")
        deadline = time.monotonic() + 30
        entries = []
        while time.monotonic() < deadline:
            outbox.process_once()
            entries = json_request(kt_base, "/api/kikoeru/deliveries")["entries"]
            if entries and entries[0]["status"] in {"completed", "conflict", "failed", "blocked"}:
                break
            time.sleep(.05)
        lyric = work / "01" / "track.lrc"
        if (not entries or entries[0]["status"] != "completed"
                or entries[0]["result"].get("match") != "selected"
                or lyric.read_text(encoding="utf-8") != "[00:01.12] KT integration fixture\n"):
            raise RuntimeError(f"Delivery not selected by the real server: {entries}")
        print(json.dumps({"job_id": job_id, "delivery": entries[0], "lyric": lyric.read_text(encoding="utf-8")}, ensure_ascii=False))
        print("KT_KIKOERU_WINDOWS_SMOKE_PASS")
        passed = True
    finally:
        if manager is not None:
            manager.shutdown()
        if outbox is not None:
            outbox.close()
        stop_http(local_http, local_thread)
        stop_http(side_http, side_thread)
        if app is not None:
            app.close()
        stack.close()
        if process is not None:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=10)
        if passed and temporary.resolve().parent == parent and temporary.name.startswith("kt-kikoeru-smoke-"):
            shutil.rmtree(temporary)
        else:
            print("fixture_dir=", temporary)


if __name__ == "__main__":
    main()
