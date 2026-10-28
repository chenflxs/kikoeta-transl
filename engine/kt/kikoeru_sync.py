"""Durable per-track delivery to the independently configured kikoeru sidecar.

The queue owns a copy of each LRC before a workflow can clean its inputs or
results. Credentials are read from current local settings, never persisted in
the queue. Source identity and destination configuration remain bound to the
settings that admitted the original remote job.
"""
from __future__ import annotations

import hashlib
import json
import re
import sqlite3
import threading
import time
from contextlib import contextmanager
from http.client import HTTPException
from pathlib import Path
from typing import Any, Callable
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

from .models import OutputSettings
from .settings import load_settings

_MAX_BODY = 8 * 1024 * 1024
_MAX_RESPONSE = 1024 * 1024
_WORK_ID = re.compile(r"(?:RJ|BJ|VJ|CC)[0-9]{1,12}\Z", re.IGNORECASE)
_REMOTE_STATES = {"pending", "processing", "retry", "completed", "conflict", "failed"}
_TERMINAL = {"completed", "conflict", "failed"}


class _Retryable(RuntimeError):
    pass


class _Rejected(RuntimeError):
    def __init__(self, message: str, *, conflict: bool = False, missing: bool = False):
        super().__init__(message)
        self.conflict = conflict
        self.missing = missing


class _NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def _endpoint(output: OutputSettings) -> str:
    value = str(output.kikoeru_url or "").strip().rstrip("/")
    parsed = urlsplit(value)
    try:
        parsed.port
    except ValueError:
        raise ValueError("Kikoeru 外挂地址无效") from None
    if (parsed.scheme not in {"http", "https"} or not parsed.hostname
            or parsed.username is not None or parsed.password is not None
            or parsed.query or parsed.fragment):
        raise ValueError("Kikoeru 外挂地址必须是 HTTP 或 HTTPS 服务地址")
    return value


def _binding(output: OutputSettings) -> str:
    # This is also used by the HTTP ingress when binding a download source.
    from .remote_source import output_binding
    return output_binding(output)


