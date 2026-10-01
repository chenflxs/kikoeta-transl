from __future__ import annotations

import base64
import json
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.request import Request, urlopen

import server
from kt import kikoeta_cache
from kt.models import AppSettings


class CachePushTests(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        for name, value in (("CACHE_DIR", root / "cache"),
                            ("INDEX_PATH", root / "cache" / "index.json")):
            patcher = patch.object(kikoeta_cache, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)
        self.content = "[00:01.00] 缓存译文".encode()
        source = root / "translation.lrc"
        source.write_bytes(self.content)
        kikoeta_cache.cache_completed_job(SimpleNamespace(
            job_id="cached-job", source="kikoeta", status="completed",
            cache_context={"work_id": "rj123", "track_paths": ["disc/01 song.mp3"]},
            results=[SimpleNamespace(outputs=[str(source)])],
        ))
        source.unlink()  # Only the cache survives, as after task cleanup/restart.
        self.received = []
        self.upload_status = 200
        owner = self

        class LlsHandler(BaseHTTPRequestHandler):
            def log_message(self, *_args):
                pass

            def do_POST(self):
                body = self.rfile.read(int(self.headers["Content-Length"]))
                owner.received.append((self.path, self.headers["Authorization"], json.loads(body)))
                self.send_response(owner.upload_status)
                self.end_headers()
                self.wfile.write(b'{"saved":1}')

        lls = self.start_server(LlsHandler)
        self.settings = AppSettings.from_dict({"output": {
            "lls_sync": False,
            "lls_url": f"http://127.0.0.1:{lls.server_port}",
            "lls_key": "a1B2c3D4e5F6",
        }})
        patcher = patch.object(server, "load_settings", return_value=self.settings)
        patcher.start()
        self.addCleanup(patcher.stop)
        engine = self.start_server(server.Handler)
        self.base = f"http://127.0.0.1:{engine.server_port}"

    def start_server(self, handler):
        httpd = ThreadingHTTPServer(("127.0.0.1", 0), handler)
        thread = threading.Thread(target=httpd.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(httpd.server_close)
        self.addCleanup(thread.join, 2)
        self.addCleanup(httpd.shutdown)
        return httpd

    def push(self, suffix="cached-job/files/0"):
        request = Request(f"{self.base}/api/lls/cache/{suffix}", method="POST")
        with urlopen(request, timeout=5) as response:
            return json.load(response)

    def test_push_cached_bytes_without_automatic_sync_or_original_file(self):
        with urlopen(f"{self.base}/api/lls/cache", timeout=5) as response:
            listing = json.load(response)
        self.assertEqual(listing["entries"][0]["work_id"], "RJ123")
        self.assertEqual(self.push(), {"uploaded": 1})
        path, authorization, body = self.received[0]
        self.assertEqual(path, "/api/v1/lyrics")
        self.assertEqual(authorization, "Bearer a1B2c3D4e5F6")
        self.assertEqual(body["workId"], "RJ123")
        self.assertEqual(body["files"][0]["relativePath"], "disc/01 song.zh.lrc")
        self.assertEqual(base64.b64decode(body["files"][0]["content"]), self.content)
        self.assertEqual(kikoeta_cache.cached_file("cached-job", 0).read_bytes(), self.content)

    def test_basic_auth(self):
        self.settings.output.lls_auth_mode = "basic"
        self.settings.output.lls_username = "upload-user"
        self.settings.output.lls_password = "upload-pass"
        self.push()
        token = self.received[0][1].removeprefix("Basic ")
        self.assertEqual(base64.b64decode(token), b"upload-user:upload-pass")

    def test_missing_cache_and_invalid_index_do_not_upload(self):
        for suffix in ("missing/files/0", "cached-job/files/-1", "cached-job/files/1"):
            with self.assertRaises(HTTPError) as error:
                self.push(suffix)
            self.assertEqual(error.exception.code, 404)
        self.assertEqual(self.received, [])

    def test_bad_credentials_do_not_upload(self):
        self.settings.output.lls_key = ""
        with self.assertRaises(HTTPError) as error:
            self.push()
        self.assertEqual(error.exception.code, 400)
        self.assertEqual(self.received, [])

    def test_remote_failure_preserves_cache_for_retry(self):
        self.upload_status = 401
        with self.assertRaises(HTTPError) as error:
            self.push()
        self.assertEqual(error.exception.code, 502)
        self.assertIn("HTTP 401", json.load(error.exception)["error"])
        self.assertTrue(kikoeta_cache.cached_file("cached-job", 0).is_file())
        self.upload_status = 200
        self.assertEqual(self.push(), {"uploaded": 1})

    def test_upload_endpoint_is_not_exposed_on_public_service(self):
        with patch.object(server, "PUBLIC_PORT", int(self.base.rsplit(":", 1)[1])):
            with self.assertRaises(HTTPError) as error:
                self.push()
        self.assertEqual(error.exception.code, 404)
        self.assertEqual(self.received, [])


if __name__ == "__main__":
    unittest.main()
