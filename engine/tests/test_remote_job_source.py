from __future__ import annotations

import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from kt.jobs import Job
from kt.models import AppSettings, StageFlags


class RemoteJobSourceTests(unittest.TestCase):
    def test_kikoeta_source_is_exposed_to_the_desktop_client(self) -> None:
        job = Job(
            job_id="remote-job",
            files=["remote.srt"],
            flags=StageFlags(),
            settings=AppSettings(),
            source="kikoeta",
        )

        self.assertEqual(job.to_dict()["source"], "kikoeta")


if __name__ == "__main__":
    unittest.main()
