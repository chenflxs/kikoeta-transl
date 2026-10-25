from __future__ import annotations

import base64
import http.client
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

from kt.jobs import Job, JobManager
from kt.models import AppSettings, FileResult, JobRequest, StageFlags
from server import Handler, _EngineHTTPServer


class JobResumeChecks(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        for name, value in (
            ("kt.jobs.WORK_DIR", self.root / "work"),
            ("kt.jobs.load_settings", AppSettings()),
            ("kt.jobs.cache_completed_job", 0),
            ("kt.jobs.sync_completed_job", 0),
            ("kt.jobs.record_finished_job", None),
        ):
            context = patch(name, return_value=value) if not name.endswith("WORK_DIR") else patch(name, value)
            context.start()
            self.addCleanup(context.stop)
        self.manager = JobManager()
        self.addCleanup(self.manager.shutdown)

    def request(self, label="original", work="RJ123456", count=5):
        upload = self.root / label
        upload.mkdir()
        files = []
        for index in range(count):
            path = upload / f"{index}.mp3"
            path.write_bytes(b"audio")
            files.append(str(path))
        return JobRequest(files=files, cleanup_paths=[str(upload)],
                          cache_context={"work_id": work, "track_paths": [f"{index}.mp3" for index in range(count)]})

    def wait_status(self, job, status):
        deadline = time.monotonic() + 4
        while time.monotonic() < deadline:
            with self.manager._lock:
                if job.status == status and self.manager._active is None:
                    return
            time.sleep(0.005)
        self.fail(f"Expected {status}, got {job.status}")

    @staticmethod
    def finish_file(**kwargs):
        output = kwargs["job_dir"] / "result.lrc"
        output.write_text("[00:00] done", encoding="utf-8")
        return FileResult(path=kwargs["path"], kind="media", status="done", stage="done", outputs=[str(output)])

    def pause_after_two(self, request):
        third_started = Event()
        calls = []

        def process(**kwargs):
            calls.append(Path(kwargs["path"]).name)
            if len(calls) == 3:
                third_started.set()
                self.assertTrue(kwargs["stop_event"].wait(3), "Preempt must interrupt the in-progress file")
                return FileResult(path=kwargs["path"], kind="media", status="cancelled", stage="cancelled")
            return self.finish_file(**kwargs)

        with patch("kt.jobs.process_file", side_effect=process):
            job = self.manager.create(request, source="kikoeta")
            self.assertTrue(third_started.wait(3))
            started = time.monotonic()
            self.manager.preempt(job.job_id)
            self.assertLess(time.monotonic() - started, 1)
            self.wait_status(job, "paused")
        return job, calls

    def test_resume_by_id_reuses_inputs_and_only_processes_remaining_files(self):
        job, _ = self.pause_after_two(self.request())
        files = list(job.files)
        with patch("kt.jobs.process_file", side_effect=self.finish_file) as process:
            resumed = self.manager.resume(job.job_id)
            self.assertIs(resumed, job)
            self.wait_status(resumed, "completed")
        self.assertEqual(job.files, files)
        self.assertEqual(process.call_count, 3)
        self.assertEqual(len(self.manager.list()), 1)

    def test_fresh_same_work_import_does_not_consume_paused_batch(self):
        job, _ = self.pause_after_two(self.request())
        with patch("kt.jobs.process_file", side_effect=self.finish_file) as process:
            second = self.manager.create(self.request("second"), source="kikoeta", resume_existing=False)
            self.wait_status(second, "completed")
        self.assertNotEqual(second.job_id, job.job_id)
        self.assertEqual(job.status, "paused")
        self.assertEqual(process.call_count, 5)

    def test_resume_while_busy_or_after_completion_is_rejected(self):
        job, _ = self.pause_after_two(self.request())
        started = Event()

        def wait_for_cancel(**kwargs):
            started.set()
            self.assertTrue(kwargs["stop_event"].wait(3))
            return FileResult(kwargs["path"], "media", status="cancelled")

        with patch("kt.jobs.process_file", side_effect=wait_for_cancel):
            other = self.manager.create(self.request("other", "RJ999999", 1), source="kikoeta")
            self.assertTrue(started.wait(3))
            with self.assertRaisesRegex(RuntimeError, "已有工作流"):
                self.manager.resume(job.job_id)
            self.manager.cancel(other.job_id)
            self.wait_status(other, "cancelled")
        with patch("kt.jobs.process_file", side_effect=self.finish_file):
            self.manager.resume(job.job_id)
            self.wait_status(job, "completed")
        with self.assertRaisesRegex(RuntimeError, "只有已暂存"):
            self.manager.resume(job.job_id)

    def test_resume_missing_pending_input_is_explicit_error_and_keeps_checkpoint(self):
        job, _ = self.pause_after_two(self.request())
        Path(job.results[2].path).unlink()
        with self.assertRaisesRegex(ValueError, "输入文件已丢失"):
            self.manager.resume(job.job_id)
        self.assertEqual(job.status, "paused")
        self.assertIsNone(self.manager._active)


class JobResumeApiChecks(unittest.TestCase):
    def setUp(self):
        self.job = Job("aabbccddeeff", ["one.srt"], StageFlags(), AppSettings())
        self.manager = Mock()
        for name in ("create", "preempt", "resume", "cancel", "get"):
            getattr(self.manager, name).return_value = self.job
        self.manager.list.return_value = [self.job]
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        self.stack.enter_context(patch("server.MANAGER", self.manager))
        self.stack.enter_context(patch("server.load_settings", return_value=AppSettings()))
        self.server = _EngineHTTPServer(("127.0.0.1", 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.base = f"http://127.0.0.1:{self.server.server_address[1]}"
        self.addCleanup(self._stop_server)

    def _stop_server(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)

    def request(self, path, payload=None, *, method="POST", authenticated=True):
        headers = {"Content-Type": "application/json"}
        if authenticated:
            token = base64.b64encode(b"admin:kikoeta").decode()
            headers["Authorization"] = f"Basic {token}"
        body = None if payload is None else json.dumps(payload).encode()
        with urlopen(Request(self.base + path, data=body, headers=headers, method=method), timeout=2) as response:
            return response.status, json.load(response)

    def test_resume_routes_require_auth_and_return_checkpoint_progress(self):
        for prefix in ("/api/jobs", "/api/v1/jobs"):
            code, body = self.request(f"{prefix}/{self.job.job_id}/resume")
            self.assertEqual(code, 200)
            self.assertIn("completed_files", body)
            self.assertIn("event_cursor", body)
            self.manager.resume.assert_called_with(self.job.job_id)
        self.manager.resume.reset_mock()
        with self.assertRaises(HTTPError) as error:
            self.request(f"/api/v1/jobs/{self.job.job_id}/resume", authenticated=False)
        self.assertEqual(error.exception.code, 401)
        self.manager.resume.assert_not_called()

    def test_action_reads_the_request_body_before_mutating_the_job(self):
        entered = Event()
        original = Handler._read_json

        def read_body(handler):
            entered.set()
            return original(handler)

        connection = http.client.HTTPConnection(*self.server.server_address, timeout=2)
        try:
            with patch.object(Handler, "_read_json", read_body):
                connection.putrequest("POST", f"/api/v1/jobs/{self.job.job_id}/resume")
                connection.putheader("Authorization", "Basic " + base64.b64encode(b"admin:kikoeta").decode())
                connection.putheader("Content-Type", "application/json")
                connection.putheader("Content-Length", "2")
                connection.endheaders()
                self.assertTrue(entered.wait(2), "Control route must read the JSON request body")
                self.manager.resume.assert_not_called()
                connection.send(b"{}")
                response = connection.getresponse()
                self.assertEqual(response.status, 200)
                response.read()
        finally:
            connection.close()
        self.manager.resume.assert_called_once_with(self.job.job_id)

    def test_fresh_remote_import_can_disable_legacy_resume_matching(self):
        self.request("/api/v1/jobs", {"files": ["one.srt"], "resume_existing": False})
        self.assertIs(self.manager.create.call_args.kwargs["resume_existing"], False)



if __name__ == "__main__":
    unittest.main()
