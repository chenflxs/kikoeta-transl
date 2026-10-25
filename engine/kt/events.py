from __future__ import annotations

from collections import deque
from threading import Condition
from typing import Any, Callable


class EventBus:
    def __init__(self) -> None:
        self._items: deque[dict[str, Any]] = deque()
        self._condition = Condition()
        self._closed = False

    def emit(self, event_type: str, **payload: Any) -> None:
        item = {"type": event_type, **payload}
        with self._condition:
            self._items.append(item)
            self._condition.notify_all()

    def close(self) -> None:
        with self._condition:
            self._closed = True
            self._condition.notify_all()

    def reopen(self) -> None:
        """Continue a resumed job without invalidating existing event cursors."""
        with self._condition:
            self._closed = False

    @property
    def cursor(self) -> int:
        with self._condition:
            return len(self._items)

    def listen(self, after: int = 0, timeout: float = 15.0) -> tuple[list[dict[str, Any]], int, bool]:
        with self._condition:
            self._condition.wait_for(
                lambda: after < len(self._items) or self._closed,
                timeout=timeout,
            )
            batch = list(self._items)[after:]
            return batch, len(self._items), self._closed


EmitFn = Callable[..., None]
