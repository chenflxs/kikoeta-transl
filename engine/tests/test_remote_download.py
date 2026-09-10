from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from kt.cleanup import cleanup_intermediates
from kt.jobs import Job, JobManager
from kt.models import AppSettings, FileResult, JobRequest, StageFlags
from server import _materialize_remote_files


class RemoteDownloadTests(unittest.TestCase):
    def test_url_input_is_downloaded_to_a_temporary_directory(self):
        response = MagicMock()
        response.__enter__.return_value = response
        response.geturl.return_value = "https://files.example/song.srt"
        response.status = 200
        response.headers = {"Content-Length": "4"}
        response.read.side_effect = [b"test", b""]

        with tempfile.TemporaryDirectory() as tmp, patch("server.WORK_DIR", Path(tmp)), patch(
            "kt.download.urlopen", return_value=response
        ):
            paths, cleanup_paths = _materialize_remote_files(
                [{"url": "https://files.example/song.srt"}]
            )
            self.assertEqual(Path(paths[0]).name, "000_song.srt")
            self.assertEqual(Path(paths[0]).read_bytes(), b"test")
            self.assertEqual(len(cleanup_paths), 1)
            cleanup_intermediates(*cleanup_paths)
            self.assertFalse(Path(cleanup_paths[0]).exists())

    def test_url_input_rejects_non_http_urls(self):
        with self.assertRaisesRegex(ValueError, "http or https"):
            _materialize_remote_files([{"url": "file:///C:/song.srt"}])

    def test_url_input_forwards_authorization_header(self):
        with tempfile.TemporaryDirectory() as tmp, patch("server.WORK_DIR", Path(tmp)), patch(
            "server.download_http_file"
        ) as download:
            paths, cleanup_paths = _materialize_remote_files(
                [{
                    "url": "https://files.example/song.mp3",
                    "headers": {"Authorization": "Bearer demo"},
                }]
            )
            download.assert_called_once_with(
                "https://files.example/song.mp3",
                Path(paths[0]),
                {"Authorization": "Bearer demo"},
            )
            cleanup_intermediates(*cleanup_paths)

    def test_url_input_rejects_unrelated_headers(self):
        with tempfile.TemporaryDirectory() as tmp, patch("server.WORK_DIR", Path(tmp)):
            with self.assertRaisesRegex(ValueError, "unsupported download header"):
                _materialize_remote_files(
                    [{
                        "url": "https://files.example/song.mp3",
                        "headers": {"Host": "internal.example"},
                    }]
                )

    def test_job_completion_removes_download_directory(self):
        with tempfile.TemporaryDirectory() as tmp:
            download_dir = Path(tmp) / "download"
            download_dir.mkdir()
            source = download_dir / "song.srt"
            source.write_text("test", encoding="utf-8")
            job = Job(
                job_id="test",
                files=[str(source)],
                flags=StageFlags(enable_translate=False),
                settings=AppSettings(),
                cleanup_paths=[str(download_dir)],
            )
            result = FileResult(path=str(source), kind="subtitle", status="done", stage="done")
            with patch("kt.jobs.process_file", return_value=result):
                JobManager()._run(job)
            self.assertEqual(job.status, "completed")
            self.assertFalse(download_dir.exists())

    def test_remote_job_exports_outside_download_directory(self):
        with tempfile.TemporaryDirectory() as tmp, patch("kt.jobs.WORK_DIR", Path(tmp)):
            download_dir = Path(tmp) / "download"
            download_dir.mkdir()
            source = download_dir / "song.mp3"
            source.write_bytes(b"audio")
            job = Job(
                job_id="test",
                files=[str(source)],
                flags=StageFlags(),
                settings=AppSettings(),
                cleanup_paths=[str(download_dir)],
            )

            def fake_process_file(**kwargs):
                output_dir = Path(kwargs["settings"].output.directory)
                output_dir.mkdir(parents=True)
                output = output_dir / "song.zh.lrc"
                output.write_text("[00:00.000] test\n", encoding="utf-8")
                return FileResult(
                    path=str(source),
                    kind="media",
                    status="done",
                    stage="done",
                    outputs=[str(output)],
                )

            with patch("kt.jobs.process_file", side_effect=fake_process_file):
                JobManager()._run(job)
            self.assertFalse(download_dir.exists())
            self.assertTrue(Path(job.results[0].outputs[0]).is_file())


if __name__ == "__main__":
    unittest.main()
