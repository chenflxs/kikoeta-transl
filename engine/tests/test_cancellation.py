from __future__ import annotations

import io
import sys
import tempfile
import time
import unittest
from contextlib import nullcontext
from pathlib import Path
from threading import Event
from types import SimpleNamespace
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from kt.cancellation import TaskCancelled
from kt.models import AppSettings, CorrectionSettings, Cue, StageFlags


class _CancellingProcess:
    def __init__(self, stop_event: Event):
        self.stop_event = stop_event
        self.returncode = None
        self.terminated = False
        self.stdout = io.StringIO()
        self.stderr = io.StringIO()

    def poll(self):
        return None if not self.terminated else -15

    def communicate(self, timeout=None):
        self.stop_event.set()
        raise __import__("subprocess").TimeoutExpired("demo", timeout)

    def terminate(self):
        self.terminated = True

    def kill(self):
        self.terminated = True

    def wait(self, timeout=None):
        self.returncode = -15
        return self.returncode


class CancellationTests(unittest.TestCase):
    def test_transcode_terminates_ffmpeg_when_cancelled(self):
        from kt.stages.transcode import transcode_to_wav

        stop_event = Event()
        process = _CancellingProcess(stop_event)
        with tempfile.TemporaryDirectory() as tmp, patch(
            "kt.stages.transcode.resolve_ffmpeg", return_value=("ffmpeg", "ffprobe")
        ), patch("kt.stages.transcode.subprocess.Popen", return_value=process):
            with self.assertRaises(TaskCancelled):
                transcode_to_wav("input.mp3", Path(tmp), AppSettings(), stop_event=stop_event)
        self.assertTrue(process.terminated)

    def test_asr_runner_terminates_process_when_cancelled(self):
        from kt.stages.asr import _run_with_heartbeat

        stop_event = Event()
        stop_event.set()
        process = _CancellingProcess(stop_event)
        with patch("kt.stages.asr.subprocess.Popen", return_value=process):
            with self.assertRaises(TaskCancelled):
                _run_with_heartbeat(
                    ["crispasr"],
                    emit=None,
                    file=None,
                    stop_event=stop_event,
                )
        self.assertTrue(process.terminated)

    def test_correction_does_not_start_a_request_after_cancellation(self):
        from kt.stages.correct import correct_cues

        stop_event = Event()
        stop_event.set()
        settings = AppSettings(
            correct=CorrectionSettings(base_url="https://example.test", model="demo")
        )
        with patch("kt.stages.correct._chat") as chat:
            with self.assertRaises(TaskCancelled):
                correct_cues(
                    [Cue(0, 1, "こんにちは")],
                    settings,
                    stop_event=stop_event,
                )
        chat.assert_not_called()

    def test_correction_stops_waiting_for_an_inflight_request(self):
        from kt.stages.correct import correct_cues

        stop_event = Event()
        release_request = Event()
        settings = AppSettings(
            correct=CorrectionSettings(base_url="https://example.test", model="demo")
        )

        def blocking_request(*_args, **_kwargs):
            release_request.wait(timeout=2)
            return '["こんにちは"]'

        from threading import Timer

        timer = Timer(0.05, stop_event.set)
        started = time.monotonic()
        try:
            with patch("kt.stages.correct._chat", side_effect=blocking_request):
                timer.start()
                with self.assertRaises(TaskCancelled):
                    correct_cues(
                        [Cue(0, 1, "こんにちは")],
                        settings,
                        stop_event=stop_event,
                    )
        finally:
            timer.cancel()
            release_request.set()
        self.assertLess(time.monotonic() - started, 1)

    def test_cancelled_galtransl_state_is_not_reported_as_failure(self):
        from kt.stages.translate import translate_cues

        async def cancelled_job(*_args, **_kwargs):
            return SimpleNamespace(success=False, status="cancelled", error="用户请求停止翻译")

        with tempfile.TemporaryDirectory() as tmp, patch(
            "kt.stages.translate.ensure_galtransl_path"
        ), patch("kt.stages.translate._write_dicts"), patch(
            "kt.stages.translate._write_config"
        ), patch("kt.stages.translate.galtransl_cwd", return_value=nullcontext()), patch(
            "kt.stages.translate._run_job", side_effect=cancelled_job
        ):
            with self.assertRaises(TaskCancelled):
                translate_cues(
                    [Cue(0, 1, "こんにちは")],
                    Path(tmp),
                    AppSettings(),
                    stop_event=Event(),
                )

    def test_pipeline_marks_cancellation_as_cancelled(self):
        from kt.pipeline import process_file

        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / "song.srt"
            source.write_text("1\n00:00:00,000 --> 00:00:01,000\nこんにちは\n", encoding="utf-8")
            stop_event = Event()

            def cancel_during_translation(*_args, **kwargs):
                kwargs["stop_event"].set()
                raise TaskCancelled()

            with patch(
                "kt.stages.translate.translate_cues", side_effect=cancel_during_translation
            ):
                result = process_file(
                    str(source),
                    AppSettings(),
                    StageFlags(enable_translate=True),
                    Path(tmp) / "job",
                    emit=lambda *_args, **_kwargs: None,
                    stop_event=stop_event,
                )
            self.assertEqual(result.status, "cancelled")
            self.assertEqual(result.stage, "cancelled")


if __name__ == "__main__":
    unittest.main()
