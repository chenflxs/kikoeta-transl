from __future__ import annotations

import hashlib
import json
import sys
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from kt.kikoeru_sync import Outbox


def binding(output):
    raw = [output.kikoeru_url, output.kikoeru_source_id, output.kikoeru_media_url_prefix]
    return hashlib.sha256(json.dumps(raw).encode()).hexdigest()


class _Sidecar(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _reply(self, status, value):
        body = json.dumps(value).encode()
        self.send_response(status)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(body)

    def _record(self):
        fixture = self.server.fixture
        fixture.authorizations.append(self.headers.get("Authorization"))
        if fixture.response_code:
            self._reply(fixture.response_code, {"error": "not echoed by KT"})
            return None
        return fixture

    def do_POST(self):
        fixture = self._record()
        if fixture is None:
            return
        payload = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        if self.path.endswith("/retry"):
            fixture.retries += 1
            fixture.remote_status = "pending"
        else:
            fixture.posts.append(payload)
            fixture.payload = payload
            if fixture.drop_response:
                self.send_response(202)
                self.send_header("Content-Length", "100")
                self.end_headers()
                self.wfile.write(b"{")
                self.close_connection = True
                return
        self._reply(202, {"delivery_id": fixture.payload["delivery_id"], "status": fixture.remote_status,
                          "result": None, "error": None})

    def do_GET(self):
        fixture = self._record()
        if fixture is None:
            return
        self._reply(200, {"delivery_id": fixture.payload["delivery_id"], "status": fixture.remote_status,
                          "result": {"file_status": "written", "match": "selected"}, "error": None})


class KikoeruOutboxChecks(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), _Sidecar)
        self.server.fixture = self
        self.server.daemon_threads = True
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self._close_server)
        self.output = SimpleNamespace(kikoeru_sync=True,
            kikoeru_url=f"http://127.0.0.1:{self.server.server_port}",
            kikoeru_token="super-secret-token", kikoeru_source_id="my-library",
            kikoeru_media_url_prefix="http://media.example/api/media/download")
        self.settings = SimpleNamespace(output=self.output)
        self.binding_patch = patch("kt.kikoeru_sync._binding", binding)
        self.binding_patch.start()
        self.addCleanup(self.binding_patch.stop)
        self.path = self.root / "outbox.sqlite"
        self.outbox = Outbox(self.path, settings_loader=lambda: self.settings)
        self.addCleanup(self.outbox.close)
        self.posts = []
        self.authorizations = []
        self.remote_status = "pending"
        self.response_code = 0
        self.payload = None
        self.retries = 0
        self.drop_response = False
        self.now = 1000

    def _close_server(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)

    def job(self):
        lrc = self.root / "result.lrc"
        lrc.write_bytes(b"[00:01.123] hello\n")
        return SimpleNamespace(job_id="aabbccddeeff", source="kikoeta", lls_output=self.output,
            cache_context={"work_id": "RJ123456", "track_paths": ["folder/audio.wav"],
                           "kikoeru_source_id": self.output.kikoeru_source_id,
                           "kikoeru_binding": binding(self.output), "kikoeru_indices": [0]},
            results=[SimpleNamespace(status="done", outputs=[str(lrc)])])

    def step(self):
        self.now += 1000
        with patch("kt.kikoeru_sync.time.time", return_value=self.now):
            return self.outbox.process_once()

    def record(self):
        return self.outbox.list_entries()[0]

    def test_durable_copy_survives_output_cleanup_and_restart(self):
        job = self.job()
        self.assertTrue(self.outbox.enqueue_file(job, 0))
        Path(job.results[0].outputs[0]).unlink()
        self.outbox.close()
        self.outbox = Outbox(self.path, settings_loader=lambda: self.settings)
        self.addCleanup(self.outbox.close)
        self.assertTrue(self.step())
        self.assertEqual(self.posts[0]["lrc"], "[00:01.123] hello\n")
        self.assertEqual(self.record()["status"], "waiting")
        self.remote_status = "completed"
        self.step()
        self.assertEqual(self.record()["status"], "completed")
        self.assertEqual(self.record()["result"]["match"], "selected")
        self.assertNotIn(b"super-secret-token", self.path.read_bytes())
        self.assertNotIn("lrc", self.record())

    def test_duplicate_uses_stable_identity_and_changed_content_is_rejected(self):
        job = self.job()
        self.assertTrue(self.outbox.enqueue_file(job, 0))
        first = self.record()["delivery_id"]
        self.assertFalse(self.outbox.enqueue_file(job, 0))
        self.assertEqual(self.record()["delivery_id"], first)
        Path(job.results[0].outputs[0]).write_text("[00:01.000] different\n", encoding="utf-8")
        with self.assertRaises(ValueError):
            self.outbox.enqueue_file(job, 0)
        self.assertEqual(len(self.outbox.list_entries()), 1)

    def test_unbound_and_unfinished_tracks_are_not_delivered(self):
        job = self.job()
        job.cache_context["kikoeru_indices"] = []
        self.assertFalse(self.outbox.enqueue_file(job, 0))
        job.cache_context["kikoeru_indices"] = [0]
        job.results[0].status = "failed"
        self.assertFalse(self.outbox.enqueue_file(job, 0))
        self.assertEqual(self.outbox.list_entries(), [])

    def test_disabled_and_changed_source_never_sends_to_new_destination(self):
        self.outbox.enqueue_file(self.job(), 0)
        self.output.kikoeru_sync = False
        self.step()
        self.assertEqual(self.record()["status"], "paused")
        self.assertEqual(self.posts, [])
        self.output.kikoeru_sync = True
        original = self.output.kikoeru_source_id
        self.output.kikoeru_source_id = "another-library"
        self.step()
        self.assertEqual(self.record()["status"], "blocked")
        self.assertEqual(self.posts, [])
        self.output.kikoeru_source_id = original
        self.step()
        self.assertEqual(len(self.posts), 1)

    def test_network_retry_and_credential_rotation(self):
        self.outbox.enqueue_file(self.job(), 0)
        self.response_code = 503
        self.step()
        self.assertEqual(self.record()["status"], "retry")
        self.response_code = 0
        self.output.kikoeru_token = "rotated-token"
        self.step()
        self.assertEqual(self.authorizations[-1], "Bearer rotated-token")
        self.assertEqual(self.record()["status"], "waiting")

    def test_lost_acceptance_response_reposts_the_same_identity(self):
        self.outbox.enqueue_file(self.job(), 0)
        self.drop_response = True
        self.step()
        self.assertEqual(self.record()["status"], "retry")
        first = dict(self.posts[0])
        self.drop_response = False
        self.step()
        self.assertEqual(self.posts[1], first)
        self.assertEqual(self.record()["status"], "waiting")

    def test_remote_conflict_is_visible_and_manual_retry_uses_remote_retry(self):
        self.outbox.enqueue_file(self.job(), 0)
        self.remote_status = "conflict"
        self.step()
        self.assertEqual(self.record()["status"], "conflict")
        delivery_id = self.record()["delivery_id"]
        self.outbox.retry(delivery_id)
        self.step()
        self.assertEqual(self.retries, 1)
        self.assertEqual(self.record()["status"], "waiting")

    def test_unauthorized_response_is_permanent_and_does_not_expose_response(self):
        self.outbox.enqueue_file(self.job(), 0)
        self.response_code = 401
        self.step()
        self.assertEqual(self.record()["status"], "failed")
        self.assertIn("401", self.record()["error"])
        self.assertNotIn("not echoed", self.record()["error"])


if __name__ == "__main__":
    unittest.main()
