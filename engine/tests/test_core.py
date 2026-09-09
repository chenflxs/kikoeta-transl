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

    def test_export_suffix_is_inserted_before_extension(self):
        from kt.models import AppSettings, OutputSettings

        cues = [Cue(start=1.0, end=2.0, message="你好")]
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / "track.lrc"
            source.write_text("dummy", encoding="utf-8")
            settings = AppSettings(
                output=OutputSettings(directory=tmp, preset="target_lrc", suffix=".fix")
            )
            outputs = export_cues(cues, source, settings)
            self.assertEqual(Path(outputs[0]).name, "track.fix.lrc")


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
            "--temperature", "0.0", "--flush-after", "1", "--split-on-punct",
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
        self.assertEqual(rendered, [
            "crispasr.exe", "--file", "in.wav", "--language", "ja",
            "--flush-after", "1",
        ])

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
        self.assertEqual(settings.correct.max_tokens, 4096)
        self.assertFalse(settings.correct.enable_thinking)
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
        self.assertFalse(settings.correct.enable_thinking)
        self.assertEqual(settings.translate.prompt_mode, "overwrite")
        self.assertEqual(settings.translate.context_num, 4)
        self.assertEqual(settings.translate.batch_size, 12)
        self.assertFalse(settings.translate.enable_thinking)


