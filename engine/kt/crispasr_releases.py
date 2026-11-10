"""Official release selection and bounded, on-demand hardware discovery."""
from __future__ import annotations

import ctypes
import json
import os
import platform
import re
import subprocess
from functools import lru_cache

from .tools import popen_kwargs


def _output(args: list[str]) -> str:
    try:
        result = subprocess.run(args, capture_output=True, text=True, encoding="utf-8",
                                errors="replace", timeout=8, **popen_kwargs())
        return result.stdout if result.returncode == 0 else ""
    except (OSError, subprocess.SubprocessError):
        return ""


@lru_cache(maxsize=1)
def environment() -> dict:
    system = {"Windows": "windows", "Darwin": "macos", "Linux": "linux"}.get(platform.system(), "")
    machine = platform.machine().lower()
    arch = {"amd64": "x86_64", "x86_64": "x86_64", "aarch64": "arm64", "arm64": "arm64"}.get(machine, machine)
    # Python may run under emulation on Windows ARM. Report the native target.
    if os.environ.get("PROCESSOR_ARCHITEW6432", "").lower() == "arm64":
        arch = "arm64"
    flags: set[str] = set()
    gpus: list[str] = []
    if system == "windows":
        if ctypes.windll.kernel32.IsProcessorFeaturePresent(40):
            flags.add("avx2")
        if ctypes.windll.kernel32.IsProcessorFeaturePresent(41):
            flags.add("avx512f")
        raw = _output(["powershell.exe", "-NoProfile", "-NonInteractive", "-Command",
                       "[Console]::OutputEncoding=[Text.Encoding]::UTF8; "
                       "@(Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name }) | ConvertTo-Json -Compress"])
        try:
            names = json.loads(raw)
            gpus = [names] if isinstance(names, str) else list(names or [])
        except (ValueError, TypeError):
            pass
    elif system == "linux":
        from pathlib import Path
        try:
            flags = set(Path("/proc/cpuinfo").read_text().lower().split())
        except OSError:
            pass
        gpus = [line.split(": ", 1)[-1] for line in _output(["lspci"]).splitlines()
                if any(word in line.lower() for word in ("vga", "3d controller", "display controller"))]
    elif system == "macos":
        flags = set(_output(["sysctl", "-n", "machdep.cpu.features", "machdep.cpu.leaf7_features"]).lower().split())
        gpus = [line.split(":", 1)[1].strip() for line in _output(["system_profiler", "SPDisplaysDataType"]).splitlines()
                if "Chipset Model:" in line]
    nvidia = _output(["nvidia-smi", "--query-gpu=name,compute_cap", "--format=csv,noheader,nounits"])
    capabilities = []
    for line in nvidia.splitlines():
        parts = line.rsplit(",", 1)
        if len(parts) == 2:
            gpus.append(parts[0].strip())
            try:
                capabilities.append(float(parts[1]))
            except ValueError:
                pass
    has_nvidia = any("nvidia" in str(gpu).lower() for gpu in gpus)
    cuda = re.search(r"CUDA(?: UMD)? Version:\s*(\d+\.\d+)", _output(["nvidia-smi"])) if has_nvidia else None
    rocm = _output(["hipconfig", "--version"]) if system == "linux" else ""
    return {"system": system, "arch": arch, "gpus": list(dict.fromkeys(gpus)), "has_nvidia": has_nvidia,
            "avx2": "avx2" in flags or "avx2.0" in flags,
            "avx512": "avx512f" in flags,
            "cuda": float(cuda[1]) if cuda else 0,
            "compute_cap": max(capabilities, default=0),
            "rocm7": bool(re.search(r"\b7\.\d", rocm)), "rocm": bool(rocm)}


def compatible_assets(release: dict, env: dict) -> list[dict]:
    """List complete CLI packages; SDKs and split runtime-only packages cannot run alone."""
    system, arch = env["system"], env["arch"]
    prefix = f"crispasr-{system}-{arch}"
    options = []
    for asset in release.get("assets", []):
        name = str(asset.get("name", ""))
        if not name.startswith(prefix) or not name.endswith((".zip", ".tar.gz")) or "-non-cuda" in name:
            continue
        flavor = name[len(prefix):].removesuffix(".tar.gz").removesuffix(".zip").lstrip("-") or "cpu"
        if flavor not in {"cpu", "cpu-legacy", "avx512", "cuda", "cuda126", "cuda13", "vulkan", "hip", "hip7"}:
            continue
        score, reason = _rank(flavor, env)
        options.append({"id": asset["id"], "name": name, "size": asset.get("size", 0),
                        "flavor": "metal" if system == "macos" and arch == "arm64" and flavor == "cpu" else flavor,
                        "score": score, "reason": reason})
    options.sort(key=lambda item: (-item["score"], item["name"]))
    for index, item in enumerate(options):
        item["recommended"] = index == 0
    return options


def _rank(flavor: str, env: dict) -> tuple[int, str]:
    cuda, cc = env.get("cuda", 0), env.get("compute_cap", 0)
    gpu_text = " ".join(env.get("gpus", [])).lower()
    if flavor == "cuda13":
        return (110, "nvidia13") if cuda >= 13 and cc >= 7.5 else (0, "cuda13Requirements")
    if flavor == "cuda":
        return (100, "nvidia12") if cuda >= 12.8 and cc >= 6 else (0, "cuda12Requirements")
    if flavor == "cuda126":
        return (90, "nvidia126") if cuda >= 12.6 and 6 <= cc < 12 else (0, "cuda126Requirements")
    if flavor in {"hip", "hip7"}:
        compatible = env.get("rocm") and (flavor == "hip7") == env.get("rocm7")
        return (105, "amdRocm") if compatible else (0, "rocmRequirements")
    if flavor == "vulkan":
        return (70, "gpuVulkan") if gpu_text and any(x in gpu_text for x in ("nvidia", "amd", "radeon", "intel", "arc")) else (5, "vulkanRequirements")
    if flavor == "avx512":
        return (60, "cpuAvx512") if env.get("avx512") else (0, "avx512Requirements")
    if flavor == "cpu-legacy":
        return (20, "cpuLegacy") if not env.get("avx2") else (10, "cpuLegacy")
    if env["system"] == "macos" and env["arch"] == "arm64":
        return 120, "appleMetal"
    if env["arch"] == "arm64" or env.get("avx2"):
        return 50, "cpuDetected"
    return 0, "avx2Requirements"
