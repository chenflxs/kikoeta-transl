from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from kt.models import Cue, StageFlags
from kt.tools import FALLBACK_ASR_BACKENDS
from kt.stages.export import export_cues
from kt.stages_plan import planned_stages
from kt.subtitle import extract_work_id, parse_subtitle_text
from kt.pipeline import detect_kind


class SubtitleTests(unittest.TestCase):
    def test_parse_srt(self):
        text = "1\n00:00:01,000 --> 00:00:04,000\nこんにちは\n\n2\n00:00:04,500 --> 00:00:06,000\nありがとう\n"
        cues = parse_subtitle_text(text, ".srt")
        self.assertEqual(len(cues), 2)
        self.assertEqual(cues[0].start, 1.0)
        self.assertEqual(cues[0].end, 4.0)
        self.assertEqual(cues[0].message, "こんにちは")

    def test_parse_lrc_fills_end(self):
        text = "[00:01.00] 一行\n[00:04.50] 二行\n"
        cues = parse_subtitle_text(text, ".lrc")
        self.assertEqual(cues[0].start, 1.0)
        self.assertEqual(cues[0].end, 4.5)
        self.assertEqual(cues[1].message, "二行")

    def test_parse_vtt(self):
        text = "WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nhello\n"
        cues = parse_subtitle_text(text, ".vtt")
        self.assertEqual(cues[0].message, "hello")
        self.assertEqual(cues[0].start, 1.0)

    def test_work_id(self):
        self.assertEqual(extract_work_id(r"D:\works\RJ123456\track.mp3"), "RJ123456")


class ExportTests(unittest.TestCase):
    def test_export_target_lrc(self):
        from kt.models import AppSettings, OutputSettings

        cues = [Cue(start=1.0, end=2.0, message="你好", src_message="こんにちは")]
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / "track.srt"
            source.write_text("dummy", encoding="utf-8")
            settings = AppSettings(output=OutputSettings(directory=tmp, preset="target_lrc"))
            outputs = export_cues(cues, source, settings)
            self.assertEqual(len(outputs), 1)
            lrc = Path(outputs[0])
            self.assertTrue(str(lrc).endswith(".lrc"))
            text = lrc.read_text(encoding="utf-8")
            self.assertIn("[00:01.000] 你好", text)
            self.assertNotIn("こんにちは", text)

    def test_export_bilingual_srt(self):
        from kt.models import AppSettings, OutputSettings, normalize_output_preset

        src = [Cue(start=1.0, end=2.0, message="こんにちは", src_message="こんにちは")]
        dst = [Cue(start=1.0, end=2.0, message="你好", src_message="こんにちは")]
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / "track.mp3"
            source.write_text("dummy", encoding="utf-8")
            settings = AppSettings(output=OutputSettings(directory=tmp, preset="bilingual_srt"))
            outputs = export_cues(dst, source, settings, src_cues=src)
            self.assertEqual(len(outputs), 1)
            text = Path(outputs[0]).read_text(encoding="utf-8")
            self.assertTrue(outputs[0].endswith(".srt"))
            self.assertIn("你好", text)
            self.assertIn("こんにちは", text)
            self.assertEqual(normalize_output_preset(formats=["srt"], bilingual=True), "bilingual_srt")

    def test_export_empty_directory_uses_source_dir(self):
        from kt.models import AppSettings, OutputSettings

        cues = [Cue(start=1.0, end=2.0, message="你好", src_message="こんにちは")]
        with tempfile.TemporaryDirectory() as tmp:
            source_dir = Path(tmp) / "album"
            source_dir.mkdir()
            source = source_dir / "track.mp3"
            source.write_text("dummy", encoding="utf-8")
            settings = AppSettings(output=OutputSettings(directory="", preset="target_lrc"))
            outputs = export_cues(cues, source, settings)
            dest = Path(outputs[0])
            self.assertEqual(dest.parent, source_dir)
            self.assertTrue(dest.is_file())
            self.assertTrue(str(dest).endswith(".lrc"))


