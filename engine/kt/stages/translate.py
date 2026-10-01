from __future__ import annotations

import asyncio
import json
import logging
import os
import re
import sys
from contextlib import contextmanager
from dataclasses import replace
from pathlib import Path
from threading import Event

from ..cancellation import TaskCancelled, raise_if_cancelled
from ..events import EmitFn
from ..models import AppSettings, Cue, cues_to_gt_json
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
    stop_event: Event | None = None,
) -> list[Cue]:
    raise_if_cancelled(stop_event)
    if settings.translate.provider == "local_llama":
        from ..llama_runtime import local_llama_session

        if emit:
            emit("log", message="正在准备本地 Llama 模型")
        with local_llama_session(settings, stop_event) as (endpoint, openai_base, model_id):
            local_translate = replace(
                settings.translate,
                sakura_endpoint=endpoint,
                sakura_model=model_id,
                openai=replace(
                    settings.translate.openai,
                    base_url=openai_base,
                    model=model_id,
                    api_key="",
                ),
            )
            local_settings = replace(settings, proxy="", translate=local_translate)
            if emit:
                emit("log", message=f"本地 Llama 已就绪：{settings.llama_model}")
            return _translate_and_repair(
                cues,
                workspace,
                local_settings,
                emit=emit,
                stop_event=stop_event,
            )
    return _translate_and_repair(
        cues,
        workspace,
        settings,
        emit=emit,
        stop_event=stop_event,
    )


def _translate_and_repair(
    cues: list[Cue],
    workspace: Path,
    settings: AppSettings,
    emit: EmitFn | None = None,
    stop_event: Event | None = None,
) -> list[Cue]:
    translated = _translate_cues(
        cues, workspace, settings, emit=emit, stop_event=stop_event
    )
    suspicious = [
        index
        for index, (source, result) in enumerate(zip(cues, translated))
        if _looks_untranslated(source, result, settings)
    ]
    if not suspicious:
        return translated

    raise_if_cancelled(stop_event)
    if emit:
        emit(
            "log",
            message=f"检测到 {len(suspicious)} 条字幕可能漏译，正在单独补译",
        )

    # Use an isolated project directory so GalTransl cannot reuse a cached
    # untranslated result from the first pass.
    retry_cues = [cues[index] for index in suspicious]
    try:
        retried = _translate_cues(
            retry_cues,
            workspace / "translation_retry",
            settings,
            emit=emit,
            stop_event=stop_event,
        )
    except Exception as exc:
        raise_if_cancelled(stop_event)
        if emit:
            emit("log", message=f"补译请求失败，保留首轮结果：{exc}")
        return translated
    repaired = 0
    for index, retry in zip(suspicious, retried):
        if not _looks_untranslated(cues[index], retry, settings):
            translated[index].message = retry.message
            repaired += 1

    still_missing = len(suspicious) - repaired
    if emit:
        if still_missing:
            emit(
                "log",
                message=(
                    f"补译完成：修复 {repaired} 条，仍有 {still_missing} 条未能确认译出；"
                    "已保留原文以避免字幕丢失"
                ),
            )
        else:
            emit("log", message=f"补译完成：修复 {repaired} 条疑似漏译字幕")
    return translated


def _translate_cues(
    cues: list[Cue],
    workspace: Path,
    settings: AppSettings,
    emit: EmitFn | None = None,
    stop_event: Event | None = None,
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

    if (
        (stop_event is not None and stop_event.is_set())
        or getattr(state, "status", "") == "cancelled"
    ):
        raise TaskCancelled()
    if not getattr(state, "success", False):
        raise RuntimeError(getattr(state, "error", None) or "GalTransl 翻译失败")
    output_path = workspace / "gt_output" / "cues.json"
    if not output_path.is_file():
        raise RuntimeError("GalTransl 未生成 gt_output/cues.json")
    items = json.loads(output_path.read_text(encoding="utf-8"))
    if not isinstance(items, list):
        raise RuntimeError("GalTransl 输出格式错误：字幕结果不是列表")
    return _merge_translation_items(items, cues)


def _merge_translation_items(items: list[dict], cues: list[Cue]) -> list[Cue]:
    """Keep the original cue count/order even when a backend omits rows."""
    out: list[Cue | None] = [None] * len(cues)
    used: set[int] = set()
    for item in items:
        if not isinstance(item, dict):
            continue
        match = None
        original_text = str(
            item.get("src_message")
            or item.get("org_message")
            or item.get("src_msg")
            or ""
        )
        if original_text:
            match = next(
                (
                    index
                    for index, cue in enumerate(cues)
                    if index not in used
                    and (cue.src_message or cue.message) == original_text
                ),
                None,
            )
        if "start" in item:
            try:
                start = float(item["start"])
                end = float(item.get("end", start))
                if match is None:
                    match = next(
                        (
                            index
                            for index, cue in enumerate(cues)
                            if index not in used
                            and abs(cue.start - start) < 0.01
                            and abs(cue.end - end) < 0.01
                        ),
                        None,
                    )
            except (TypeError, ValueError):
                pass
        if match is None:
            match = next((index for index in range(len(cues)) if index not in used), None)
        if match is None:
            break
        used.add(match)
        translated = Cue.from_mapping(item)
        source = cues[match]
        if translated.start == 0 and translated.end == 0:
            translated.start, translated.end = source.start, source.end
        translated.src_message = source.src_message or source.message
        out[match] = translated

    return [
        cue if cue is not None else Cue(
            start=source.start,
            end=source.end,
            message=source.message,
            src_message=source.src_message or source.message,
        )
        for source, cue in zip(cues, out)
    ]


_KANA_RE = re.compile(r"[\u3040-\u30ff\u31f0-\u31ff]")
_CONTENT_RE = re.compile(r"(?:[^\W\d_]|[\u3400-\u9fff])", re.UNICODE)


def _looks_untranslated(source: Cue, result: Cue, settings: AppSettings) -> bool:
    original = source.src_message or source.message
    translated = result.message
    if not translated.strip():
        return True

    source_lang = _language_code(settings.source_lang)
    target_lang = _language_code(settings.target_lang)
    if source_lang == target_lang:
        return False

    normalize = lambda value: " ".join(value.split()).casefold()
    if normalize(original) == normalize(translated):
        return bool(_CONTENT_RE.search(original))

    # Kana is distinctive to Japanese, while Chinese translations may share
    # kanji. Catch Japanese fragments that survived inside a Chinese result.
    if source_lang == "ja" and target_lang in {"zh", "zh-cn", "zh-tw"}:
        source_kana = len(_KANA_RE.findall(original))
        translated_kana = len(_KANA_RE.findall(translated))
        return source_kana > 0 and translated_kana >= max(2, source_kana // 3)
    return False


def _language_code(value: str) -> str:
    language = (value or "").strip().lower().replace("_", "-")
    if language.startswith("zh-"):
        return "zh"
    if language.startswith("ja-"):
        return "ja"
    return language


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
