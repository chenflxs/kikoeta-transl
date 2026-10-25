"""Loopback KT API fixture: real scheduling/HTTP/downloads, deterministic stages."""
from __future__ import annotations

import json
import sys
import tempfile
import threading
from contextlib import ExitStack
from pathlib import Path
from urllib.parse import urlparse
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from kt.jobs import JobManager
from kt.models import AppSettings, FileResult


def main():
    with tempfile.TemporaryDirectory() as temporary, ExitStack() as stack:
        root = Path(temporary)
        settings = AppSettings()
        stack.enter_context(patch("kt.jobs.WORK_DIR", root / "work"))
        for name, value in (
            ("kt.jobs.load_settings", settings),
            ("kt.jobs.cache_completed_job", 0),
            ("kt.jobs.sync_completed_job", 0),
            ("kt.jobs.record_finished_job", None),
        ):
            stack.enter_context(patch(name, return_value=value))
        import server

        manager = JobManager()
        calls = []
        downloads = []
        interrupted = False

        def process(**kwargs):
            nonlocal interrupted
            work = manager._active.cache_context["work_id"]
            index = int(kwargs["job_dir"].name[:4])
            calls.append([work, index])
            if work == "RJ111111" and index == 2 and not interrupted:
                interrupted = True
                if not kwargs["stop_event"].wait(15):
                    raise TimeoutError("test must preempt the running file")
                return FileResult(kwargs["path"], "media", status="cancelled")
            output = kwargs["job_dir"] / "result.lrc"
            output.write_text(f"[00:00.00] {work}:{index}", encoding="utf-8")
            kwargs["emit"]("file_done", file=kwargs["path"])
            return FileResult(kwargs["path"], "media", status="done", outputs=[str(output)])

        stack.enter_context(patch("kt.jobs.process_file", side_effect=process))
        stack.enter_context(patch("server.MANAGER", manager))
        stack.enter_context(patch("server.WORK_DIR", root / "work"))
        stack.enter_context(patch("server.load_settings", return_value=settings))

        class Handler(server.Handler):
            def log_message(self, *_):
                pass

            def do_GET(self):
                path = urlparse(self.path).path
                if path.startswith("/audio/"):
                    downloads.append(path)
                    self._send(200, b"fixture audio", content_type="application/octet-stream")
                elif path == "/test/state":
                    self._json({"calls": calls, "downloads": downloads, "jobs": len(manager.list())})
                else:
                    super().do_GET()

        http = server._EngineHTTPServer(("127.0.0.1", 0), Handler)
        worker = threading.Thread(target=http.serve_forever, daemon=True)
        worker.start()
        print(json.dumps({"endpoint": f"http://127.0.0.1:{http.server_port}"}), flush=True)
        try:
            sys.stdin.readline()
        finally:
            manager.shutdown()
            http.shutdown()
            http.server_close()
            worker.join(timeout=3)


if __name__ == "__main__":
    main()