class AsrCommandTests(unittest.TestCase):
    def test_command_from_defaults(self):
        from kt.models import AppSettings
        from kt.stages.asr import build_asr_command

        command = build_asr_command(
            executable="crispasr.exe",
            model_path=Path("model.gguf"),
            aligner_path=Path("aligner.gguf"),
            input_file=Path("in.wav"),
            output_file=Path("out"),
            settings=AppSettings(),
        )
        self.assertEqual(command, [
            "crispasr.exe", "--backend", "qwen3-1.7b", "--model", "model.gguf",
            "--aligner-model", "aligner.gguf", "--force-aligner", "--language", "ja",
            "--output-srt", "--output-file", "out", "--file", "in.wav", "--vad",
            "--vad-model", "firered", "--vad-threshold", "0.5",
            "--vad-max-speech-duration-s", "6", "--vad-min-silence-duration-ms", "300",
            "--max-new-tokens", "224", "--frequency-penalty", "0.0",
            "--repetition-penalty", "1.0", "--condition-on-previous-text", "True",
            "--temperature", "0.0", "--split-on-punct",
        ])

    def test_command_respects_fields_and_extra_args(self):
        from kt.models import AppSettings, AsrSettings
        from kt.stages.asr import build_asr_command

        settings = AppSettings(
            asr=AsrSettings(
                enable_vad=False,
                split_on_punct=True,
                force_aligner=False,
                max_new_tokens=64,
                frequency_penalty=0.5,
            )
        )
        command = build_asr_command(
            executable="crispasr.exe",
            model_path=Path("model.gguf"),
            aligner_path=Path("aligner.gguf"),
            input_file=Path("in.wav"),
            output_file=Path("out"),
            settings=settings,
        )
        self.assertNotIn("--vad", command)
        self.assertNotIn("--force-aligner", command)
        self.assertIn("--split-on-punct", command)
        self.assertIn("64", command)

        override = AppSettings(asr=AsrSettings(extra_args="$crispasr_executable --file $input_file --language $language"))
        rendered = build_asr_command(
            executable="crispasr.exe",
            model_path=Path("model.gguf"),
            aligner_path=Path("aligner.gguf"),
            input_file=Path("in.wav"),
            output_file=Path("out"),
            settings=override,
        )
        self.assertEqual(rendered, ["crispasr.exe", "--file", "in.wav", "--language", "ja"])

    def test_command_accepts_asr_prompt(self):
        from kt.models import AppSettings, AsrSettings
        from kt.stages.asr import build_asr_command

        command = build_asr_command(
            executable="crispasr.exe",
            model_path=Path("model.gguf"),
            aligner_path=Path("aligner.gguf"),
            input_file=Path("in.wav"),
            output_file=Path("out"),
            settings=AppSettings(asr=AsrSettings(prompt="歌詞の聞き取り")),
        )
        self.assertEqual(command[command.index("--prompt") + 1], "歌詞の聞き取り")


class SettingsParseTests(unittest.TestCase):
    def test_asr_defaults_and_override(self):
        from kt.models import AppSettings

        settings = AppSettings.from_dict({})
        self.assertEqual(settings.output.directory, "")
        self.assertTrue(settings.asr.enable_vad)
        self.assertEqual(settings.asr.max_new_tokens, 224)
        self.assertEqual(settings.asr.repetition_penalty, 1.0)
        self.assertTrue(settings.asr.condition_on_previous_text)
        self.assertEqual(settings.asr.temperature, 0.0)
        self.assertTrue(settings.asr.split_on_punct)
        self.assertEqual(settings.correct.max_tokens, 1024)
        self.assertEqual(settings.translate.context_num, 10)
        self.assertEqual(settings.translate.batch_size, 10)
        self.assertEqual(settings.translate.token_limit, 1024)
        settings = AppSettings.from_dict({"asr": {"enable_vad": False, "max_new_tokens": "64", "vad_model": "silero"}})
        self.assertFalse(settings.asr.enable_vad)
        self.assertEqual(settings.asr.max_new_tokens, 64)
        self.assertEqual(settings.asr.vad_model, "silero")

    def test_model_prompt_settings(self):
        from kt.models import AppSettings

        settings = AppSettings.from_dict({
            "correct": {"prompt": "校对", "temperature": "0.1", "max_tokens": "256"},
            "translate": {
                "prompt_mode": "overwrite",
                "prompt": "只翻译歌词",
                "context_num": "4",
                "batch_size": "12",
                "token_limit": "1024",
            },
        })
        self.assertEqual(settings.correct.prompt, "校对")
        self.assertEqual(settings.correct.max_tokens, 256)
        self.assertEqual(settings.translate.prompt_mode, "overwrite")
        self.assertEqual(settings.translate.context_num, 4)
        self.assertEqual(settings.translate.batch_size, 12)