class Outbox:
    def __init__(self, path: Path, settings_loader: Callable = load_settings):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.settings_loader = settings_loader
        self._stop = threading.Event()
        self._wake = threading.Event()
        self._process_lock = threading.Lock()
        self._thread: threading.Thread | None = None
        self._opener = build_opener(_NoRedirect())
        with self._db() as db:
            db.execute("""CREATE TABLE IF NOT EXISTS deliveries (
                delivery_id TEXT PRIMARY KEY, fingerprint TEXT NOT NULL,
                job_id TEXT NOT NULL, file_index INTEGER NOT NULL,
                source_id TEXT NOT NULL, work_id TEXT NOT NULL, track_path TEXT NOT NULL,
                endpoint TEXT NOT NULL, binding TEXT NOT NULL, payload TEXT NOT NULL,
                status TEXT NOT NULL, remote_received INTEGER NOT NULL DEFAULT 0,
                retry_remote INTEGER NOT NULL DEFAULT 0, attempts INTEGER NOT NULL DEFAULT 0,
                next_attempt REAL NOT NULL DEFAULT 0, error TEXT, result TEXT,
                updated REAL NOT NULL
            )""")
            db.execute("UPDATE deliveries SET status='queued',next_attempt=0 WHERE status='processing'")

    @contextmanager
    def _db(self):
        db = sqlite3.connect(str(self.path), timeout=5)
        db.row_factory = sqlite3.Row
        try:
            with db:
                yield db
        finally:
            db.close()

    def start(self) -> None:
        if self._thread is not None and self._thread.is_alive():
            return
        self._stop.clear()
        self._thread = threading.Thread(target=self._run, daemon=True, name="kikoeru-outbox")
        self._thread.start()

    def close(self) -> None:
        self._stop.set()
        self._wake.set()
        if self._thread is not None:
            self._thread.join(timeout=12)

    def enqueue_file(self, job: Any, index: int) -> bool:
        """Copy one completed LRC durably; return whether a new row was added.

        Invalid or unbound jobs do not enqueue. An admitted job with a missing
        result file raises instead of claiming the result was safely copied.
        """
        output = job.lls_output
        context = job.cache_context
        source_id = str(getattr(output, "kikoeru_source_id", "") or "").strip()
        if (job.source != "kikoeta" or output is None or not output.kikoeru_sync
                or index not in context.get("kikoeru_indices", [])
                or context.get("kikoeru_source_id") != source_id
                or context.get("kikoeru_binding") != _binding(output)):
            return False
        if index < 0 or index >= len(job.results) or job.results[index].status != "done":
            return False
        paths = context.get("track_paths")
        work_id = str(context.get("work_id") or "").strip().upper()
        if (not _WORK_ID.fullmatch(work_id) or not isinstance(paths, list)
                or index >= len(paths) or not isinstance(paths[index], str) or not paths[index]):
            raise ValueError("Kikoeru 写回缺少有效作品号或曲目路径")
        lrc_files = [Path(value) for value in job.results[index].outputs if Path(value).suffix.lower() == ".lrc"]
        if len(lrc_files) != 1:
            raise ValueError("Kikoeru 写回需要每条音轨恰好一个 LRC 输出")
        raw = lrc_files[0].read_bytes()
        if not raw or len(raw) > _MAX_BODY:
            raise ValueError("Kikoeru 歌词文件大小无效")
        lrc = raw.decode("utf-8-sig")
        identity = hashlib.sha256(str(job.job_id).encode("utf-8")).hexdigest()[:24]
        delivery_id = f"kt-{identity}-{index}"
        payload = {"delivery_id": delivery_id, "source_id": source_id,
                   "work_id": work_id, "track_path": paths[index], "lrc": lrc}
        encoded = json.dumps(payload, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
        if len(encoded.encode("utf-8")) > _MAX_BODY:
            raise ValueError("Kikoeru 写回请求超过 8 MiB")
        fingerprint = hashlib.sha256(encoded.encode("utf-8")).hexdigest()
        endpoint = _endpoint(output)
        binding = _binding(output)
        with self._db() as db:
            db.execute("BEGIN IMMEDIATE")
            row = db.execute("SELECT fingerprint,endpoint,binding FROM deliveries WHERE delivery_id=?", (delivery_id,)).fetchone()
            if row is not None:
                if (row["fingerprint"] != fingerprint or row["endpoint"] != endpoint or row["binding"] != binding):
                    raise ValueError("同一音轨的 Kikoeru 投递内容发生变化，请检查任务")
                return False
            db.execute("""INSERT INTO deliveries
                (delivery_id,fingerprint,job_id,file_index,source_id,work_id,track_path,endpoint,binding,payload,status,updated)
                VALUES(?,?,?,?,?,?,?,?,?,?,?,?)""",
                (delivery_id, fingerprint, str(job.job_id), index, source_id,
                 work_id, paths[index], endpoint, binding, encoded, "queued", time.time()))
        self._wake.set()
        return True

    def enqueue_job(self, job: Any) -> int:
        return sum(self.enqueue_file(job, index) for index in range(len(job.results)))

    @staticmethod
    def _public(row) -> dict | None:
        if row is None:
            return None
        item = {key: row[key] for key in ("delivery_id", "job_id", "file_index", "source_id", "work_id",
                                          "track_path", "status", "attempts", "error", "updated")}
        item["result"] = json.loads(row["result"]) if row["result"] else None
        return item

    def list_entries(self, limit: int = 100) -> list[dict]:
        limit = max(1, min(int(limit), 500))
        with self._db() as db:
            rows = db.execute("SELECT * FROM deliveries ORDER BY updated DESC,delivery_id LIMIT ?", (limit,)).fetchall()
            return [self._public(row) for row in rows]

    def retry(self, delivery_id: str) -> dict | None:
        with self._db() as db:
            db.execute("""UPDATE deliveries SET status='queued',retry_remote=remote_received,
                          error=NULL,next_attempt=0,updated=? WHERE delivery_id=?
                          AND status IN ('conflict','failed','blocked','paused','retry','waiting')""",
                       (time.time(), delivery_id))
            row = db.execute("SELECT * FROM deliveries WHERE delivery_id=?", (delivery_id,)).fetchone()
            result = self._public(row)
        self._wake.set()
        return result

    def _claim(self):
        with self._db() as db:
            db.execute("BEGIN IMMEDIATE")
            row = db.execute("""SELECT * FROM deliveries WHERE status IN
                ('queued','waiting','retry','paused','blocked','processing') AND next_attempt <= ?
                ORDER BY updated,delivery_id LIMIT 1""", (time.time(),)).fetchone()
            if row is None:
                return None
            db.execute("UPDATE deliveries SET status='processing',attempts=attempts+1,next_attempt=?,updated=? WHERE delivery_id=?",
                       (time.time() + 30, time.time(), row["delivery_id"]))
            return dict(row)

    def _finish(self, row, status: str, *, error: str | None = None, result=None,
                delay: float = 0, received: bool | None = None, retry_remote: bool | None = None):
        with self._db() as db:
            db.execute("""UPDATE deliveries SET status=?,error=?,result=?,next_attempt=?,updated=?,
                remote_received=?,retry_remote=? WHERE delivery_id=?""",
                       (status, error, json.dumps(result, ensure_ascii=False) if result is not None else None,
                        time.time() + delay, time.time(),
                        int(row["remote_received"] if received is None else received),
                        int(row["retry_remote"] if retry_remote is None else retry_remote), row["delivery_id"]))

    def _request(self, row, token: str, method: str, suffix: str, payload: str | None = None):
        body = payload.encode("utf-8") if payload is not None else None
        request = Request(row["endpoint"] + suffix, data=body,
                          headers={"Authorization": "Bearer " + token, "Accept": "application/json",
                                   "Content-Type": "application/json"}, method=method)
        try:
            with self._opener.open(request, timeout=5) as response:
                if response.status not in {200, 202}:
                    raise _Rejected("Kikoeru 外挂返回无效响应")
                raw = response.read(_MAX_RESPONSE + 1)
                declared_size = response.headers.get("Content-Length")
                if declared_size and declared_size.isdecimal() and len(raw) < min(int(declared_size), _MAX_RESPONSE + 1):
                    raise _Retryable("Kikoeru 外挂响应被中断")
        except HTTPError as exc:
            code = exc.code
            exc.close()
            if code in {408, 429} or code >= 500:
                raise _Retryable(f"Kikoeru 外挂暂时不可用（HTTP {code}）") from None
            raise _Rejected(f"Kikoeru 外挂拒绝请求（HTTP {code}）", conflict=code == 409, missing=code == 404) from None
        except (URLError, OSError, TimeoutError, HTTPException):
            raise _Retryable("无法连接 Kikoeru 外挂") from None
        if len(raw) > _MAX_RESPONSE:
            raise _Rejected("Kikoeru 外挂响应过大")
        try:
            record = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, ValueError):
            raise _Rejected("Kikoeru 外挂响应格式无效") from None
        if (not isinstance(record, dict) or record.get("delivery_id") != row["delivery_id"]
                or not isinstance(record.get("status"), str)
                or record["status"] not in _REMOTE_STATES
                or (record.get("result") is not None and not isinstance(record["result"], dict))
                or (record.get("error") is not None and not isinstance(record["error"], str))):
            raise _Rejected("Kikoeru 外挂任务响应不匹配")
        return record

    def process_once(self) -> bool:
        """Process one due record synchronously; useful for bounded checks."""
        with self._process_lock:
            row = self._claim()
            if row is None:
                return False
            try:
                current = self.settings_loader()
                output = current.output if hasattr(current, "output") else current
                if not output.kikoeru_sync:
                    self._finish(row, "paused", error="Kikoeru 自动写回已关闭", delay=5)
                    return True
                if _binding(output) != row["binding"] or _endpoint(output) != row["endpoint"]:
                    self._finish(row, "blocked", error="Kikoeru 来源配置已变化，请核对后恢复原配置", delay=5)
                    return True
                token = str(output.kikoeru_token or "")
                if len(token) < 10 or "\r" in token or "\n" in token:
                    self._finish(row, "blocked", error="请配置 Kikoeru 外挂密钥", delay=5)
                    return True
                suffix = "/v1/deliveries/" + quote(row["delivery_id"], safe="")
                if row["retry_remote"]:
                    record = self._request(row, token, "POST", suffix + "/retry", "{}")
                elif row["remote_received"]:
                    record = self._request(row, token, "GET", suffix)
                else:
                    record = self._request(row, token, "POST", "/v1/deliveries", row["payload"])
                remote_status = record["status"]
                if remote_status in _TERMINAL:
                    self._finish(row, remote_status, error=str(record.get("error") or "")[:1000] or None,
                                 result=record.get("result"), received=True, retry_remote=False)
                else:
                    self._finish(row, "waiting", error=str(record.get("error") or "")[:1000] or None,
                                 result=record.get("result"), delay=2, received=True, retry_remote=False)
            except _Retryable as exc:
                self._finish(row, "retry", error=str(exc), delay=min(300, 2 ** min(row["attempts"] + 1, 8)))
            except _Rejected as exc:
                if exc.missing and row["remote_received"]:
                    self._finish(row, "retry", error="外挂任务记录不存在，将重新投递", delay=2, received=False, retry_remote=False)
                else:
                    self._finish(row, "conflict" if exc.conflict else "failed", error=str(exc))
            except (ValueError, TypeError, AttributeError):
                self._finish(row, "blocked", error="Kikoeru 写回配置无效", delay=5)
            except OSError:
                self._finish(row, "retry", error="无法读取 Kikoeru 写回配置", delay=5)
            return True

    def _run(self):
        while not self._stop.is_set():
            try:
                processed = self.process_once()
            except (sqlite3.Error, OSError):
                # Claims have a lease so a failed final update can recover
                # without losing the durable LRC or silently stopping the worker.
                self._stop.wait(2)
                continue
            if not processed:
                self._wake.wait(1)
                self._wake.clear()
