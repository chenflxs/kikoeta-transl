"""Download official CLI releases, stage them, then replace runtime files with rollback."""
from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import tarfile
import tempfile
import time
import zipfile
from functools import lru_cache
from pathlib import Path, PurePosixPath
from threading import Event, RLock, Thread
from urllib.request import ProxyHandler, Request, build_opener

from .crispasr_releases import compatible_assets, environment
from .models import AppSettings
from .tools import popen_kwargs, resolve_crispasr_dir

REPOSITORY = "https://github.com/CrispStrobe/CrispASR"
LATEST_API = "https://api.github.com/repos/CrispStrobe/CrispASR/releases/latest"
_MANIFEST = ".kikoeta-runtime.json"
_BUSY = {"downloading", "extracting", "installing"}


def _opener(proxy: str):
    return build_opener(ProxyHandler({"http": proxy, "https": proxy}) if proxy else ProxyHandler({}))


@lru_cache(maxsize=8)
def _version(executable: str, modified: int, size: int) -> dict:
    try:
        result = subprocess.run([executable, "--version"], capture_output=True, timeout=12, **popen_kwargs())
        text = (result.stdout + result.stderr).decode("utf-8", errors="replace")
        match = re.search(r"(?:version\s*:\s*|crispasr\s+)(\d+\.\d+\.\d+)", text, re.I)
        if result.returncode or not match:
            raise RuntimeError(text.strip()[-600:] or f"exit {result.returncode}")
        return {"version": match[1], "error": ""}
    except (OSError, subprocess.SubprocessError, RuntimeError) as exc:
        return {"version": "", "error": str(exc)}


def local_status(settings: AppSettings) -> dict:
    folder = resolve_crispasr_dir(settings).resolve()
    executable = folder / ("crispasr.exe" if os.name == "nt" else "crispasr")
    exists = executable.is_file()
    info = {"version": "", "error": ""}
    if exists:
        details = executable.stat()
        info = _version(str(executable), details.st_mtime_ns, details.st_size)
    return {"installed": exists, "dir": str(folder), **info}


def _archive_path(name: str) -> Path:
    path = PurePosixPath(name)
    if path.is_absolute() or ".." in path.parts or "\\" in name or ":" in name:
        raise ValueError("发行包包含不安全的文件路径")
    return Path(*path.parts)


def extract_package(archive: Path, destination: Path) -> Path:
    total = 0
    if zipfile.is_zipfile(archive):
        with zipfile.ZipFile(archive) as package:
            members = package.infolist()
            if len(members) > 12000:
                raise ValueError("发行包文件过多")
            for member in members:
                _archive_path(member.filename)
                if stat.S_ISLNK(member.external_attr >> 16):
                    raise ValueError("ZIP 发行包不能包含符号链接")
                total += member.file_size
            if total > 5 * 1024**3:
                raise ValueError("发行包解压后超过 5 GiB")
            package.extractall(destination)
    else:
        with tarfile.open(archive) as package:
            members = package.getmembers()
            if len(members) > 12000:
                raise ValueError("发行包文件过多")
            for member in members:
                _archive_path(member.name)
                total += member.size
            if total > 5 * 1024**3:
                raise ValueError("发行包解压后超过 5 GiB")
            # Python's data filter also rejects links escaping the extraction root.
            package.extractall(destination, filter="data")
    executable_name = "crispasr.exe" if os.name == "nt" else "crispasr"
    executables = [p for p in destination.rglob(executable_name) if p.is_file() and not p.is_symlink()]
    if len(executables) != 1:
        raise ValueError("发行包中未找到唯一的 CrispASR 程序")
    return executables[0]


def _runtime_file(path: Path) -> bool:
    name = path.name.lower()
    return not name.endswith(".gguf") and (
        name.startswith("crispasr") or name.endswith((".dll", ".dylib")) or ".so" in name)


def install_runtime(staged_executable: Path, target: Path, version: str) -> None:
    """Only replace files from the runtime package; model weights never move."""
    target.mkdir(parents=True, exist_ok=True)
    target = target.resolve()
    source = staged_executable.parent
    files = {p.relative_to(source): p for p in source.rglob("*")
             if p.is_file() and not p.name.lower().endswith(".gguf")}
    if not files or any(_MANIFEST == str(p) for p in files):
        raise ValueError("发行包文件无效")
    previous = set()
    manifest = target / _MANIFEST
    if manifest.is_file():
        previous = {_archive_path(name) for name in json.loads(manifest.read_text(encoding="utf-8"))["files"]}
    previous.update(p.relative_to(target) for p in target.iterdir() if p.is_file() and _runtime_file(p))
    previous.add(Path(_MANIFEST))
    affected = previous | set(files)
    for relative in affected:
        # Do not follow an existing directory/file link outside the chosen runtime.
        if not (target / relative).resolve().is_relative_to(target) or relative.suffix.lower() == ".gguf":
            raise ValueError("安装路径无效")
        if (target / relative).exists() and not (target / relative).is_file():
            raise ValueError("安装文件与现有目录冲突")
    moved: list[Path] = []
    written: list[Path] = []
    backup = Path(tempfile.mkdtemp(prefix=".crispasr-backup-", dir=target.parent))
    restored = False
    try:
        try:
            for relative in sorted(affected):
                old = target / relative
                if old.is_file() or old.is_symlink():
                    saved = backup / relative
                    saved.parent.mkdir(parents=True, exist_ok=True)
                    os.replace(old, saved)
                    moved.append(relative)
            for relative, original in files.items():
                dest = target / relative
                dest.parent.mkdir(parents=True, exist_ok=True)
                written.append(relative)
                shutil.copy2(original, dest)
            written.append(Path(_MANIFEST))
            manifest.write_text(json.dumps({"version": version, "files": [str(p).replace("\\", "/") for p in files]}), encoding="utf-8")
            _version.cache_clear()
            info = local_status(AppSettings(crispasr_dir=str(target)))
            if info["version"] != version or info["error"]:
                raise RuntimeError(f"安装验证失败：{info['error'] or info['version']}")
        except Exception as install_error:
            for relative in reversed(written):
                (target / relative).unlink(missing_ok=True)
            for relative in reversed(moved):
                os.replace(backup / relative, target / relative)
            _version.cache_clear()
            restored = True
            raise install_error
        restored = True
    finally:
        # Keep the old runtime available for recovery if rollback itself fails.
        if restored:
            shutil.rmtree(backup, ignore_errors=True)


