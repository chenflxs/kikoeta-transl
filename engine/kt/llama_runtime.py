from __future__ import annotations

import json
import os
import socket
import subprocess
import threading
import time
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from threading import Event
from typing import BinaryIO
from urllib.request import ProxyHandler, build_opener

from .cancellation import TaskCancelled, raise_if_cancelled, terminate_process
from .models import AppSettings
from .tools import (
    LOCAL_LLAMA_ENDPOINT,
    LOCAL_LLAMA_HOST,
    LOCAL_LLAMA_OPENAI_BASE,
    LOCAL_LLAMA_PORT,
    list_llama_models,
    popen_kwargs,
)


@dataclass(frozen=True)
class _Selection:
    executable: Path
    model_path: Path
    ctx_size: int | None
    gpu_layers: int | None

    def command(self) -> list[str]:
        command = [
            str(self.executable),
            "-m",
            str(self.model_path),
            "--host",
            LOCAL_LLAMA_HOST,
            "--port",
            str(LOCAL_LLAMA_PORT),
        ]
        if self.ctx_size is not None:
            command.extend(("--ctx-size", str(self.ctx_size)))
        if self.gpu_layers is not None:
            command.extend(("--gpu-layers", str(self.gpu_layers)))
        return command


class _StderrTail:
    _LIMIT = 4096

    def __init__(self, stream: BinaryIO) -> None:
        self._lock = threading.Lock()
        self._buffer = bytearray()
        self._reader = threading.Thread(target=self._drain, args=(stream,), daemon=True)
        self._reader.start()

    def _drain(self, stream: BinaryIO) -> None:
        with stream:
            try:
                while chunk := os.read(stream.fileno(), self._LIMIT):
                    with self._lock:
                        self._buffer.extend(chunk)
                        del self._buffer[:-self._LIMIT]
            except OSError:
                pass

    def describe(self, message: str) -> str:
        # Allow the reader to consume the last bytes after process exit.
        self._reader.join(timeout=0.25)
        with self._lock:
            tail = self._buffer.decode("utf-8", errors="replace").strip()
        return f"{message}\n{tail}" if tail else message


