from __future__ import annotations

import base64
import json
import sys
import threading
import unittest
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from kt.models import AppSettings
from server import (
    Handler,
    _EngineHTTPServer,
    _is_remote_api_path,
    _valid_remote_authorization,
)


def _basic(username: str, password: str) -> str:
    encoded = base64.b64encode(f"{username}:{password}".encode()).decode()
    return f"Basic {encoded}"


class RemoteAuthorizationTests(unittest.TestCase):
    def test_default_credentials(self):
        settings = AppSettings.from_dict({})
        self.assertEqual(settings.remote_username, "admin")
        self.assertEqual(settings.remote_password, "kikoeta")
        self.assertTrue(
            _valid_remote_authorization(
                _basic("admin", "kikoeta"),
                settings.remote_username,
                settings.remote_password,
            )
        )

    def test_wrong_or_malformed_credentials_are_rejected(self):
        self.assertFalse(_valid_remote_authorization(None, "admin", "kikoeta"))
        self.assertFalse(_valid_remote_authorization("Bearer token", "admin", "kikoeta"))
        self.assertFalse(_valid_remote_authorization("Basic !!!", "admin", "kikoeta"))
        self.assertFalse(
            _valid_remote_authorization(
                _basic("admin", "wrong"), "admin", "kikoeta"
            )
        )

    def test_custom_credentials_round_trip(self):
        settings = AppSettings.from_dict(
            {"remote_username": "listener", "remote_password": "secret:part"}
        )
        restored = AppSettings.from_dict(settings.to_dict())
        self.assertEqual(restored.remote_username, "listener")
        self.assertEqual(restored.remote_password, "secret:part")
        self.assertTrue(
            _valid_remote_authorization(
                _basic("listener", "secret:part"),
                restored.remote_username,
                restored.remote_password,
            )
        )

    def test_invalid_username_falls_back_to_default(self):
        settings = AppSettings.from_dict(
            {"remote_username": "bad:name", "remote_password": "secret"}
        )
        self.assertEqual(settings.remote_username, "admin")

    def test_public_service_only_exposes_remote_api_paths(self):
        self.assertTrue(_is_remote_api_path("/api/v1/health"))
        self.assertTrue(_is_remote_api_path("/api/v1/jobs/abc"))
        self.assertFalse(_is_remote_api_path("/api/settings"))
        self.assertFalse(_is_remote_api_path("/api/shutdown"))

    def test_unicode_credentials_are_supported(self):
        self.assertTrue(
            _valid_remote_authorization(
                _basic("听众", "密码"), "听众", "密码"
            )
        )

    def test_remote_health_requires_basic_authentication(self):
        server = _EngineHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        port = server.server_address[1]
        url = f"http://127.0.0.1:{port}/api/v1/health"
        try:
            with patch("server.PUBLIC_PORT", port), patch(
                "server.load_settings", return_value=AppSettings()
            ):
                settings_request = Request(
                    f"http://127.0.0.1:{port}/api/settings",
                    headers={"Authorization": _basic("admin", "kikoeta")},
                )
                with self.assertRaises(HTTPError) as hidden_internal_api:
                    urlopen(settings_request, timeout=2)
                self.assertEqual(hidden_internal_api.exception.code, 404)

                with self.assertRaises(HTTPError) as unauthorized:
                    urlopen(url, timeout=2)
                self.assertEqual(unauthorized.exception.code, 401)
                self.assertIn("Basic", unauthorized.exception.headers["WWW-Authenticate"])

                request = Request(url, headers={"Authorization": _basic("admin", "kikoeta")})
                with urlopen(request, timeout=2) as response:
                    payload = json.load(response)
                self.assertTrue(payload["ok"])
                self.assertEqual(payload["revision"], 6)
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)

    def test_cache_listing_requires_authentication_and_exposes_download_urls(self):
        server = _EngineHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        port = server.server_address[1]
        url = f"http://127.0.0.1:{port}/api/v1/cache"
        entries = [
            {
                "job_id": "cached-job",
                "work_id": "RJ123",
                "completed_at": "2026-09-13T00:00:00+00:00",
                "files": [{"track_path": "track.mp3", "name": "track.zh.lrc"}],
            }
        ]
        try:
            with patch("server.load_settings", return_value=AppSettings()), patch(
                "server.list_cached_results", return_value=entries
            ):
                request = Request(url, headers={"Authorization": _basic("admin", "kikoeta")})
                with urlopen(request, timeout=2) as response:
                    payload = json.load(response)
                self.assertEqual(
                    payload["entries"][0]["files"][0]["download_url"],
                    "/api/v1/cache/cached-job/files/0",
                )
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)


if __name__ == "__main__":
    unittest.main()
