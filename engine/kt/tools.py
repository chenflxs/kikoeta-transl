from __future__ import annotations

import json
import os
import shutil
import struct
import subprocess
from pathlib import Path

from .models import AppSettings
from .paths import BIN_DIR, CREATE_NO_WINDOW, GALTRANSL_ROOT


FALLBACK_ASR_BACKENDS = [
    "whisper",
    "parakeet",
    "canary",
    "cohere",
    "qwen3",
    "qwen3-1.7b",
    "mega-asr",
    "voxtral",
    "voxtral4b",
    "granite",
]

SOURCE_LANGS = [
    {"id": "ja", "label": "ja · 日本語"},
    {"id": "en", "label": "en · English"},
    {"id": "zh", "label": "zh · 中文"},
    {"id": "ko", "label": "ko · 한국어"},
    {"id": "ru", "label": "ru · русский"},
    {"id": "fr", "label": "fr · Français"},
    {"id": "auto", "label": "auto · 自动检测"},
]

TARGET_LANGS = [
    {"id": "zh-cn", "label": "zh-cn · 简体中文"},
    {"id": "zh-tw", "label": "zh-tw · 繁體中文"},
    {"id": "en", "label": "en · English"},
    {"id": "ja", "label": "ja · 日本語"},
    {"id": "ko", "label": "ko · 한국어"},
    {"id": "ru", "label": "ru · русский"},
    {"id": "fr", "label": "fr · Français"},
]

TRANSLATORS = [
    {"id": "ForGal-json", "label": "ForGal-json · Gal JSON"},
    {"id": "ForNovel", "label": "ForNovel · 小说 / 其他文本"},
    {"id": "ForGal-tsv", "label": "ForGal-tsv · Gal TSV"},
    {"id": "galtransl-v3", "label": "galtransl-v3 · Sakura 接口"},
    {"id": "sakura-v1.0", "label": "sakura-v1.0 · Sakura 接口"},
]


def resolve_ffmpeg(settings: AppSettings) -> tuple[str, str]:
    tool_roots = [BIN_DIR / "ffmpeg", BIN_DIR]
    ffmpeg = _first_runnable(*_tool_candidates("ffmpeg", settings.ffmpeg_path, extra_roots=tool_roots))
    probe_name = "ffprobe.exe" if os.name == "nt" else "ffprobe"
    beside = str(Path(ffmpeg).with_name(probe_name)) if ffmpeg else ""
    ffprobe = _first_runnable(
        settings.ffprobe_path,
        beside,
        *_tool_candidates("ffprobe", "", extra_roots=[BIN_DIR / "ffmpeg", BIN_DIR]),
    )
    if not ffmpeg:
        raise FileNotFoundError("未找到可运行的 ffmpeg。请将有效的 ffmpeg.exe 放到 bin/ffmpeg 或 bin/ffmpeg/bin，或在设置中指定路径。")
    if not ffprobe:
        raise FileNotFoundError("未找到可运行的 ffprobe。请将有效的 ffprobe.exe 与 ffmpeg 放在同一目录。")
    return ffmpeg, ffprobe


def resolve_crispasr_dir(settings: AppSettings) -> Path:
    if settings.crispasr_dir:
        return Path(settings.crispasr_dir)
    return BIN_DIR / "crispasr"


def list_crispasr_models(settings: AppSettings) -> dict[str, object]:
    folder = resolve_crispasr_dir(settings)
    exe_name = "crispasr.exe" if os.name == "nt" else "crispasr"
    if not folder.is_dir():
        return {
            "dir": str(folder),
            "models": [],
            "aligners": [],
            "executable": "",
            "backends": list(FALLBACK_ASR_BACKENDS),
        }
    names = [path.name for path in folder.glob("*.gguf")]
    models = sorted(name for name in names if "aligner" not in name.lower() and "alignment" not in name.lower())
    aligners = sorted(name for name in names if "aligner" in name.lower() or "alignment" in name.lower())
    exe = folder / exe_name
    return {
        "dir": str(folder.resolve()),
        "models": models,
        "aligners": aligners,
        "executable": str(exe.resolve()) if exe.is_file() else "",
        "backends": list(FALLBACK_ASR_BACKENDS),
    }