class LlamaRuntime:
    def __init__(self) -> None:
        self._lock = threading.RLock()
        self._process: subprocess.Popen[bytes] | None = None
        self._selection: _Selection | None = None
        self._stderr: _StderrTail | None = None
        self._model_id = ""
        self._users = 0
        self._job_scopes = 0
        self._error = ""

    @contextmanager
    def session(self, settings: AppSettings, stop_event: Event | None = None):
        model_id = self.acquire(settings, stop_event)
        try:
            yield model_id
        finally:
            self.release()

    @contextmanager
    def job_scope(self):
        """Keep an already-started server available across stages of one job."""
        with self._lock:
            self._job_scopes += 1
        try:
            yield
        finally:
            with self._lock:
                self._job_scopes -= 1
                if not self._users and not self._job_scopes:
                    self._stop_locked()

    def acquire(self, settings: AppSettings, stop_event: Event | None = None) -> str:
        with self._lock:
            selection = self._resolve_selection(settings)
            self._refresh_process_state()
            if self._process is not None and self._selection != selection:
                if self._users:
                    raise RuntimeError("本地 Llama 正被其他任务使用，暂时无法切换启动配置")
                self._stop_locked()
            if self._process is None:
                if self._users:
                    raise RuntimeError("本地 Llama 已意外退出，正在等待旧请求结束后重试")
                self._start_locked(selection, stop_event)
            self._users += 1
            return self._model_id

    def release(self) -> None:
        with self._lock:
            if self._users:
                self._users -= 1
                if not self._users and not self._job_scopes:
                    self._stop_locked()

    def shutdown(self) -> None:
        with self._lock:
            self._stop_locked()

    def status(self) -> dict[str, object]:
        if not self._lock.acquire(blocking=False):
            selection = self._selection
            return {
                "status": "starting",
                "loaded_model": selection.model_path.name if selection else "",
                "model_id": self._model_id,
                "error": "",
            }
        try:
            self._refresh_process_state()
            if self._process is None:
                state = "error" if self._error else "stopped"
            else:
                state = "busy" if self._users else "ready"
            return {
                "status": state,
                "loaded_model": self._selection.model_path.name if self._selection else "",
                "model_id": self._model_id,
                "error": self._error,
            }
        finally:
            self._lock.release()

    def _resolve_selection(self, settings: AppSettings) -> _Selection:
        info = list_llama_models(settings)
        executable_text = str(info.get("executable") or "")
        if not executable_text:
            raise FileNotFoundError("未找到 llama-server 可执行文件")
        selected = settings.llama_model.strip()
        if not selected:
            raise RuntimeError("尚未选择本地 Llama 模型")
        for item in info.get("models") or []:
            if isinstance(item, dict) and item.get("id") == selected:
                return _Selection(
                    executable=Path(executable_text).resolve(),
                    model_path=Path(str(item["path"])).resolve(),
                    ctx_size=settings.llama_ctx_size,
                    gpu_layers=settings.llama_gpu_layers,
                )
        raise FileNotFoundError(f"未找到已选择的本地 Llama 模型：{selected}")

    def _start_locked(
        self,
        selection: _Selection,
        stop_event: Event | None,
    ) -> None:
        if _port_is_open():
            raise RuntimeError(f"本地 Llama 固定端口 {LOCAL_LLAMA_PORT} 已被其他进程占用")
        self._error = ""
        process = None
        stderr = None
        try:
            process = subprocess.Popen(
                selection.command(),
                cwd=str(selection.executable.parent),
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE,
                **popen_kwargs(),
            )
            assert process.stderr is not None
            stderr = _StderrTail(process.stderr)
            self._process = process
            self._selection = selection
            self._stderr = stderr
            self._model_id = self._wait_until_ready(process, stop_event)
        except BaseException as exc:
            if process is not None:
                terminate_process(process)
            self._clear_process()
            if isinstance(exc, Exception) and not isinstance(exc, TaskCancelled):
                self._error = stderr.describe(str(exc)) if stderr else str(exc)
                if self._error != str(exc):
                    raise RuntimeError(self._error) from exc
            raise

    def _wait_until_ready(
        self,
        process: subprocess.Popen[bytes],
        stop_event: Event | None,
    ) -> str:
        deadline = time.monotonic() + 180
        last_error = ""
        while time.monotonic() < deadline:
            raise_if_cancelled(stop_event)
            code = process.poll()
            if code is not None:
                raise RuntimeError(f"llama-server 启动失败，退出码 {code}")
            try:
                models = _remote_models()
                if models:
                    return models[0]
            except Exception as exc:
                last_error = str(exc)
            time.sleep(0.25)
        detail = f"：{last_error}" if last_error else ""
        raise RuntimeError(f"等待 llama-server 加载模型超时{detail}")

    def _refresh_process_state(self) -> None:
        if self._process is not None and self._process.poll() is not None:
            message = f"llama-server 已退出，退出码 {self._process.returncode}"
            self._error = self._stderr.describe(message) if self._stderr else message
            self._clear_process()

    def _clear_process(self) -> None:
        self._process = None
        self._selection = None
        self._stderr = None
        self._model_id = ""

    def _stop_locked(self) -> None:
        process = self._process
        self._clear_process()
        self._users = 0
        if process is not None:
            terminate_process(process)


def _port_is_open() -> bool:
    try:
        with socket.create_connection((LOCAL_LLAMA_HOST, LOCAL_LLAMA_PORT), timeout=0.25):
            return True
    except OSError:
        return False


def _remote_models() -> list[str]:
    opener = build_opener(ProxyHandler({}))
    with opener.open(f"{LOCAL_LLAMA_OPENAI_BASE}/models", timeout=1) as response:
        payload = json.loads(response.read().decode("utf-8"))
    data = payload.get("data") if isinstance(payload, dict) else None
    if not isinstance(data, list):
        return []
    return [
        str(item.get("id") or "").strip()
        for item in data
        if isinstance(item, dict) and str(item.get("id") or "").strip()
    ]


LLAMA_RUNTIME = LlamaRuntime()


@contextmanager
def local_llama_session(settings: AppSettings, stop_event: Event | None = None):
    with LLAMA_RUNTIME.session(settings, stop_event) as model_id:
        yield LOCAL_LLAMA_ENDPOINT, LOCAL_LLAMA_OPENAI_BASE, model_id
