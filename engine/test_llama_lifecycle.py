from __future__ import annotations

import unittest
from pathlib import Path
from threading import Event
from unittest.mock import Mock, patch

from kt.cancellation import TaskCancelled
from kt.llama_runtime import LlamaRuntime
from kt.models import AppSettings


class LlamaLifecycleTests(unittest.TestCase):
    def setUp(self) -> None:
        self.runtime = LlamaRuntime()
        self.settings = AppSettings()
        self.process = Mock()
        self.process.poll.return_value = None
        stop_patch = patch("kt.llama_runtime.terminate_process")
        self.stopped = stop_patch.start()
        self.addCleanup(stop_patch.stop)

        def start(_executable, model_path, _stop_event):
            self.runtime._process = self.process
            self.runtime._model_path = model_path
            self.runtime._model_id = "served-model"

        resolve_patch = patch.object(
            self.runtime,
            "_resolve_selection",
            return_value=(Path("model.gguf"), Path("llama-server.exe")),
        )
        resolve_patch.start()
        self.addCleanup(resolve_patch.stop)
        start_patch = patch.object(self.runtime, "_start_locked", side_effect=start)
        self.start = start_patch.start()
        self.addCleanup(start_patch.stop)

    def test_standalone_session_stops_after_success(self) -> None:
        with self.runtime.session(self.settings) as model_id:
            self.assertEqual(model_id, "served-model")
            self.stopped.assert_not_called()
        self.stopped.assert_called_once_with(self.process)
        self.assertEqual(self.runtime.status()["status"], "stopped")

    def test_standalone_session_stops_after_cancellation(self) -> None:
        with self.assertRaises(TaskCancelled):
            with self.runtime.session(self.settings, Event()):
                raise TaskCancelled()
        self.stopped.assert_called_once_with(self.process)

    def test_job_scope_reuses_model_then_stops_on_completion(self) -> None:
        with self.runtime.job_scope():
            with self.runtime.session(self.settings):
                pass
            self.stopped.assert_not_called()
            with self.runtime.session(self.settings):
                pass
            self.assertEqual(self.start.call_count, 1)
        self.stopped.assert_called_once_with(self.process)

    def test_job_scope_stops_after_interruption(self) -> None:
        with self.assertRaises(TaskCancelled):
            with self.runtime.job_scope():
                with self.runtime.session(self.settings):
                    pass
                raise TaskCancelled()
        self.stopped.assert_called_once_with(self.process)

    def test_other_job_keeps_server_alive(self) -> None:
        with self.runtime.job_scope():
            with self.runtime.job_scope():
                with self.runtime.session(self.settings):
                    pass
            self.stopped.assert_not_called()
        self.stopped.assert_called_once_with(self.process)

    def test_other_active_session_keeps_server_alive(self) -> None:
        with self.runtime.session(self.settings):
            with self.runtime.session(self.settings):
                self.assertEqual(self.start.call_count, 1)
            self.stopped.assert_not_called()
        self.stopped.assert_called_once_with(self.process)

    def test_crashed_server_cannot_be_replaced_while_old_session_is_active(self) -> None:
        with self.runtime.session(self.settings):
            self.process.poll.return_value = 1
            self.process.returncode = 1
            self.assertEqual(self.runtime.status()["status"], "error")
            with self.assertRaisesRegex(RuntimeError, "旧请求结束"):
                self.runtime.acquire(self.settings)
            self.assertEqual(self.start.call_count, 1)
        self.runtime.acquire(self.settings)
        self.assertEqual(self.start.call_count, 2)
        self.runtime.release()


if __name__ == "__main__":
    unittest.main()
