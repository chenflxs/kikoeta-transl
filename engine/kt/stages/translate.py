from __future__ import annotations

import asyncio
import json
import logging
import os
import sys
from contextlib import contextmanager
from pathlib import Path

from ..events import EmitFn
from ..models import AppSettings, Cue, cues_from_gt_json, cues_to_gt_json
from ..paths import GALTRANSL_ROOT


def ensure_galtransl_path() -> None:
    root = str(GALTRANSL_ROOT)
    if root not in sys.path:
        sys.path.insert(0, root)


@contextmanager
def galtransl_cwd():
    previous = os.getcwd()
    os.chdir(GALTRANSL_ROOT)
    try:
        yield
    finally:
        os.chdir(previous)


def translate_cues(
    cues: list[Cue],
    workspace: Path,
    settings: AppSettings,
    emit: EmitFn | None = None,
    stop_event=None,
) -> list[Cue]:
    ensure_galtransl_path()
    # GalTransl temporarily changes cwd to its own package directory. Resolve
    # here so its project/config paths remain valid for callers that pass a
    # relative workspace (the CLI and HTTP job paths are usually absolute).
    workspace = workspace.resolve()
    workspace.mkdir(parents=True, exist_ok=True)
    for name in ("gt_input", "gt_output", "transl_cache"):
        (workspace / name).mkdir(parents=True, exist_ok=True)
    input_path = workspace / "gt_input" / "cues.json"
    input_path.write_text(json.dumps(cues_to_gt_json(cues), ensure_ascii=False, indent=2), encoding="utf-8")
    _write_dicts(workspace, settings)
    _write_config(workspace, settings)

    handler = None
    if emit:
        handler = _EmitHandler(emit)
        logging.getLogger("GalTransl").addHandler(handler)
    try:
        with galtransl_cwd():
            state = asyncio.run(_run_job(workspace, settings, stop_event))
    finally:
        if handler:
            logging.getLogger("GalTransl").removeHandler(handler)

    if not getattr(state, "success", False):
        raise RuntimeError(getattr(state, "error", None) or "GalTransl 翻译失败")
    output_path = workspace / "gt_output" / "cues.json"
    if not output_path.is_file():
        raise RuntimeError("GalTransl 未生成 gt_output/cues.json")
    items = json.loads(output_path.read_text(encoding="utf-8"))
    translated = cues_from_gt_json(items, cues)
    for src, dst in zip(cues, translated):
        if not dst.src_message:
            dst.src_message = src.message
    return translated


async def _run_job(workspace: Path, settings: AppSettings, stop_event):
    from GalTransl.Service import JobSpec, run_job_async

    spec = JobSpec(
        project_dir=str(workspace),
        translator=settings.translate.translator or "ForGal-json",
        config_file_name="config.yaml",
    )
    return await run_job_async(spec, stop_event=stop_event)


def _write_dicts(workspace: Path, settings: AppSettings) -> None:
    mapping = {
        "项目字典_译前.txt": settings.dict_pre,
        "项目GPT字典.txt": settings.dict_gpt,
        "项目字典_译后.txt": settings.dict_after,
    }
    for name, content in mapping.items():
        path = workspace / name
        if content.strip():
            path.write_text(content.replace(" ", "\t"), encoding="utf-8")
        elif path.exists():
            path.unlink()


def _write_config(workspace: Path, settings: AppSettings) -> None:
    import yaml
    from GalTransl.DefaultProjectConfig import DEFAULT_PROJECT_CONFIG_YAML

    cfg = yaml.safe_load(DEFAULT_PROJECT_CONFIG_YAML) or {}
    common = cfg.setdefault("common", {})
    source = settings.source_lang or "ja"
    if source == "zh":
        source = "zh-cn"
    target = settings.target_lang or "zh-cn"
    common["language"] = f"{source}2{target}"
    common["workersPerProject"] = 1
    common["gpt.contextNum"] = max(0, settings.translate.context_num)
    common["gpt.numPerRequestTranslate"] = max(1, settings.translate.batch_size)
    common["gpt.token_limit"] = max(0, settings.translate.token_limit)
    common["gpt.change_prompt"] = (
        "OverwritePrompt" if settings.translate.prompt_mode == "overwrite" else "AppendPrompt"
    ) if settings.translate.prompt.strip() else "no"
    common["gpt.prompt_content"] = settings.translate.prompt
    common["saveLog"] = True
    plugin = cfg.setdefault("plugin", {})
    plugin["filePlugin"] = "file_galtransl_json"
    backend = cfg.setdefault("backendSpecific", {})
    translator = settings.translate.translator or "ForGal-json"
    if "sakura" in translator or "galtransl" in translator:
        sakura = backend.setdefault("SakuraLLM", {})
        sakura["endpoints"] = [settings.translate.sakura_endpoint or "http://127.0.0.1:8080"]
        sakura["rewriteModelName"] = settings.translate.sakura_model
    else:
        openai_cfg = backend.setdefault("OpenAI-Compatible", {})
        endpoint = (settings.translate.openai.base_url or "https://api.openai.com").rstrip("/")
        if endpoint.endswith("/v1"):
            endpoint = endpoint[:-3]
        openai_cfg["tokens"] = [
            {
                "token": settings.translate.openai.api_key or "sk-placeholder",
                "endpoint": endpoint,
                "modelName": settings.translate.openai.model,
            }
        ]
        openai_cfg["checkAvailable"] = bool(settings.translate.openai.api_key)
        if settings.translate.enable_thinking is None:
            openai_cfg.pop("extra_body", None)
        else:
            openai_cfg["extra_body"] = {
                "thinking": {
                    "type": "enabled"
                    if settings.translate.enable_thinking
                    else "disabled"
                }
            }
    proxy = cfg.setdefault("proxy", {})
    proxy["enableProxy"] = bool(settings.proxy)
    proxy["proxies"] = [{"address": settings.proxy}] if settings.proxy else []
    _keep_gt_dicts(cfg, workspace)
    (workspace / "config.yaml").write_text(
        yaml.dump(cfg, allow_unicode=True, sort_keys=False),
        encoding="utf-8",
    )


def _keep_gt_dicts(cfg: dict, workspace: Path) -> None:
    dict_cfg = cfg.setdefault("dictionary", {})
    dict_cfg["defaultDictFolder"] = "Dict"
    for key in ("preDict", "gpt.dict", "postDict"):
        kept = []
        for item in dict_cfg.get(key) or []:
            name = str(item)
            if name.startswith("(project_dir)"):
                extra = workspace / name[len("(project_dir)"):]
                if extra.is_file() and extra.stat().st_size > 0:
                    kept.append(name)
            else:
                kept.append(name)
        dict_cfg[key] = kept


class _EmitHandler(logging.Handler):
    def __init__(self, emit: EmitFn):
        super().__init__()
        self._emit = emit

    def emit(self, record: logging.LogRecord) -> None:
        try:
            self._emit("log", message=record.getMessage())
        except Exception:
            pass
