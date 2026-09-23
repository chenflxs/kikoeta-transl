from __future__ import annotations

import re
from dataclasses import asdict, dataclass, field
from typing import Any, Literal

StageName = Literal[
    "queued",
    "transcoding",
    "asr",
    "correcting",
    "translating",
    "exporting",
    "done",
    "failed",
    "cancelled",
]

FileKind = Literal["media", "subtitle"]


@dataclass
class Cue:
    start: float
    end: float
    message: str
    src_message: str = ""

    def to_gt_item(self) -> dict[str, Any]:
        return {
            "start": self.start,
            "end": self.end,
            "message": self.message,
            "src_message": self.src_message or self.message,
        }

    @classmethod
    def from_mapping(cls, item: dict[str, Any]) -> "Cue":
        message = str(item.get("message") or "")
        src = str(item.get("src_message") or item.get("org_message") or message)
        return cls(
            start=float(item.get("start") or 0),
            end=float(item.get("end") or item.get("start") or 0),
            message=message,
            src_message=src,
        )


def cues_to_gt_json(cues: list[Cue]) -> list[dict[str, Any]]:
    return [cue.to_gt_item() for cue in cues]


def cues_from_gt_json(items: list[dict[str, Any]], fallback: list[Cue]) -> list[Cue]:
    out: list[Cue] = []
    for index, item in enumerate(items):
        cue = Cue.from_mapping(item)
        if index < len(fallback):
            if cue.start == 0 and cue.end == 0:
                cue.start = fallback[index].start
                cue.end = fallback[index].end
            if not cue.src_message:
                cue.src_message = fallback[index].src_message or fallback[index].message
        out.append(cue)
    return out


@dataclass
class StageFlags:
    enable_correct: bool = False
    enable_translate: bool = True


@dataclass
class AsrSettings:
    model: str = ""
    aligner: str = ""
    backend: str = "qwen3-1.7b"
    language: str = "ja"
    prompt: str = ""
    extra_args: str = ""
    threads: int = 4
    processors: int = 1
    offset_t: int = 0
    offset_n: int = 0
    duration: int = 0
    max_context: int = -1
    max_len: int = 0
    hotwords: str = ""
    split_on_word: bool = False
    best_of: int = 5
    beam_size: str = "greedy"
    audio_ctx: int = 0
    word_thold: float = 0.01
    entropy_thold: float = 2.4
    logprob_thold: float = -1.0
    no_speech_thold: float = 0.6
    sensitivity: str = "balanced"
    seed: int = 0
    temperature_inc: float = 0.2
    no_fallback: bool = False
    no_punctuation: bool = False
    punc_model: str = ""
    truecase_model: str = ""
    flush_after: int = 1
    chunk_seconds: int = 30
    chunk_overlap: float = 3.0
    no_gpu: bool = False
    device: int = 0
    gpu_backend: str = "auto"
    flash_attn: bool = True
    enable_vad: bool = True
    vad_max_speech_duration_s: float = 6.0
    vad_min_silence_duration_ms: int = 300
    max_new_tokens: int = 512
    max_new_tokens_default_version: int = 2
    frequency_penalty: float = 0.0
    repetition_penalty: float = 1.0
    condition_on_previous_text: bool = True
    temperature: float = 0.0
    split_on_punct: bool = True
    vad_model: str = "firered"
    vad_threshold: float = 0.5
    force_aligner: bool = True


@dataclass
class ModelEndpoint:
    base_url: str = ""
    model: str = ""
    api_key: str = ""


@dataclass
class CorrectionSettings:
    provider: str = "online"
    base_url: str = ""
    model: str = ""
    api_key: str = ""
    prompt: str = ""
    temperature: float = 0.2
    # Correction prompts include strict formatting instructions, and some
    # providers spend part of the completion budget on hidden reasoning.
    # Keep enough room for both reasoning and the returned subtitle text.
    max_tokens: int = 4096
    # Subtitle correction must leave enough completion budget for the actual
    # SRT/LRC body.  DeepSeek enables thinking by default, so opt out unless
    # the user explicitly turns it on.
    enable_thinking: bool | None = False


