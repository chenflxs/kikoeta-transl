from __future__ import annotations

from dataclasses import replace
from pathlib import Path
from threading import Event

from .cleanup import cleanup_intermediates
from .events import EmitFn
from .models import AppSettings, Cue, FileKind, FileResult, StageFlags
from .paths import MEDIA_EXTS, SUBTITLE_EXTS
from .stages.export import export_cues
from .subtitle import parse_subtitle


class PipelineError(RuntimeError):
    pass


def detect_kind(path: str | Path) -> FileKind:
    suffix = Path(path).suffix.lower()
    if suffix in SUBTITLE_EXTS:
        return "subtitle"
    if suffix in MEDIA_EXTS:
        return "media"
    raise PipelineError(f"不支持的文件类型: {path}")


def process_file(
    path: str,
    settings: AppSettings,
    flags: StageFlags,
    job_dir: Path,
    emit: EmitFn,
    stop_event: Event | None = None,
) -> FileResult:
    kind = detect_kind(path)
    result = FileResult(path=path, kind=kind)
    wav = None
    workspace = job_dir / "gt"
    try:
        _raise_if_stopped(stop_event)
        if kind == "subtitle":
            emit("status", file=path, stage="parse", message="解析字幕")
            cues = parse_subtitle(path)
            if not cues:
                raise PipelineError("字幕文件没有可用条目")
        else:
            emit("status", file=path, stage="transcoding", message="ffmpeg 转码")
            result.stage = "transcoding"
            from .stages.transcode import transcode_to_wav
            wav = transcode_to_wav(path, job_dir, settings)
            emit("status", file=path, stage="asr", message="ASR 听写")
            result.stage = "asr"
            from .stages.asr import transcribe_wav
            cues = transcribe_wav(wav, job_dir, settings, emit=emit, file=path)
            if not cues:
                raise PipelineError("ASR 没有产出字幕")

        src_cues = [
            Cue(start=item.start, end=item.end, message=item.message, src_message=item.message)
            for item in cues
        ]
        for item in cues:
            item.src_message = item.message

        if flags.enable_correct:
            _raise_if_stopped(stop_event)
            emit("status", file=path, stage="correcting", message="小模型矫正")
            result.stage = "correcting"
            from .stages.correct import correct_cues
            cues = correct_cues(cues, settings, emit=emit, file=path)
            src_cues = [
                Cue(start=item.start, end=item.end,
                    message=item.src_message or item.message,
                    src_message=item.src_message or item.message)
                for item in cues
            ]

        if flags.enable_translate:
            _raise_if_stopped(stop_event)
            emit("status", file=path, stage="translating", message="翻译")
            result.stage = "translating"
            from .stages.translate import translate_cues
            cues = translate_cues(cues, workspace, settings, emit=emit)

        emit("status", file=path, stage="exporting", message="导出字幕")
        result.stage = "exporting"
        export_settings = settings
        if not settings.output.suffix:
            if flags.enable_translate:
                suffix = _language_suffix(settings.target_lang)
            elif flags.enable_correct:
                suffix = ".fix"
            else:
                suffix = ""
            export_settings = replace(
                settings,
                output=replace(settings.output, suffix=suffix),
            )
        outputs = export_cues(cues, path, export_settings, src_cues=src_cues)
        result.outputs = outputs
        result.status = "done"
        result.stage = "done"
        result.message = f"完成，产出 {len(outputs)} 个文件"
        emit("file_done", file=path, outputs=outputs)
        return result
    except StopRequested:
        result.status = "cancelled"
        result.stage = "cancelled"
        result.error = "已取消"
        emit("file_error", file=path, error="已取消")
        return result
    except Exception as exc:
        result.status = "failed"
        result.error = str(exc)
        result.message = str(exc)
        emit("file_error", file=path, error=str(exc))
        return result
    finally:
        if not settings.output.keep_gt_cache:
            cleanup_intermediates(workspace)
        cleanup_intermediates(wav or "")


def _raise_if_stopped(stop_event: Event | None) -> None:
    if stop_event is not None and stop_event.is_set():
        raise StopRequested()



class StopRequested(Exception):
    pass


def _language_suffix(language: str) -> str:
    value = str(language or "").strip().lower().replace("_", "-")
    if value in {"zh", "zh-cn", "zh-hans", "zh-hans-cn"}:
        return ".zh"
    if value in {"zh-tw", "zh-hant", "zh-hant-tw"}:
        return ".zh-tw"
    return "." + (value or "target")
