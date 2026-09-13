from __future__ import annotations

import os
import queue
import re
import shlex
import shutil
import subprocess
import tempfile
import time
from threading import Event, Thread
from pathlib import Path

from ..events import EmitFn
from ..cancellation import TaskCancelled, raise_if_cancelled, terminate_process
from ..models import AppSettings, Cue
from ..subtitle import parse_subtitle
from ..tools import list_crispasr_models, popen_kwargs, resolve_crispasr_dir


_SUPPORTED_OPTIONS: dict[str, frozenset[str]] = {}


DEFAULT_ASR_TEMPLATE = (
    "$crispasr_executable --backend $backend --model $model_file "
    "--aligner-model $aligner_file --force-aligner --language $language "
    "--output-srt --output-file $output_file --file $input_file --vad "
    "--vad-model firered --vad-threshold 0.5 --vad-max-speech-duration-s 6 "
    "--vad-min-silence-duration-ms 300 --max-new-tokens 224 "
    "--frequency-penalty 0.0 "
    "--temperature 0.0 --split-on-punct"
)


def transcribe_wav(
    wav_path: str | Path,
    work_dir: Path,
    settings: AppSettings,
    *,
    emit: EmitFn | None = None,
    file: str | None = None,
    stop_event: Event | None = None,
) -> list[Cue]:
    raise_if_cancelled(stop_event)
    info = list_crispasr_models(settings)
    executable = info["executable"]
    if not executable:
        raise FileNotFoundError("未找到 CrispASR 可执行文件，请放到 bin/crispasr")
    model = settings.asr.model or (info["models"][0] if info["models"] else "")
    aligner = settings.asr.aligner or (info["aligners"][0] if info["aligners"] else "")
    if not model:
        raise FileNotFoundError("未找到 ASR 模型（.gguf）")
    if settings.asr.force_aligner and not aligner:
        raise FileNotFoundError("未找到 ASR aligner 模型（.gguf）")

    folder = resolve_crispasr_dir(settings)
    model_path = _resolve_under(folder, model)
    aligner_path = (
        _resolve_under(folder, aligner)
        if settings.asr.force_aligner and aligner
        else None
    )

    # CrispASR's Windows path handling is not reliable for non-ASCII parent
    # directories. Keep its staged input/output in the system temp directory.
    job_dir = Path(tempfile.mkdtemp(prefix="kt_asr_"))
    try:
        staged = job_dir / f"input{Path(wav_path).suffix.lower()}"
        output_base = job_dir / "transcript"
        generated = output_base.with_suffix(".srt")
        shutil.copyfile(wav_path, staged)
        raise_if_cancelled(stop_event)
        command = build_asr_command(
            executable=executable,
            model_path=model_path,
            aligner_path=aligner_path,
            input_file=staged,
            output_file=output_base,
            settings=settings,
        )
        _validate_options(executable, command)
        raise_if_cancelled(stop_event)
        _emit_log(emit, file, "CrispASR 已启动，正在加载模型并准备听写")
        result = _run_with_heartbeat(
            command,
            emit=emit,
            file=file,
            stop_event=stop_event,
        )
        _emit_log(emit, file, "CrispASR 推理完成，正在读取听写结果")
        if not generated.is_file() or generated.stat().st_size == 0:
            detail = (result.stderr or result.stdout or "").strip()
            raise RuntimeError(f"CrispASR 失败: {detail or result.returncode}")
        cues = parse_subtitle(generated)
        if not cues:
            detail = (result.stderr or result.stdout or "").strip()
            raise RuntimeError(f"CrispASR 未生成有效字幕: {detail or result.returncode}")
        if result.returncode != 0:
            _emit_log(
                emit,
                file,
                f"CrispASR 返回码为 {result.returncode}，但已生成 {len(cues)} 条有效字幕，继续导出",
            )
        return cues
    finally:
        shutil.rmtree(job_dir, ignore_errors=True)


