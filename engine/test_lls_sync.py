from __future__ import annotations

import base64
import json
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from kt.lls_sync import lyric_path, sync_completed_job
from kt.models import AppSettings


class LlsSyncTests(unittest.TestCase):
    def test_settings_and_track_path(self) -> None:
        settings = AppSettings.from_dict({"output": {
            "lls_sync": True, "lls_url": "https://example.test/lls",
            "lls_auth_mode": "basic", "lls_username": "u", "lls_password": "p",
        }})
        self.assertTrue(settings.output.lls_sync)
        self.assertEqual(settings.to_dict()["output"]["lls_url"], "https://example.test/lls")
        self.assertEqual(lyric_path("disc/01 - Song.mp3", ".lrc"), "disc/01 - Song.zh.lrc")
        self.assertEqual(lyric_path("disc\\bad:name.wav", ".srt"), "disc/bad_name.zh.srt")

    def test_only_completed_kikoeta_jobs_upload_with_selected_auth(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "translated.lrc"
            source.write_bytes(b"[00:01.00]translated")
            job = SimpleNamespace(
                source="kikoeta", status="completed",
                cache_context={"work_id": "rj123", "track_paths": ["disc/song.mp3"]},
                results=[SimpleNamespace(outputs=[str(source)])],
            )
            output = AppSettings.from_dict({"output": {
                "lls_sync": True, "lls_key": "a1B2c3D4e5F6",
            }}).output

            class Response:
                def __enter__(self):
                    return self

                def __exit__(self, *_args):
                    return False

                def read(self, _limit):
                    return b'{"saved":1}'

            with patch("kt.lls_sync.urlopen", return_value=Response()) as send:
                self.assertEqual(sync_completed_job(job, output), 1)
                request = send.call_args.args[0]
                self.assertEqual(request.full_url, "http://127.0.0.1:2378/api/v1/lyrics")
                self.assertEqual(request.get_header("Authorization"), "Bearer a1B2c3D4e5F6")
                payload = json.loads(request.data)
                self.assertEqual(payload["workId"], "RJ123")
                self.assertEqual(payload["files"][0]["relativePath"], "disc/song.zh.lrc")
                self.assertEqual(base64.b64decode(payload["files"][0]["content"]), source.read_bytes())
                job.source = "desktop"
                self.assertEqual(sync_completed_job(job, output), 0)
                self.assertEqual(send.call_count, 1)
            output.lls_auth_mode = "basic"
            output.lls_username = "transl-user"
            output.lls_password = "different-password"
            output.lls_url = "https://example.test/lls/"
            job.source = "kikoeta"
            with patch("kt.lls_sync.urlopen", return_value=Response()) as send:
                self.assertEqual(sync_completed_job(job, output), 1)
                request = send.call_args.args[0]
                self.assertEqual(request.full_url, "https://example.test/lls/api/v1/lyrics")
                token = request.get_header("Authorization").split(" ", 1)[1]
                self.assertEqual(base64.b64decode(token).decode(), "transl-user:different-password")


if __name__ == "__main__":
    unittest.main()
