"""KT workflow -> durable outbox -> real sidecar HTTP integration checks.

The sibling sidecar is optional for a standalone KT checkout. The model stages
and the upstream kikoeru API are deterministic local fixtures; file delivery,
HTTP authentication, indexing requests and workflow checkpoints are real.
"""
from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
import threading
import time
import unittest
from contextlib import ExitStack
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Event
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
SIDECAR = Path(os.environ.get("KIKOERU_SIDECAR_DIR", ROOT.parent.parent / "kikoeru-ch" / "sidecar"))
from node_sidecar import NodeSidecar

from kt.jobs import JobManager
from kt.kikoeru_sync import Outbox
from kt.models import AppSettings, FileResult, JobRequest
from kt.remote_source import bind_context


class _KikoeruHandler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_GET(self):
        fixture = self.server.fixture
        if self.headers.get("Authorization") != "Bearer source-token":
            return self.respond(401, {"error": "unauthorized"})
        info = {
            "rootFolder": {"name": "fixture", "path": str(fixture.library), "type": "local", "writable": True},
            "dir": "RJ123456", "fullPath": str(fixture.work), "writable": True,
        }
        if self.path == "/api/work/123456/fileinfo":
            return self.respond(200, info)
        if self.path == "/api/work/123456/trackinfo":
            return self.respond(200, {
                "work": {"id": 123456, "dir": "RJ123456"},
                "mediaLibrary": {"type": "local", "writable": True, "absolutePath": str(fixture.library)},
                "paths": {"dir": "RJ123456", "fullPath": str(fixture.work)},
                "trackTableReady": True,
                "tracks": [{"seq": index, "relPath": f"01/track-{index}.wav", "fileType": "audio", "ext": ".wav"}
                           for index in range(3)],
            })
        if self.path == "/api/tracks/123456":
            fixture.refresh_count += 1
            return self.respond(200, [])
        for route in ("query-lrc", "check-lrc"):
            prefix = f"/api/media/{route}/123456/"
            if self.path.startswith(prefix):
                index = int(self.path[len(prefix):])
                target = fixture.work / "01" / f"track-{index}.lrc"
                if route == "query-lrc":
                    candidates = [{"title": target.name, "subtitle": "01", "hash": str(index + 100),
                                   "ext": ".lrc", "isAI": False, "matchLevel": 0}] if target.is_file() else []
                    return self.respond(200, {"result": True, "lyricList": candidates})
                return self.respond(200, {"result": target.is_file(), "hash": str(index + 100),
                                          "lrc": [{"time": 1120, "text": "fixture"}] if target.is_file() else []})
        self.respond(404, {"error": "not found"})

    def respond(self, code, value):
        body = json.dumps(value).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