def _run_with_heartbeat(
    command: list[str],
    *,
    emit: EmitFn | None,
    file: str | None,
    stop_event: Event | None = None,
    idle_notice_after: float = 30.0,
    idle_notice_interval: float = 60.0,
) -> subprocess.CompletedProcess[str]:
    """Stream CrispASR output and warn when it becomes idle."""
    process = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        bufsize=1,
        **popen_kwargs(),
    )
    output_queue: queue.Queue[tuple[str, str | None]] = queue.Queue()
    output_lines: dict[str, list[str]] = {"stdout": [], "stderr": []}

    def read_output(name: str, stream) -> None:
        try:
            for line in stream:
                output_queue.put((name, line.rstrip("\r\n")))
        finally:
            output_queue.put((name, None))

    readers = [
        Thread(
            target=read_output,
            args=(name, stream),
            name=f"crispasr-{name}",
            daemon=True,
        )
        for name, stream in (
            ("stdout", process.stdout),
            ("stderr", process.stderr),
        )
    ]
    for reader in readers:
        reader.start()

    last_output = time.monotonic()
    next_notice = last_output + idle_notice_after
    notice_count = 0
    streams_closed = 0
    while True:
        if stop_event is not None and stop_event.is_set():
            terminate_process(process)
            _emit_log(emit, file, "CrispASR 已停止")
            raise TaskCancelled()
        now = time.monotonic()
        wait_for = 0.25
        if process.poll() is None:
            wait_for = min(wait_for, max(0.01, next_notice - now))
        try:
            stream_name, line = output_queue.get(timeout=wait_for)
        except queue.Empty:
            stream_name, line = "", ""
        if line is None:
            streams_closed += 1
        elif line:
            output_lines[stream_name].append(line)
            last_output = time.monotonic()
            next_notice = last_output + idle_notice_after
            notice_count = 0
            _emit_log(emit, file, line)

        now = time.monotonic()
        if process.poll() is None and now >= next_notice:
            notice_count += 1
            if notice_count >= 5:
                _emit_log(
                    emit,
                    file,
                    "CrispASR 已连续 5 次无输出，可能出现了问题，建议中断进程并检查听写参数、模型和音频文件",
                )
                next_notice = float("inf")
            else:
                _emit_log(
                    emit,
                    file,
                    f"CrispASR 已超过 {int(idle_notice_after)} 秒没有输出，仍在听写中（第 {notice_count}/5 次提醒）",
                )
                next_notice = now + idle_notice_interval

        if process.poll() is not None and streams_closed >= 2 and output_queue.empty():
            break

    returncode = process.wait()
    return subprocess.CompletedProcess(
        args=command,
        returncode=returncode,
        stdout="\n".join(output_lines["stdout"]),
        stderr="\n".join(output_lines["stderr"]),
    )


def _emit_log(emit: EmitFn | None, file: str | None, message: str) -> None:
    if emit is None:
        return
    payload = {"message": message}
    if file:
        payload["file"] = file
    emit("log", **payload)