@dataclass
class TranslateSettings:
    provider: str = "online"
    translator: str = "ForGal-json"
    openai: ModelEndpoint = field(default_factory=ModelEndpoint)
    sakura_endpoint: str = "http://127.0.0.1:8080"
    sakura_model: str = ""
    prompt_mode: str = "append"
    prompt: str = ""
    context_num: int = 10
    batch_size: int = 10
    token_limit: int = 1024
    # None leaves the provider default unchanged; False disables thinking
    # through the OpenAI-compatible extra_body field where supported.
    enable_thinking: bool | None = None


OUTPUT_PRESETS = (
    "target_lrc",
    "target_srt",
    "bilingual_lrc",
    "bilingual_srt",
    "source_target_lrc",
    "source_target_srt",
)


def normalize_output_preset(preset: str = "", formats: list[str] | None = None, bilingual: bool | None = None) -> str:
    value = str(preset or "").strip().lower().replace("-", "_")
    aliases = {
        "lrc": "target_lrc",
        "srt": "target_srt",
        "targetlrc": "target_lrc",
        "targetsrt": "target_srt",
        "bilinguallrc": "bilingual_lrc",
        "bilingualsrt": "bilingual_srt",
        "sourcetargetlrc": "source_target_lrc",
        "sourcetargetsrt": "source_target_srt",
    }
    value = aliases.get(value, value)
    if value in OUTPUT_PRESETS:
        return value
    items = [str(item).lower().lstrip(".") for item in (formats or []) if str(item).strip()]
    fmt = "srt" if "srt" in items and "lrc" not in items else "lrc"
    use_bilingual = bool(bilingual)
    return ("bilingual" if use_bilingual else "target") + "_" + fmt


def preset_format(preset: str) -> str:
    return "srt" if str(preset).endswith("srt") else "lrc"


def preset_bilingual(preset: str) -> bool:
    value = str(preset)
    return value.startswith("bilingual_") or value.startswith("source_target_")


def preset_source_first(preset: str) -> bool:
    return str(preset).startswith("source_target_")


@dataclass
class OutputSettings:
    directory: str = ""
    preset: str = "target_lrc"
    formats: list[str] = field(default_factory=lambda: ["lrc"])
    bilingual: bool = False
    keep_gt_cache: bool = True
    # Optional suffix inserted before the output extension, e.g. ".fix" or
    # ".zh". An empty suffix preserves the historical file name.
    suffix: str = ""


@dataclass
class AppSettings:
    ffmpeg_path: str = ""
    ffprobe_path: str = ""
    crispasr_dir: str = ""
    llama_dir: str = ""
    llama_model: str = ""
    proxy: str = ""
    theme: str = "system"
    remote_access: bool = False
    remote_username: str = "admin"
    remote_password: str = "kikoeta"
    source_lang: str = "ja"
    target_lang: str = "zh-cn"
    flags: StageFlags = field(default_factory=StageFlags)
    asr: AsrSettings = field(default_factory=AsrSettings)
    correct: CorrectionSettings = field(default_factory=CorrectionSettings)
    translate: TranslateSettings = field(default_factory=TranslateSettings)
    output: OutputSettings = field(default_factory=OutputSettings)
    dict_pre: str = ""
    dict_gpt: str = ""
    dict_after: str = ""

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict[str, Any] | None) -> "AppSettings":
        raw = data or {}
        flags = raw.get("flags") or {}
        asr = raw.get("asr") or {}
        correct = raw.get("correct") or {}
        translate = raw.get("translate") or {}
        openai = translate.get("openai") or {}
        output = raw.get("output") or {}
        formats = output.get("formats") or ["lrc"]
        if isinstance(formats, str):
            formats = [formats]
        return cls(
            ffmpeg_path=str(raw.get("ffmpeg_path") or ""),
            ffprobe_path=str(raw.get("ffprobe_path") or ""),
            crispasr_dir=str(raw.get("crispasr_dir") or ""),
            llama_dir=str(raw.get("llama_dir") or ""),
            llama_model=str(raw.get("llama_model") or ""),
            proxy=str(raw["proxy"] if "proxy" in raw else "http://127.0.0.1:7890"),
            theme=str(raw.get("theme") or "system"),
            remote_access=_as_bool(raw.get("remote_access"), False),
            remote_username=_remote_username(raw.get("remote_username")),
            remote_password=str(raw.get("remote_password") or "kikoeta"),
            source_lang=str(raw.get("source_lang") or "ja"),
            target_lang=str(raw.get("target_lang") or "zh-cn"),
            flags=StageFlags(
                enable_correct=bool(flags.get("enable_correct", False)),
                enable_translate=bool(flags.get("enable_translate", True)),
            ),
            asr=_asr_from_dict(asr, str(raw.get("source_lang") or "ja")),
            correct=CorrectionSettings(
                provider=_normalize_provider(correct.get("provider")),
                base_url=str(correct.get("base_url") or ""),
                model=str(correct.get("model") or ""),
                api_key=str(correct.get("api_key") or ""),
                prompt=str(correct.get("prompt") or ""),
                temperature=_as_float(correct.get("temperature"), 0.2),
                max_tokens=_positive_int(correct.get("max_tokens"), 4096),
                enable_thinking=(
                    _optional_bool(correct.get("enable_thinking"))
                    if "enable_thinking" in correct
                    else False
                ),
            ),
            translate=TranslateSettings(
                provider=_normalize_provider(translate.get("provider")),
                translator=str(translate.get("translator") or "ForGal-json"),
                openai=ModelEndpoint(
                    base_url=str(openai.get("base_url") or ""),
                    model=str(openai.get("model") or ""),
                    api_key=str(openai.get("api_key") or ""),
                ),
                sakura_endpoint=str(translate.get("sakura_endpoint") or "http://127.0.0.1:8080"),
                sakura_model=str(translate.get("sakura_model") or ""),
                prompt_mode=_normalize_prompt_mode(translate.get("prompt_mode")),
                prompt=str(translate.get("prompt") or ""),
                context_num=_as_int(translate.get("context_num"), 10),
                batch_size=_as_int(translate.get("batch_size"), 10),
                token_limit=_as_int(translate.get("token_limit"), 1024),
                enable_thinking=_optional_bool(translate.get("enable_thinking")),
            ),
            output=_output_from_dict(output, formats),
            dict_pre=str(raw.get("dict_pre") or ""),
            dict_gpt=str(raw.get("dict_gpt") or ""),
            dict_after=str(raw.get("dict_after") or ""),
        )