@unittest.skipUnless((SIDECAR / 'src' / 'cli.js').is_file() and shutil.which('node'), "Node sidecar source and runtime required")
class KikoeruDeliveryChecks(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.library = self.root / "library"
        self.work = self.library / "RJ123456"
        (self.work / "01").mkdir(parents=True)
        for index in range(3):
            (self.work / "01" / f"track-{index}.wav").write_bytes(b"fixture audio")
        self.refresh_count = 0
        self.upstream = ThreadingHTTPServer(("127.0.0.1", 0), _KikoeruHandler)
        self.upstream.fixture = self
        self.upstream_thread = threading.Thread(target=self.upstream.serve_forever, daemon=True)
        self.upstream_thread.start()
        upstream_url = f"http://127.0.0.1:{self.upstream.server_port}"
        self.sidecar = NodeSidecar(SIDECAR, {"api_token": "sidecar-token-12345", "sources": {"fixture": {
            "base_url": upstream_url, "token": "source-token",
            "roots": [{"server": str(self.library), "local": str(self.library)}],
        }}}, self.root / "sidecar.sqlite")
        self.side_server = None
        self.side_thread = None
        self.start_sidecar()
        self.settings = AppSettings()
        output = self.settings.output
        output.kikoeru_sync = True
        output.kikoeru_url = f"http://127.0.0.1:{self.side_port}"
        output.kikoeru_token = "sidecar-token-12345"
        output.kikoeru_source_id = "fixture"
        output.kikoeru_media_url_prefix = upstream_url + "/media"
        self.stack = ExitStack()
        self.stack.enter_context(patch("kt.jobs.WORK_DIR", self.root / "work"))
        self.stack.enter_context(patch("kt.jobs.load_settings", return_value=self.settings))
        for name in ("cache_completed_job", "sync_completed_job", "record_finished_job"):
            self.stack.enter_context(patch("kt.jobs." + name, return_value=0))
        self.outbox = Outbox(self.root / "outbox.sqlite", lambda: self.settings)
        self.manager = JobManager(kikoeru_outbox=self.outbox)

    def tearDown(self):
        self.manager.shutdown()
        self.outbox.close()
        self.stack.close()
        self.stop_sidecar()
        self.sidecar.close()
        self.upstream.shutdown()
        self.upstream.server_close()
        self.upstream_thread.join(timeout=3)
        self.temporary.cleanup()

    def start_sidecar(self):
        self.side_server = self.sidecar.start(port=getattr(self, "side_port", 0))
        self.side_port = self.side_server.server_port

    def stop_sidecar(self):
        if self.side_server is not None:
            self.sidecar.close()
            self.side_server = None

    def request(self, count=3):
        upload = self.root / "uploads"
        upload.mkdir(exist_ok=True)
        files = []
        for index in range(count):
            path = upload / f"{index}.wav"
            path.write_bytes(b"downloaded audio")
            files.append(str(path))
        payload = {"files": [{"url": self.settings.output.kikoeru_media_url_prefix + f"/{index}"}
                              for index in range(count)],
                   "cache": {"work_id": "RJ123456", "track_paths": [f"01/track-{index}.wav" for index in range(count)]}}
        return JobRequest(files=files, cleanup_paths=[str(upload)],
                          cache_context=bind_context(payload, self.settings.output))

    def finish_file(self, **kwargs):
        index = int(kwargs["job_dir"].name[:4])
        output = kwargs["job_dir"] / "result.lrc"
        output.write_text(f"[00:01.123] fixture-{index}\n", encoding="utf-8")
        return FileResult(kwargs["path"], "media", status="done", stage="done", outputs=[str(output)])

    def wait_job(self, job, expected):
        deadline = time.monotonic() + 6
        while time.monotonic() < deadline:
            with self.manager._lock:
                if job.status == expected and self.manager._active is None:
                    return
            time.sleep(.01)
        self.fail(f"workflow expected {expected}, got {job.status}")

    def deliver_all(self, count):
        deadline = time.monotonic() + 12
        entries = []
        while time.monotonic() < deadline:
            self.outbox.process_once()
            entries = self.outbox.list_entries()
            if len(entries) == count and all(item["status"] == "completed" for item in entries):
                return entries
            time.sleep(.02)
        self.fail(f"deliveries did not complete: {entries}")

    def test_successful_tracks_are_delivered_when_another_track_fails(self):
        def process(**kwargs):
            if int(kwargs["job_dir"].name[:4]) == 1:
                return FileResult(kwargs["path"], "media", status="failed", stage="failed", error="fixture failure")
            return self.finish_file(**kwargs)

        with patch("kt.jobs.process_file", side_effect=process):
            job = self.manager.create(self.request(), source="kikoeta")
            self.wait_job(job, "failed")
        entries = self.deliver_all(2)
        self.assertEqual({entry["file_index"] for entry in entries}, {0, 2})
        self.assertFalse((self.root / "uploads").exists(), "delivery must survive input cleanup")
        for index in (0, 2):
            self.assertEqual((self.work / "01" / f"track-{index}.lrc").read_text(encoding="utf-8"),
                             f"[00:01.12] fixture-{index}\n")
        self.assertFalse((self.work / "01" / "track-1.lrc").exists())
        self.assertTrue(all(item["result"]["match"] == "selected" for item in entries))

    def test_pause_restart_resume_keeps_delivery_identity(self):
        second_started = Event()

        def pause_second(**kwargs):
            if int(kwargs["job_dir"].name[:4]) == 1:
                second_started.set()
                self.assertTrue(kwargs["stop_event"].wait(4))
                return FileResult(kwargs["path"], "media", status="cancelled")
            return self.finish_file(**kwargs)

        with patch("kt.jobs.process_file", side_effect=pause_second):
            job = self.manager.create(self.request(2), source="kikoeta")
            self.assertTrue(second_started.wait(4))
            self.manager.preempt(job.job_id)
            self.wait_job(job, "paused")
        first = self.deliver_all(1)[0]
        self.manager.shutdown()
        self.manager = JobManager(kikoeru_outbox=self.outbox)
        restored = self.manager.get(job.job_id)
        self.assertIsNotNone(restored)
        self.assertEqual(restored.status, "paused")
        with patch("kt.jobs.process_file", side_effect=self.finish_file) as process:
            self.manager.resume(job.job_id)
            self.wait_job(restored, "completed")
            self.assertEqual(process.call_count, 1)
        entries = self.deliver_all(2)
        self.assertIn(first["delivery_id"], {item["delivery_id"] for item in entries})
        self.assertEqual(len({item["delivery_id"] for item in entries}), 2)

    def test_offline_sidecar_and_outbox_restart_do_not_lose_lyric(self):
        self.stop_sidecar()
        with patch("kt.jobs.process_file", side_effect=self.finish_file):
            job = self.manager.create(self.request(1), source="kikoeta")
            self.wait_job(job, "completed")
        self.assertTrue(self.outbox.process_once())
        record = self.outbox.list_entries()[0]
        self.assertEqual(record["status"], "retry")
        self.assertFalse((self.work / "01" / "track-0.lrc").exists())
        self.manager.shutdown()
        self.outbox.close()
        self.outbox = Outbox(self.root / "outbox.sqlite", lambda: self.settings)
        self.manager = JobManager(kikoeru_outbox=self.outbox)
        self.start_sidecar()
        self.outbox.retry(record["delivery_id"])
        entries = self.deliver_all(1)
        self.assertEqual(entries[0]["delivery_id"], record["delivery_id"])
        self.assertEqual((self.work / "01" / "track-0.lrc").read_text(encoding="utf-8"), "[00:01.12] fixture-0\n")
        self.assertGreaterEqual(self.refresh_count, 1)


if __name__ == "__main__":
    unittest.main()
