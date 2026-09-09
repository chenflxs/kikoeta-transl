from __future__ import annotations

import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from server import _EngineHTTPServer


class ShutdownTests(unittest.TestCase):
    def test_long_poll_threads_do_not_block_engine_exit(self):
        self.assertTrue(_EngineHTTPServer.daemon_threads)
        self.assertFalse(_EngineHTTPServer.block_on_close)


if __name__ == "__main__":
    unittest.main()