@dataclass
class JobRequest:
    files: list[str]
    flags: StageFlags = field(default_factory=StageFlags)
    settings_override: dict[str, Any] = field(default_factory=dict)
    cleanup_paths: list[str] = field(default_factory=list)
    cache_context: dict[str, Any] = field(default_factory=dict)


@dataclass
class FileResult:
    path: str
    kind: FileKind
    status: StageName = "queued"
    stage: str = "queued"
    message: str = ""
    outputs: list[str] = field(default_factory=list)
    error: str = ""

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


def _asr_from_dict(asr: dict[str, Any], source_lang: str) -> AsrSettings:
    legacy_token_default = _as_int(asr.get("max_new_tokens_default_version"), 1) < 2
    max_new_tokens = _as_int(asr.get("max_new_tokens"), 512)
    if legacy_token_default and max_new_tokens == 224:
        max_new_tokens = 512
    extra_args = str(asr.get("extra_args") or "")
    if legacy_token_default:
        extra_args = re.sub(
            r"(?<!\S)((?:--max-new-tokens|-n)(?:\s+|=))224(?=\s|$)",
            r"\g<1>512",
            extra_args,
        )
    return AsrSettings(
        model=str(asr.get("model") or ""),
        aligner=str(asr.get("aligner") or ""),
        backend=str(asr.get("backend") or "qwen3-1.7b"),
        language=str(asr.get("language") or source_lang or "ja"),
        prompt=str(asr.get("prompt") or ""),
        extra_args=extra_args,
        threads=_as_int(asr.get("threads"), 4),
        processors=_as_int(asr.get("processors"), 1),
        offset_t=_as_int(asr.get("offset_t"), 0),
        offset_n=_as_int(asr.get("offset_n"), 0),
        duration=_as_int(asr.get("duration"), 0),
        max_context=_as_int(asr.get("max_context"), -1),
        max_len=_as_int(asr.get("max_len"), 0),
        hotwords=str(asr.get("hotwords") or ""),
        split_on_word=_as_bool(asr.get("split_on_word"), False),
        best_of=_as_int(asr.get("best_of"), 5),
        beam_size=str(asr.get("beam_size") or "greedy"),
        audio_ctx=_as_int(asr.get("audio_ctx"), 0),
        word_thold=_as_float(asr.get("word_thold"), 0.01),
        entropy_thold=_as_float(asr.get("entropy_thold"), 2.4),
        logprob_thold=_as_float(asr.get("logprob_thold"), -1.0),
        no_speech_thold=_as_float(asr.get("no_speech_thold"), 0.6),
        sensitivity=str(asr.get("sensitivity") or "balanced"),
        seed=_as_int(asr.get("seed"), 0),
        temperature_inc=_as_float(asr.get("temperature_inc"), 0.2),
        no_fallback=_as_bool(asr.get("no_fallback"), False),
        no_punctuation=_as_bool(asr.get("no_punctuation"), False),
        punc_model=str(asr.get("punc_model") or ""),
        truecase_model=str(asr.get("truecase_model") or ""),
        flush_after=_as_int(asr.get("flush_after"), 1),
        chunk_seconds=_as_int(asr.get("chunk_seconds"), 30),
        chunk_overlap=_as_float(asr.get("chunk_overlap"), 3.0),
        no_gpu=_as_bool(asr.get("no_gpu"), False),
        device=_as_int(asr.get("device"), 0),
        gpu_backend=str(asr.get("gpu_backend") or "auto"),
        flash_attn=_as_bool(asr.get("flash_attn"), True),
        enable_vad=_as_bool(asr.get("enable_vad"), True),
        vad_max_speech_duration_s=_as_float(asr.get("vad_max_speech_duration_s"), 6.0),
        vad_min_silence_duration_ms=_as_int(asr.get("vad_min_silence_duration_ms"), 300),
        max_new_tokens=max_new_tokens,
        max_new_tokens_default_version=2,
        frequency_penalty=_as_float(asr.get("frequency_penalty"), 0.0),
        repetition_penalty=_as_float(asr.get("repetition_penalty"), 1.0),
        condition_on_previous_text=_as_bool(asr.get("condition_on_previous_text"), True),
        temperature=_as_float(asr.get("temperature"), 0.0),
        split_on_punct=_as_bool(asr.get("split_on_punct"), True),
        vad_model=str(asr.get("vad_model") or "firered"),
        vad_threshold=_as_float(asr.get("vad_threshold"), 0.5),
        force_aligner=_as_bool(asr.get("force_aligner"), True),
    )