class CrispAsrUpdater:
    def __init__(self, install_guard):
        self._lock = RLock()
        self._guard = install_guard
        self._cancel = Event()
        self._state = {"phase": "idle", "received": 0, "total": 0, "error": ""}
        self._release: dict | None = None
        self._release_time = 0.0
        self._release_proxy = ""

    def status(self) -> dict:
        with self._lock:
            return dict(self._state)

    def _set(self, **changes) -> None:
        with self._lock:
            self._state.update(changes)

    def releases(self, settings: AppSettings) -> dict:
        # Serialize metadata requests, not the lengthy download/install operation.
        with self._lock:
            if self._release is None or self._release_proxy != settings.proxy or time.monotonic() - self._release_time > 300:
                request = Request(LATEST_API, headers={"User-Agent": "Kikoeta-Transl", "Accept": "application/vnd.github+json"})
                with _opener(settings.proxy).open(request, timeout=20) as response:
                    data = response.read(4 * 1024**2 + 1)
                if len(data) > 4 * 1024**2:
                    raise ValueError("发行信息过大")
                release = json.loads(data)
                if not re.fullmatch(r"v?\d+\.\d+\.\d+", str(release.get("tag_name", ""))):
                    raise ValueError("发行版版本号无效")
                self._release = release
                self._release_proxy = settings.proxy
                self._release_time = time.monotonic()
            release = self._release
        env = environment()
        local = local_status(settings)
        latest = release["tag_name"].removeprefix("v")
        current = local["version"]
        return {"tag": release["tag_name"], "url": f"{REPOSITORY}/releases/tag/{release['tag_name']}",
                "local": local, "environment": env, "assets": compatible_assets(release, env),
                "newer": not current or tuple(map(int, latest.split("."))) > tuple(map(int, current.split(".")))}

    def start(self, settings: AppSettings, asset_id: int) -> dict:
        release_info = self.releases(settings)
        if not any(a["id"] == asset_id for a in release_info["assets"]):
            raise ValueError("请选择当前系统的官方发行包")
        with self._lock:
            if self._state["phase"] in _BUSY:
                raise RuntimeError("CrispASR 正在更新")
            asset = next(dict(a) for a in self._release["assets"] if a["id"] == asset_id)
            tag = release_info["tag"]
            expected_url = f"{REPOSITORY}/releases/download/{tag}/{asset['name']}"
            if asset.get("browser_download_url") != expected_url:
                raise ValueError("发行包下载地址无效")
            self._cancel.clear()
            self._state = {"phase": "downloading", "received": 0, "total": asset["size"],
                           "error": "", "asset": asset["name"], "version": tag}
            Thread(target=self._run, args=(settings, asset, tag.removeprefix("v")), daemon=True,
                   name="crispasr-update").start()
            return dict(self._state)

    def cancel(self) -> dict:
        with self._lock:
            if self._state["phase"] in {"downloading", "extracting"}:
                self._cancel.set()
            return dict(self._state)

    def _run(self, settings: AppSettings, asset: dict, version: str) -> None:
        try:
            with tempfile.TemporaryDirectory(prefix="kt-crispasr-", ignore_cleanup_errors=True) as temp_name:
                temp = Path(temp_name)
                archive = temp / "release.archive"
                digest = hashlib.sha256()
                received = 0
                request = Request(asset["browser_download_url"], headers={"User-Agent": "Kikoeta-Transl"})
                with _opener(settings.proxy).open(request, timeout=45) as response, archive.open("wb") as output:
                    while chunk := response.read(1024**2):
                        if self._cancel.is_set():
                            raise InterruptedError()
                        received += len(chunk)
                        if received > asset["size"] or received > 2 * 1024**3:
                            raise ValueError("发行包大小不符")
                        output.write(chunk)
                        digest.update(chunk)
                        self._set(received=received)
                if received != asset["size"]:
                    raise ValueError("发行包下载不完整")
                expected = asset.get("digest") or ""
                if expected and expected != f"sha256:{digest.hexdigest()}":
                    raise ValueError("发行包 SHA-256 校验失败")
                self._set(phase="extracting")
                executable = extract_package(archive, temp / "unpacked")
                if self._cancel.is_set():
                    raise InterruptedError()
                staged = local_status(AppSettings(crispasr_dir=str(executable.parent)))
                if staged["version"] != version or staged["error"]:
                    raise RuntimeError(f"此发行包无法运行：{staged['error'] or staged['version']}")
                with self._guard():
                    # Cancel and install form one state transition, so cancellation
                    # cannot race file replacement.
                    with self._lock:
                        if self._cancel.is_set():
                            raise InterruptedError()
                        self._state["phase"] = "installing"
                    install_runtime(executable, resolve_crispasr_dir(settings), version)
                    from .stages.asr import _SUPPORTED_OPTIONS
                    _SUPPORTED_OPTIONS.clear()
                self._set(phase="done")
        except InterruptedError:
            self._set(phase="cancelled")
        except Exception as exc:
            self._set(phase="error", error=str(exc))
