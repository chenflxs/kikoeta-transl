from __future__ import annotations

import json
from collections import deque
from threading import Event
from typing import Any, Callable


class EventBus:
    def __init__(self) -> None:
        self._items: deque[dict[str, Any]] = deque()
        self._wait = Event()
        self._closed = False

    def emit(self, event_type: str, **payload: Any) -> None:
        item = {"type": event_type, **payload}
        self._items.append(item)
        self._wait.set()

    def close(self) -> None:
        self._closed = True
        self._wait.set()

    def listen(self, after: int = 0, timeout: float = 15.0) -> tuple[list[dict[str, Any]], int, bool]:
        if after >= len(self._items) and not self._closed:
            self._wait.clear()
            self._wait.wait(timeout)
        batch = list(self._items)[after:]
        return batch, len(self._items), self._closed


EmitFn = Callable[..., None]
