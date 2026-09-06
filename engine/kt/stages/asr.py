from __future__ import annotations

import os
import shlex
import shutil
import subprocess
import tempfile
from pathlib import Path

from ..models import AppSettings, Cue
from ..subtitle import parse_subtitle
from ..tools import list_crispasr_models, popen_kwargs, resolve_crispasr_dir


DEFAULT_ASR_TEMPLATE = (
    "$crispasr_executable --backend $backend --model $model_file "
    "--aligner-model $aligner_file --force-aligner --language $language "
    "--output-srt --output-file $output_file --file $input_file --vad "
    "--vad-model firered --vad-threshold 0.5 --vad-max-speech-duration-s 6 "
    "--vad-min-silence-duration-ms 300 --max-new-tokens 224 "
    "--frequency-penalty 0.0 --repetition-penalty 1.0 "
    "--condition-on-previous-text True --temperature 0.0 --split-on-punct"
)


def transcribe_wav(wav_path: str | Path, work_dir: Path, settings: AppSettings) -> list[Cue]:
    info = list_crispasr_models(settings)
    executable = info["executable"]
    if not executable:
        raise FileNotFoundError("未找到 CrispASR 可执行文件，请放到 bin/crispasr")
    model = settings.asr.model or (info["models"][0] if info["models"] else "")
    aligner = settings.asr.aligner or (info["aligners"][0] if info["aligners"] else "")
    if not model:
        raise FileNotFoundError("未找到 ASR 模型（.gguf）")
    if not aligner:
        raise FileNotFoundError("未找到 ASR aligner 模型（.gguf）")

    folder = resolve_crispasr_dir(settings)
    model_path = _resolve_under(folder, model)
    aligner_path = _resolve_under(folder, aligner)

    job_dir = Path(tempfile.mkdtemp(prefix="asr_", dir=str(work_dir)))
    staged = job_dir / f"input{Path(wav_path).suffix.lower()}"
    output_base = job_dir / "transcript"
    generated = output_base.with_suffix(".srt")
    shutil.copyfile(wav_path, staged)
    command = build_asr_command(
        executable=executable,
        model_path=model_path,
        aligner_path=aligner_path,
        input_file=staged,
        output_file=output_base,
        settings=settings,
    )
    result = subprocess.run(
        command,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        **popen_kwargs(),
    )
    if result.returncode != 0 or not generated.is_file() or generated.stat().st_size == 0:
        detail = (result.stderr or result.stdout or "").strip()
        raise RuntimeError(f"CrispASR 失败: {detail or result.returncode}")
    cues = parse_subtitle(generated)
    shutil.rmtree(job_dir, ignore_errors=True)
    return cues


def build_asr_command(
    *,
    executable: str,
    model_path: Path,
    aligner_path: Path,
    input_file: Path,
    output_file: Path,
    settings: AppSettings,
) -> list[str]:
    extra = settings.asr.extra_args.strip()
    if extra:
        return _render_template(
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
    aligner_path: Path,
    input_file: Path,
    output_file: Path,
    settings: AppSettings,
) -> list[str]:
    asr = settings.asr
    command = [
        executable,
        "--backend", asr.backend or "qwen3-1.7b",
        "--model", str(model_path),
        "--aligner-model", str(aligner_path),
    ]
    if asr.force_aligner:
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
            "--repetition-penalty", _fmt_decimal(asr.repetition_penalty),
            "--condition-on-previous-text", str(asr.condition_on_previous_text),
            "--temperature", _fmt_num(asr.temperature),
        ]
    )
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
    aligner_path: Path,
    backend: str,
    language: str,
    prompt: str,
    input_file: Path,
    output_file: Path,
) -> list[str]:
    replacements = {
        "$crispasr_executable": executable,
        "$model_file": str(model_path),
        "$aligner_file": str(aligner_path),
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