def list_crispasr_backends(settings: AppSettings | None = None) -> list[str]:
    folder = resolve_crispasr_dir(settings or AppSettings())
    executable = folder / ("crispasr.exe" if os.name == "nt" else "crispasr")
    if not executable.is_file():
        return list(FALLBACK_ASR_BACKENDS)
    try:
        result = subprocess.run(
            [str(executable), "--list-backends-json"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=10,
            **popen_kwargs(),
        )
        payload = json.loads(result.stdout or "{}")
        non_asr_caps = {"tts", "s2s", "pitch", "chords", "beats", "tab", "piano"}
        asr_caps = {
            "timestamps-native",
            "timestamps-ctc",
            "word-timestamps",
            "token-confidence",
            "language-detect",
            "diarize",
        }
        backends: list[str] = []
        for entry in payload.get("backends", []):
            name = str(entry.get("name", "")).strip()
            caps = set(entry.get("caps") or [])
            if name and caps.intersection(asr_caps) and not (
                caps.intersection(non_asr_caps) and not caps.intersection({"timestamps-ctc", "word-timestamps"})
            ):
                backends.append(name)
        if backends:
            return list(dict.fromkeys(backends))
    except (OSError, subprocess.SubprocessError, ValueError, TypeError, json.JSONDecodeError):
        pass
    return list(FALLBACK_ASR_BACKENDS)


def list_gt_dicts() -> list[dict[str, object]]:
    folder = GALTRANSL_ROOT / "Dict"
    if not folder.is_dir():
        return []
    items: list[dict[str, object]] = []
    for path in sorted(folder.iterdir(), key=lambda item: item.name):
        if not path.is_file() or path.suffix.lower() != ".txt":
            continue
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except OSError:
            lines = []
        count = len(
            [
                line
                for line in lines
                if line.strip() and not line.startswith("\\\\") and not line.startswith("//")
            ]
        )
        items.append(
            {
                "name": path.name,
                "path": str(path),
                "category": _dict_category(path.name),
                "count": count,
            }
        )
    return items


def list_openai_models(base_url: str, api_key: str = "", proxy: str = "") -> list[str]:
    url = openai_models_url(base_url)
    headers = {}
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"
    kwargs: dict = {"timeout": 15, "headers": headers}
    if proxy:
        kwargs["proxies"] = {"http": proxy, "https": proxy}
    try:
        import requests
        response = requests.get(url, **kwargs)
        response.raise_for_status()
        payload = response.json()
    except Exception as exc:
        raise RuntimeError(f"查询模型列表失败: {exc}") from exc
    models: list[str] = []
    if isinstance(payload, dict):
        data = payload.get("data") or payload.get("models") or []
    else:
        data = payload
    if not isinstance(data, list):
        raise RuntimeError("模型列表响应无法解析")
    for item in data:
        if isinstance(item, str) and item.strip():
            models.append(item.strip())
        elif isinstance(item, dict):
            name = str(item.get("id") or item.get("name") or "").strip()
            if name:
                models.append(name)
    models = list(dict.fromkeys(models))
    if not models:
        raise RuntimeError("响应未包含可用模型")
    return models


def openai_models_url(base_url: str) -> str:
    text = (base_url or "").strip().rstrip("/")
    if not text:
        raise ValueError("未填写 API 地址")
    if text.endswith("/models"):
        return text
    if text.endswith("/v1"):
        return text + "/models"
    return text + "/v1/models"


def catalog() -> dict:
    folder = GALTRANSL_ROOT / "Dict"
    return {
        "source_langs": SOURCE_LANGS,
        "target_langs": TARGET_LANGS,
        "translators": TRANSLATORS,
        "dict_dir": str(folder),
        "gt_dicts": list_gt_dicts(),
    }


def popen_kwargs() -> dict:
    kwargs: dict = {}
    if os.name == "nt":
        kwargs["creationflags"] = CREATE_NO_WINDOW
    return kwargs


def _dict_category(name: str) -> str:
    lower = name.lower()
    if "gpt" in lower:
        return "gpt"
    if "译后" in name or "post" in lower:
        return "post"
    return "pre"


def _tool_candidates(name: str, configured: str = "", extra_roots: list[Path] | None = None) -> list[object]:
    exe = f"{name}.exe" if os.name == "nt" else name
    items: list[object] = []
    if configured:
        items.append(configured)
        configured_path = Path(configured)
        if configured_path.is_dir():
            items.append(configured_path / exe)
            items.append(configured_path / "bin" / exe)
    for root in extra_roots or []:
        items.append(root / exe)
        items.append(root / "bin" / exe)
        items.append(root / name / exe)
        items.append(root / name / "bin" / exe)
    which = shutil.which(name)
    if which:
        items.append(which)
    extras = [
        Path(r"C:\ffmpeg\bin") / exe,
        Path(os.environ.get("ProgramFiles", r"C:\Program Files")) / "ffmpeg" / "bin" / exe,
        Path(os.environ.get("LOCALAPPDATA", "")) / "Microsoft" / "WinGet" / "Links" / exe,
    ]
    items.extend(extras)
    return items


def _first_existing(*candidates: object) -> str:
    seen: set[str] = set()
    for item in candidates:
        if not item:
            continue
        path = Path(str(item))
        key = str(path).lower()
        if key in seen:
            continue
        seen.add(key)
        if path.is_file():
            return str(path.resolve())
    return ""


def _first_runnable(*candidates: object) -> str:
    """Return the first executable that Windows can actually start.

    A damaged or truncated PE file can still pass ``Path.is_file()`` and even
    have an ``MZ`` header. Probe the tools before selecting them so a broken
    bundled copy does not mask a valid system installation.
    """
    seen: set[str] = set()
    for item in candidates:
        if not item:
            continue
        path = Path(str(item))
        key = str(path).lower()
        if key in seen:
            continue
        seen.add(key)
        if not path.is_file() or not _is_valid_executable(path):
            continue
        try:
            result = subprocess.run(
                [str(path), "-version"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=5,
                **popen_kwargs(),
            )
        except (OSError, subprocess.SubprocessError):
            continue
        if result.returncode == 0:
            return str(path.resolve())
    return ""


def _is_valid_executable(path: Path) -> bool:
    """Reject truncated Windows PE files before trying to launch them."""
    if os.name != "nt":
        return True
    try:
        file_size = path.stat().st_size
        with path.open("rb") as file:
            if file.read(2) != b"MZ":
                return False
            file.seek(0x3C)
            raw = file.read(4)
            if len(raw) != 4:
                return False
            pe_offset = struct.unpack("<I", raw)[0]
            if pe_offset + 24 > file_size:
                return False
            file.seek(pe_offset)
            header = file.read(24)
            if len(header) != 24 or header[:4] != b"PE\0\0":
                return False
            section_count = struct.unpack_from("<H", header, 6)[0]
            optional_size = struct.unpack_from("<H", header, 20)[0]
            section_table = pe_offset + 24 + optional_size
            if section_table + section_count * 40 > file_size:
                return False
            file.seek(section_table)
            for _ in range(section_count):
                section = file.read(40)
                if len(section) != 40:
                    return False
                raw_size = struct.unpack_from("<I", section, 16)[0]
                raw_offset = struct.unpack_from("<I", section, 20)[0]
                if raw_offset + raw_size > file_size:
                    return False
    except (OSError, struct.error):
        return False
    return True
