from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from kt import kikoeta_cache


class KikoetaCacheTests(unittest.TestCase):
    def test_completed_kikoeta_jobs_keep_only_the_latest_five_lrc_results(self):
        with tempfile.TemporaryDirectory() as temp:
            cache_dir = Path(temp) / "cache"
            index_path = cache_dir / "index.json"
            output = Path(temp) / "result.lrc"
            output.write_text("[00:00.00]歌词", encoding="utf-8")

            with patch.object(kikoeta_cache, "CACHE_DIR", cache_dir), patch.object(
                kikoeta_cache, "INDEX_PATH", index_path
            ):
                for index in range(6):
                    job = SimpleNamespace(
                        job_id=f"job-{index}",
                        source="kikoeta",
                        status="completed",
                        cache_context={
                            "work_id": "RJ123",
                            "track_paths": [f"track-{index}.mp3"],
                        },
                        results=[SimpleNamespace(outputs=[str(output)])],
                    )
                    self.assertEqual(kikoeta_cache.cache_completed_job(job), 1)

                entries = kikoeta_cache.list_cached_results()
                self.assertEqual([entry["job_id"] for entry in entries], [
                    "job-5", "job-4", "job-3", "job-2", "job-1"
                ])
                self.assertFalse((cache_dir / "job-0").exists())
                self.assertEqual(
                    kikoeta_cache.cached_file("job-5", 0).read_text(encoding="utf-8"),
                    "[00:00.00]歌词",
                )

    def test_non_kikoeta_jobs_are_not_cached(self):
        job = SimpleNamespace(
            source="desktop",
            status="completed",
            cache_context={},
        )
        self.assertEqual(kikoeta_cache.cache_completed_job(job), 0)


if __name__ == "__main__":
    unittest.main()
