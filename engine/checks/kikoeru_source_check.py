from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from kt.models import OutputSettings
from kt.remote_source import bind_context, matches_media_url, output_binding


class SourceBindingChecks(unittest.TestCase):
    def output(self, **changes):
        return OutputSettings(kikoeru_sync=True, kikoeru_url="http://localhost:2379",
                              kikoeru_source_id="home", kikoeru_media_url_prefix="https://audio.example/api/media/download/",
                              **changes)

    def test_origin_path_boundaries_and_signed_query(self):
        prefix = "https://audio.example/api/media/download/"
        self.assertTrue(matches_media_url("https://audio.example:443/api/media/download/123/0?token=secret", prefix))
        for value in ("https://audio.example.evil/api/media/download/123/0",
                      "http://audio.example/api/media/download/123/0",
                      "https://audio.example:8443/api/media/download/123/0",
                      "https://audio.example/api/media/download-evil/123/0",
                      "https://user@audio.example/api/media/download/123/0",
                      "https://audio.example/api/media/download/%2e%2e/other",
                      "https://audio.example/api/media/download/%5cother"):
            self.assertFalse(matches_media_url(value, prefix), value)

    def test_mixed_sources_bind_only_explicitly_matched_tracks(self):
        payload = {"files": [{"url": "https://audio.example/api/media/download/1/0?token=private"},
                             {"url": "https://public.example/api/media/download/1/0"},
                             {"content_base64": "YQ=="}],
                   "cache": {"work_id": "RJ123456", "track_paths": ["a.wav", "b.wav", "c.wav"],
                             "kikoeru_source_id": "attacker"}}
        context = bind_context(payload, self.output())
        self.assertEqual(context["kikoeru_indices"], [0])
        self.assertEqual(context["kikoeru_source_id"], "home")
        self.assertNotIn("private", str(context))
        self.assertNotIn("attacker", str(context))

    def test_credentials_can_rotate_but_source_changes_do_not_match(self):
        original = self.output()
        first = output_binding(original)
        original.kikoeru_token = "new-credential"
        self.assertEqual(output_binding(original), first)
        original.kikoeru_source_id = "another"
        self.assertNotEqual(output_binding(original), first)

    def test_disabled_does_not_bind_and_invalid_configuration_fails(self):
        payload = {"files": [{"url": "https://audio.example/api/media/download/1/0"}],
                   "cache": {"work_id": "RJ123456", "track_paths": ["a.wav"]}}
        output = self.output()
        output.kikoeru_sync = False
        self.assertNotIn("kikoeru_indices", bind_context(payload, output))
        output.kikoeru_sync = True
        output.kikoeru_media_url_prefix += "?token=secret"
        with self.assertRaises(ValueError):
            bind_context(payload, output)


if __name__ == "__main__":
    unittest.main()