class CorrectionTests(unittest.TestCase):
    def test_correction_requires_unchanged_srt_structure(self):
        from kt.models import Cue
        from kt.stages.correct import _extract_corrected_messages

        source = [Cue(start=1.0, end=2.5, message="こんにちは")]
        self.assertEqual(
            _extract_corrected_messages(
                "1\n00:00:01,000 --> 00:00:02,500\nこんばんは\n", source
            ),
            ["こんばんは"],
        )
        with self.assertRaisesRegex(RuntimeError, "时间轴"):
            _extract_corrected_messages(
                "1\n00:00:01,001 --> 00:00:02,500\nこんばんは\n", source
            )

    def test_translation_prompt_modes_are_written_for_gt(self):
        import yaml
        from kt.models import AppSettings, TranslateSettings
        from kt.stages.translate import _write_config, ensure_galtransl_path

        ensure_galtransl_path()
        with tempfile.TemporaryDirectory() as tmp:
            workspace = Path(tmp)
            settings = AppSettings(translate=TranslateSettings(prompt_mode="append", prompt="末尾规则"))
            _write_config(workspace, settings)
            common = yaml.safe_load((workspace / "config.yaml").read_text(encoding="utf-8"))["common"]
            self.assertEqual(common["gpt.change_prompt"], "AppendPrompt")
            self.assertEqual(common["gpt.prompt_content"], "末尾规则")

            settings.translate.prompt_mode = "overwrite"
            _write_config(workspace, settings)
            common = yaml.safe_load((workspace / "config.yaml").read_text(encoding="utf-8"))["common"]
            self.assertEqual(common["gpt.change_prompt"], "OverwritePrompt")


class PlanTests(unittest.TestCase):
    def test_media_requires_asr(self):
        stages = planned_stages("media", StageFlags(enable_translate=False))
        self.assertEqual(stages, ["transcoding", "asr", "exporting"])

    def test_subtitle_skips_asr(self):
        stages = planned_stages("subtitle", StageFlags(enable_correct=True, enable_translate=True))
        self.assertEqual(stages, ["correcting", "translating", "exporting"])

    def test_detect_kind(self):
        self.assertEqual(detect_kind("a.mp3"), "media")
        self.assertEqual(detect_kind("a.lrc"), "subtitle")


class CatalogTests(unittest.TestCase):
    def test_asr_backend_fallback(self):
        self.assertIn("qwen3-1.7b", FALLBACK_ASR_BACKENDS)

    def test_resolve_local_tools(self):
        from kt.models import AppSettings
        from kt.tools import list_crispasr_models, list_gt_dicts, resolve_ffmpeg

        ffmpeg, ffprobe = resolve_ffmpeg(AppSettings())
        self.assertTrue(Path(ffmpeg).is_file())
        self.assertTrue(ffmpeg.lower().endswith("ffmpeg.exe") or ffmpeg.endswith("ffmpeg"))
        self.assertTrue(Path(ffprobe).is_file())
        info = list_crispasr_models(AppSettings())
        self.assertTrue(info["models"], msg=info)
        self.assertTrue(info["aligners"], msg=info)
        names = [item["name"] for item in list_gt_dicts()]
        self.assertTrue(any("GPT" in name for name in names), names)


if __name__ == "__main__":
    unittest.main()
