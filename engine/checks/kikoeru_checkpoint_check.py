"""Regression checks for the workflow-to-outbox persistence boundary."""
from __future__ import annotations

import json
import sys
import tempfile
import threading
import time
import unittest
from contextlib import ExitStack
from pathlib import Path
from threading import Event
from unittest.mock import Mock, patch
from urllib.error import HTTPError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from kt.job_checkpoint import NAME
from kt.jobs import Job, JobManager
from kt.kikoeru_sync import Outbox
from kt.models import AppSettings, FileResult, JobRequest, StageFlags
from kt.remote_source import bind_context
from server import Handler, _EngineHTTPServer


class KikoeruCheckpointChecks(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.work = self.root / "work"
        self.settings = AppSettings()
        output = self.settings.output
        output.kikoeru_sync = True
        output.kikoeru_url = "http://127.0.0.1:2379"
        output.kikoeru_token = "fixture-token-123"
        output.kikoeru_source_id = "fixture"
        output.kikoeru_media_url_prefix = "http://media.example/api/media/download"
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        self.stack.enter_context(patch("kt.jobs.WORK_DIR", self.work))
        self.stack.enter_context(patch("kt.jobs.load_settings", return_value=self.settings))
        for name in ("cache_completed_job", "sync_completed_job", "record_finished_job"):
            self.stack.enter_context(patch("kt.jobs." + name, return_value=0))

    def request(self):
        audio = self.root / "audio.wav"
        audio.write_bytes(b"audio")
        payload = {"files": [{"url": "http://media.example/api/media/download/123456/0"}],
                   "cache": {"work_id": "RJ123456", "track_paths": ["audio.wav"]}}
        return JobRequest(files=[str(audio)], cache_context=bind_context(payload, self.settings.output))

    @staticmethod
    def finish_file(**kwargs):
        lrc = kwargs["job_dir"] / "result.lrc"
        lrc.write_bytes(b"[00:01.123] fixture\n")
        return FileResult(kwargs["path"], "media", status="done", stage="done", outputs=[str(lrc)])

    def wait(self, predicate, message):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if predicate():
                return
            time.sleep(.01)
        self.fail(message)

    def test_terminal_checkpoint_survives_failed_copy_and_recovers_after_restart(self):
        broken = Mock()
        broken.enqueue_file.side_effect = OSError("fixture disk unavailable")
        manager = JobManager(kikoeru_outbox=broken)
        self.addCleanup(manager.shutdown)
        with patch("kt.jobs.process_file", side_effect=self.finish_file):
            job = manager.create(self.request(), source="kikoeta")
            self.wait(lambda: job.status == "completed" and manager._active is None,
                      "workflow must finish independently of outbox storage")
        checkpoint = self.work / job.job_id / NAME
        self.assertTrue(checkpoint.is_file())
        raw = json.loads(checkpoint.read_text(encoding="utf-8"))
        self.assertEqual(raw["status"], "completed")
        self.assertEqual(raw["kikoeru_pending"], [0])
        self.assertTrue(Path(raw["results"][0]["outputs"][0]).is_file())
        manager.shutdown()

        outbox = Outbox(self.root / "outbox.sqlite", lambda: self.settings)
        self.addCleanup(outbox.close)
        recovered = JobManager(kikoeru_outbox=outbox)
        self.addCleanup(recovered.shutdown)
        restored = recovered.get(job.job_id)
        self.assertIsNotNone(restored)
        self.assertEqual(restored.status, "completed")
        self.wait(lambda: restored.kikoeru_pending == [] and not checkpoint.exists(),
                  "recovery must copy the LRC then clear the terminal checkpoint")
        entries = outbox.list_entries()
        self.assertEqual(len(entries), 1)
        self.assertEqual(entries[0]["job_id"], job.job_id)
        self.assertEqual(entries[0]["status"], "queued")

    def test_blocked_outbox_storage_does_not_block_get_or_preempt(self):
        entered, release, controls_done = Event(), Event(), Event()
        outbox = Mock()

        def blocked_copy(*_):
            entered.set()
            release.wait(3)
            return True

        outbox.enqueue_file.side_effect = blocked_copy
        manager = JobManager()
        manager._kikoeru_outbox = outbox
        self.addCleanup(manager.shutdown)
        request = self.request()
        job = Job("aabbccddeeff", request.files, StageFlags(), self.settings,
                  source="kikoeta", cache_context=request.cache_context, lls_output=self.settings.output,
                  status="running", kikoeru_pending=[0],
                  results=[FileResult(request.files[0], "media", status="done", outputs=[])])
        manager._jobs[job.job_id] = job
        manager._active = job
        delivery = threading.Thread(target=manager._drain_deliveries, args=(job,), daemon=True)
        delivery.start()
        self.assertTrue(entered.wait(1))
        failures = []

        def controls():
            try:
                self.assertIs(manager.get(job.job_id), job)
                manager.preempt(job.job_id)
            except Exception as exc:
                failures.append(exc)
            finally:
                controls_done.set()

        control = threading.Thread(target=controls, daemon=True)
        control.start()
        try:
            self.assertTrue(controls_done.wait(.75), "slow delivery storage must not hold manager lock")
            self.assertEqual(failures, [])
            self.assertEqual(job.status, "pausing")
        finally:
            release.set()
            control.join(timeout=2)
            delivery.join(timeout=2)


class KikoeruPendingRecentApiChecks(unittest.TestCase):
    def test_recent_deletion_cannot_remove_unpersisted_delivery_checkpoint(self):
        settings = AppSettings()
        job = Job("aabbccddeeff", ["audio.wav"], StageFlags(), settings,
                  status="completed", kikoeru_pending=[0])
        manager = Mock()
        manager.get.return_value = job
        manager.list.return_value = [job]
        with ExitStack() as stack:
            stack.enter_context(patch("server.MANAGER", manager))
            stack.enter_context(patch("server.load_settings", return_value=settings))
            delete_one = stack.enter_context(patch("server.delete_recent_job"))
            delete_cache = stack.enter_context(patch("server.delete_translation_cache"))
            delete_all = stack.enter_context(patch("server.delete_all_recent_jobs", return_value=0))
            server = _EngineHTTPServer(("127.0.0.1", 0), Handler)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                base = f"http://127.0.0.1:{server.server_port}"
                for suffix in (job.job_id, job.job_id + "/cache"):
                    with self.assertRaises(HTTPError) as raised:
                        urlopen(Request(base + "/api/recent/" + suffix, method="DELETE"), timeout=2)
                    self.assertEqual(raised.exception.code, 409)
                    raised.exception.close()
                delete_one.assert_not_called()
                delete_cache.assert_not_called()
                with urlopen(Request(base + "/api/recent", method="DELETE"), timeout=2) as response:
                    self.assertEqual(response.status, 200)
                delete_all.assert_called_once_with({job.job_id})
            finally:
                server.shutdown()
                server.server_close()
                thread.join(timeout=2)


if __name__ == "__main__":
    unittest.main()