def _normalize_prompt_mode(value: Any) -> str:
    mode = str(value or "append").strip().lower()
    if mode in {"overwrite", "overwriteprompt"}:
        return "overwrite"
    return "append"


def _normalize_provider(value: Any) -> str:
    return "local_llama" if str(value or "").strip().lower() == "local_llama" else "online"


def _as_bool(value: Any, default: bool) -> bool:
    if value is None or value == "":
        return default
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return bool(value)
    text = str(value).strip().lower()
    if text in {"1", "true", "yes", "on"}:
        return True
    if text in {"0", "false", "no", "off"}:
        return False
    return default


def _remote_username(value: Any) -> str:
    username = str(value or "admin").strip()
    return username if username and ":" not in username else "admin"


def _optional_bool(value: Any) -> bool | None:
    if value is None or value == "":
        return None
    if isinstance(value, str):
        text = value.strip().lower()
        if text in {"1", "true", "yes", "on"}:
            return True
        if text in {"0", "false", "no", "off"}:
            return False
        return None
    if isinstance(value, (bool, int, float)):
        return bool(value)
    return None


def _as_float(value: Any, default: float) -> float:
    try:
        if value is None or value == "":
            return default
        return float(value)
    except (TypeError, ValueError):
        return default


def _as_int(value: Any, default: int) -> int:
    try:
        if value is None or value == "":
            return default
        return int(float(value))
    except (TypeError, ValueError):
        return default


def _output_from_dict(output: dict[str, Any], formats: list[Any]) -> OutputSettings:
    preset = normalize_output_preset(
        str(output.get("preset") or ""),
        [str(item) for item in formats if str(item)],
        bool(output.get("bilingual", False)),
    )
    return OutputSettings(
        directory=str(output.get("directory") or ""),
        preset=preset,
        formats=[preset_format(preset)],
        bilingual=preset_bilingual(preset),
        keep_gt_cache=bool(output.get("keep_gt_cache", True)),
        suffix=str(output.get("suffix") or ""),
    )


def _positive_int(value: Any, default: int) -> int:
    parsed = _as_int(value, default)
    return parsed if parsed > 0 else default