class CorrectionTests(unittest.TestCase):
    def test_correction_prompt_freezes_position_and_symbol_width(self):
        from kt.stages.correct import SYSTEM_PROMPT

        self.assertIn("仅 100% 确定的错误才修正", SYSTEM_PROMPT)
        self.assertIn("JSON 字符串数组", SYSTEM_PROMPT)
        self.assertIn("禁止合并、拆分、删除或重排", SYSTEM_PROMPT)
        self.assertIn("不要生成、猜测或修改时间戳", SYSTEM_PROMPT)
        self.assertIn("口语缩约", SYSTEM_PROMPT)
        self.assertIn("デヒトトビ", SYSTEM_PROMPT)

    def test_local_timeline_merge_before_text_only_request(self):
        import json
        from unittest.mock import patch
        from kt.models import AppSettings, CorrectionSettings
        from kt.stages.correct import correct_cues

        cues = [
            Cue(324.98, 330, "私絶対に…"),
            Cue(340.6, 342, "あぁぁーんっ!"),
            Cue(339.32, 340, "んんっ!"),
            Cue(339.32, 341, "激しくしないでください"),
        ]
        messages = ["私絶対に…", "んんっ! 激しくしないでください", "あぁぁーんっ!"]
        settings = AppSettings(correct=CorrectionSettings(base_url="https://example.test", model="demo"))
        with patch("kt.stages.correct._chat", return_value=json.dumps(messages)) as chat:
            result = correct_cues(cues, settings)
        self.assertIn(json.dumps(messages, ensure_ascii=False), chat.call_args.args[1])
        self.assertNotIn("[05:", chat.call_args.args[1])
        self.assertNotIn("339.32", chat.call_args.args[1])
        self.assertEqual([cue.start for cue in result], [324.98, 339.32, 340.6])
        self.assertEqual(result[1].end, 341)
        self.assertEqual(result[1].src_message, messages[1])
        self.assertEqual(len(cues), 4)
        self.assertEqual(cues[2].message, "んんっ!")

    def test_correction_json_preserves_multiline_and_validates_count(self):
        import json
        from kt.stages.correct import _extract_corrected_messages, _to_prompt_lines
        cues = [Cue(1, 2, '一行\n"二行"'), Cue(2, 3, "三行")]
        self.assertEqual(json.loads(_to_prompt_lines(cues)), [cue.message for cue in cues])
        self.assertEqual(_extract_corrected_messages(_to_prompt_lines(cues), cues), [cue.message for cue in cues])
        for response in ('["一行"]', '["一行", 3]', '["一行", ""]'):
            with self.assertRaises(RuntimeError):
                _extract_corrected_messages(response, cues)

    def test_correct_request_retries_with_minimal_payload_on_400(self):
        from unittest.mock import patch

        import httpx
        from kt.models import AppSettings, CorrectionSettings
        from kt.stages.correct import _chat

        responses = [
            httpx.Response(
                400,
                json={"error": {"message": "unsupported temperature"}},
                request=httpx.Request("POST", "https://example.test/v1/chat/completions"),
            ),
            httpx.Response(
                200,
                json={"choices": [{"message": {"content": "ok"}}]},
                request=httpx.Request("POST", "https://example.test/v1/chat/completions"),
            ),
        ]
        settings = AppSettings(
            correct=CorrectionSettings(
                base_url="https://example.test/v1",
                model="demo",
                temperature=0.2,
            )
        )
        with patch("httpx.post", side_effect=responses) as post:
            self.assertEqual(_chat(settings.correct, "input", ""), "ok")
        self.assertEqual(post.call_count, 2)
        self.assertNotIn("temperature", post.call_args.kwargs["json"])

    def test_correct_request_can_disable_thinking(self):
        from unittest.mock import patch

        import httpx
        from kt.models import AppSettings, CorrectionSettings
        from kt.stages.correct import _chat

        response = httpx.Response(
            200,
            json={"choices": [{"message": {"content": "ok"}}]},
            request=httpx.Request("POST", "https://example.test/v1/chat/completions"),
        )
        settings = AppSettings(
            correct=CorrectionSettings(
                base_url="https://example.test/v1",
                model="demo",
                enable_thinking=False,
            )
        )
        with patch("httpx.post", return_value=response) as post:
            self.assertEqual(_chat(settings.correct, "input", ""), "ok")
        self.assertEqual(
            post.call_args.kwargs["json"]["thinking"], {"type": "disabled"}
        )
        self.assertEqual(post.call_args.kwargs["json"]["max_tokens"], 4096)

    def test_correct_request_retries_without_thinking_after_reasoning_exhausts_budget(self):
        from unittest.mock import patch

        import httpx
        from kt.models import CorrectionSettings
        from kt.stages.correct import _chat

        responses = [
            httpx.Response(
                200,
                json={
                    "choices": [
                        {"finish_reason": "length", "message": {"content": None}}
                    ]
                },
                request=httpx.Request("POST", "https://example.test/v1/chat/completions"),
            ),
            httpx.Response(
                200,
                json={
                    "choices": [
                        {"finish_reason": "stop", "message": {"content": "ok"}}
                    ]
                },
                request=httpx.Request("POST", "https://example.test/v1/chat/completions"),
            ),
        ]
        settings = CorrectionSettings(
            base_url="https://example.test/v1",
            model="demo",
            enable_thinking=True,
        )
        with patch("httpx.post", side_effect=responses) as post:
            self.assertEqual(_chat(settings, "input", ""), "ok")
        self.assertEqual(post.call_count, 2)
        self.assertEqual(
            post.call_args.kwargs["json"]["thinking"], {"type": "disabled"}
        )

    def test_correction_keeps_source_timeline_when_model_reformats_it(self):
        from kt.models import Cue
        from kt.stages.correct import _extract_corrected_messages

        source = [Cue(start=1.0, end=2.5, message="こんにちは")]
        self.assertEqual(
            _extract_corrected_messages(
                "1\n00:00:01,000 --> 00:00:02,500\nこんばんは\n", source
            ),
            ["こんばんは"],
        )
        self.assertEqual(
            _extract_corrected_messages(
                "1\n00:00:01,001 --> 00:00:02,500\nこんばんは\n", source
            ),
            ["こんばんは"],
        )
        with self.assertRaisesRegex(RuntimeError, "结构"):
            _extract_corrected_messages("1\nnot-a-timeline\nこんばんは\n", source)

    def test_correction_accepts_one_line_timestamp_response(self):
        from kt.models import Cue
        from kt.stages.correct import _extract_corrected_messages

        source = [
            Cue(start=56.59, end=62.26, message="原文1"),
            Cue(start=62.26, end=67.19, message="原文2"),
        ]
        response = (
            "[00:00:56,590] 修正1\n"
            "[00:01:02,260] 修正2\n"
        )
        self.assertEqual(
            _extract_corrected_messages(response, source),
            ["修正1", "修正2"],
        )

    def test_correction_splits_large_inputs_into_batches(self):
        from unittest.mock import patch

        from kt.models import AppSettings, CorrectionSettings, Cue
        from kt.stages.correct import CORRECTION_BATCH_SIZE, _to_srt, correct_cues

        cues = [Cue(start=index, end=index + 1, message=f"原文{index}") for index in range(21)]
        batches = [
            cues[index : index + CORRECTION_BATCH_SIZE]
            for index in range(0, len(cues), CORRECTION_BATCH_SIZE)
        ]
        responses = [
            _to_srt(
                [
                    Cue(start=cue.start, end=cue.end, message=f"修正{cue.message}")
                    for cue in batch
                ],
                start_index=index + 1,
            )
            for index, batch in zip(range(0, len(cues), CORRECTION_BATCH_SIZE), batches)
        ]
        settings = AppSettings(
            correct=CorrectionSettings(base_url="https://example.test/v1", model="demo")
        )
        with patch("kt.stages.correct._chat", side_effect=responses) as chat:
            result = correct_cues(cues, settings)

        self.assertEqual(chat.call_count, len(batches))
        self.assertEqual([cue.message for cue in result], [f"修正原文{index}" for index in range(21)])

    def test_correction_sends_full_lyrics_as_context_and_only_current_batch_as_target(self):
        from unittest.mock import patch

        from kt.models import AppSettings, CorrectionSettings, Cue
        from kt.stages.correct import CORRECTION_BATCH_SIZE, _to_srt, correct_cues

        cues = [Cue(start=index, end=index + 1, message=f"原文{index}") for index in range(25)]
        responses = []
        for offset in range(0, len(cues), CORRECTION_BATCH_SIZE):
            batch = cues[offset : offset + CORRECTION_BATCH_SIZE]
            responses.append(
                _to_srt(
                    [
                        Cue(
                            start=cue.start,
                            end=cue.end,
                            message=f"修正{cue.message}",
                        )
                        for cue in batch
                    ],
                    start_index=offset + 1,
                )
            )
        settings = AppSettings(
            correct=CorrectionSettings(base_url="https://example.test/v1", model="demo")
        )
        with patch("kt.stages.correct._chat", side_effect=responses) as chat:
            correct_cues(cues, settings)

        second_input = chat.call_args_list[1].args[1]
        self.assertIn("完整歌词上下文（25 条", second_input)
        self.assertIn(">>> 当前目标批次（第 11-20 条，共 10 条", second_input)
        self.assertIn("修正原文8", second_input)
        self.assertIn("修正原文9", second_input)
        self.assertIn("原文20", second_input)
        self.assertIn("原文24", second_input)
        self.assertNotIn("前导上下文", second_input)
        self.assertNotIn("后续验证", second_input)

    def test_correction_emits_progress_logs(self):
        from unittest.mock import patch

        from kt.models import AppSettings, CorrectionSettings, Cue
        from kt.stages.correct import _to_srt, correct_cues

        cues = [
            Cue(start=0, end=1, message="原文1"),
            Cue(start=1, end=2, message="原文2"),
        ]
        response = _to_srt(
            [
                Cue(start=cue.start, end=cue.end, message=f"修正{cue.message}")
                for cue in cues
            ]
        )
        settings = AppSettings(
            correct=CorrectionSettings(
                base_url="https://example.test/v1", model="demo"
            )
        )
        events = []
        with patch("kt.stages.correct._chat", return_value=response):
            correct_cues(
                cues,
                settings,
                emit=lambda event_type, **payload: events.append(
                    (event_type, payload)
                ),
                file="demo.srt",
            )

        messages = [payload["message"] for event_type, payload in events if event_type == "log"]
        self.assertEqual(len(messages), 6)
        self.assertIn("本地时间轴整理完成", messages[0])
        self.assertIn("矫正开始", messages[1])
        self.assertIn("正在请求矫正模型", messages[2])
        self.assertIn("已收到矫正响应", messages[3])
        self.assertIn("修改 2 条", messages[4])
        self.assertIn("矫正完成", messages[5])
        self.assertTrue(all(payload["file"] == "demo.srt" for _, payload in events))

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

            settings.translate.enable_thinking = False
            _write_config(workspace, settings)
            config = yaml.safe_load((workspace / "config.yaml").read_text(encoding="utf-8"))
            self.assertEqual(
                config["backendSpecific"]["OpenAI-Compatible"]["extra_body"],
                {"thinking": {"type": "disabled"}},
            )


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

    def test_combined_subtitle_pipeline_uses_target_language_suffix(self):
        from unittest.mock import patch

        from kt.models import AppSettings, OutputSettings
        from kt.pipeline import process_file

        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / "track.lrc"
            source.write_text("[00:01.000] こんにちは\n", encoding="utf-8")
            settings = AppSettings(
                target_lang="zh-cn",
                output=OutputSettings(directory=tmp, preset="target_lrc"),
            )
            corrected = [Cue(start=1.0, end=4.0, message="こんばんは", src_message="こんにちは")]
            translated = [Cue(start=1.0, end=4.0, message="你好", src_message="こんばんは")]
            with patch("kt.stages.correct.correct_cues", return_value=corrected), patch(
                "kt.stages.translate.translate_cues", return_value=translated
            ):
                result = process_file(
                    str(source),
                    settings,
                    StageFlags(enable_correct=True, enable_translate=True),
                    Path(tmp) / "job",
                    emit=lambda *_args, **_kwargs: None,
                )
            self.assertEqual(result.status, "done")
            self.assertEqual(Path(result.outputs[0]).name, "track.zh.lrc")


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

    def test_resolve_ffmpeg_skips_broken_configured_binary(self):
        from kt.models import AppSettings
        from kt.tools import resolve_ffmpeg

        with tempfile.TemporaryDirectory() as tmp:
            broken = Path(tmp) / "ffmpeg.exe"
            broken.write_bytes(b"MZ but truncated")
            ffmpeg, ffprobe = resolve_ffmpeg(
                AppSettings(ffmpeg_path=str(broken), ffprobe_path=str(broken))
            )
            self.assertNotEqual(Path(ffmpeg).resolve(), broken.resolve())
            self.assertNotEqual(Path(ffprobe).resolve(), broken.resolve())


if __name__ == "__main__":
    unittest.main()