def _validate_options(executable: str, command: list[str]) -> None:
    """Reject options unsupported by the installed CrispASR binary."""
    supported = _SUPPORTED_OPTIONS.get(executable)
    if supported is None:
        result = subprocess.run(
            [executable, "--help"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            **popen_kwargs(),
        )
        supported = frozenset(
            re.findall(r"--[a-z0-9][a-z0-9-]*", f"{result.stdout}\n{result.stderr}")
        )
        _SUPPORTED_OPTIONS[executable] = supported
    unknown = sorted(
        {token for token in command if token.startswith("--") and token not in supported}
    )
    if unknown:
        raise RuntimeError(
            "CrispASR 不支持参数: " + ", ".join(unknown) + "。请更新听写参数模板。"
        )


def build_asr_command(
    *,
    executable: str,
    model_path: Path,
    aligner_path: Path | None,
    input_file: Path,
    output_file: Path,
    settings: AppSettings,
) -> list[str]:
    extra = settings.asr.extra_args.strip()
    if extra:
        command = _render_template(
            extra,
            executable=executable,
            model_path=model_path,
            aligner_path=aligner_path,
            backend=settings.asr.backend or "qwen3-1.7b",
            language=settings.asr.language or settings.source_lang or "ja",
            prompt=settings.asr.prompt,
            input_file=input_file,
            output_file=output_file,
        )
        if not settings.asr.force_aligner:
            command = _remove_aligner_options(command)
        return command
    return _command_from_settings(
        executable=executable,
        model_path=model_path,
        aligner_path=aligner_path,
        input_file=input_file,
        output_file=output_file,
        settings=settings,
    )


def _command_from_settings(
    *,
    executable: str,
    model_path: Path,
    aligner_path: Path | None,
    input_file: Path,
    output_file: Path,
    settings: AppSettings,
) -> list[str]:
    asr = settings.asr
    command = [
        executable,
        "--backend", asr.backend or "qwen3-1.7b",
        "--model", str(model_path),
    ]
    if asr.force_aligner:
        if aligner_path is None:
            raise FileNotFoundError("未找到 ASR aligner 模型（.gguf）")
        command.extend(["--aligner-model", str(aligner_path)])
        command.append("--force-aligner")
    command.extend(
        [
            "--language", asr.language or settings.source_lang or "ja",
            "--output-srt",
            "--output-file", str(output_file),
            "--file", str(input_file),
        ]
    )
    if asr.enable_vad:
        command.extend(
            [
                "--vad",
            ]
        )
        if asr.vad_model.strip():
            command.extend(["--vad-model", asr.vad_model.strip()])
        command.extend(
            [
                "--vad-threshold", _fmt_num(asr.vad_threshold),
                "--vad-max-speech-duration-s", _fmt_num(asr.vad_max_speech_duration_s),
                "--vad-min-silence-duration-ms", str(int(asr.vad_min_silence_duration_ms)),
            ]
        )
    if asr.prompt.strip():
        command.extend(["--prompt", asr.prompt.strip()])
    command.extend(
        [
            "--max-new-tokens", str(int(asr.max_new_tokens)),
            "--frequency-penalty", _fmt_num(asr.frequency_penalty),
            "--temperature", _fmt_num(asr.temperature),
        ]
    )
    if int(asr.flush_after) > 0:
        command.extend(["--flush-after", str(int(asr.flush_after))])
    if asr.split_on_punct:
        command.append("--split-on-punct")
    return command


def _resolve_under(folder: Path, name: str) -> Path:
    path = Path(name)
    if not path.is_absolute():
        path = folder / path
    if not path.is_file():
        raise FileNotFoundError(f"未找到模型文件: {path}")
    return path.resolve()


def _render_template(
    template: str,
    executable: str,
    model_path: Path,
    aligner_path: Path | None,
    backend: str,
    language: str,
    prompt: str,
    input_file: Path,
    output_file: Path,
) -> list[str]:
    replacements = {
        "$crispasr_executable": executable,
        "$model_file": str(model_path),
        "$aligner_file": str(aligner_path) if aligner_path else "",
        "$backend": backend,
        "$language": language or "auto",
        "$prompt": prompt,
        "$input_file": str(input_file),
        "$output_file": str(output_file),
    }
    rendered = template
    for key, value in replacements.items():
        rendered = rendered.replace(key, value)
    if os.name == "nt":
        tokens = shlex.split(rendered, posix=False)
        return [
            token[1:-1] if len(token) >= 2 and token[0] == token[-1] and token[0] in "\"'" else token
            for token in tokens
        ]
    return shlex.split(rendered)


def _remove_aligner_options(command: list[str]) -> list[str]:
    """Remove aligner options when forced alignment is disabled."""
    names = {"--aligner-model", "-am", "--force-aligner", "-falign"}
    cleaned: list[str] = []
    skip_value = False
    for token in command:
        if skip_value:
            skip_value = False
            continue
        if token in names:
            if token in {"--aligner-model", "-am"}:
                skip_value = True
            continue
        if any(token.startswith(f"{name}=") for name in {"--aligner-model", "-am"}):
            continue
        cleaned.append(token)
    return cleaned


def _fmt_num(value: float | int) -> str:
    number = float(value)
    if number == 0:
        return "0.0"
    if number.is_integer():
        return str(int(number))
    return format(number, ".8g")


def _fmt_decimal(value: float | int) -> str:
    formatted = format(float(value), ".8g")
    return formatted if "." in formatted or "e" in formatted.lower() else f"{formatted}.0"
