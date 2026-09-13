from __future__ import annotations

import subprocess
from threading import Event


class TaskCancelled(Exception):
    """Raised when a job's cooperative cancellation event is set."""


def raise_if_cancelled(stop_event: Event | None) -> None:
    if stop_event is not None and stop_event.is_set():
        raise TaskCancelled()


def terminate_process(process: subprocess.Popen[object]) -> None:
    """Stop a child process without leaving it running after job cancellation."""
    if process.poll() is not None:
        return
    try:
        process.terminate()
        process.wait(timeout=1)
        return
    except (OSError, subprocess.SubprocessError):
        pass
    try:
        process.kill()
        process.wait(timeout=1)
    except (OSError, subprocess.SubprocessError):
        pass
