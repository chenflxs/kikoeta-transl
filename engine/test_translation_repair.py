import json
import sys
import tempfile
import unittest
from contextlib import nullcontext
from pathlib import Path
from threading import Event
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))

from kt.cancellation import TaskCancelled
from kt.models import AppSettings, Cue, OutputSettings, StageFlags
from kt.pipeline import process_file
from kt.stages.translate import (
    _looks_untranslated, _merge_translation_items, ensure_galtransl_path, translate_cues,
)


class TranslationRepairTests(unittest.TestCase):
    def setUp(self):
        self.settings = AppSettings(source_lang="ja", target_lang="zh-cn")

    def test_short_and_partial_japanese_are_not_diluted_by_source_length(self):
        pairs = [
            ("行け", "行け"), ("お帰りなさい、今日もお疲れ様でした", "欢迎回来は"),
            ("待って", "请稍等ね"), ("未来", "未来へ"), ("先生", "老师センセイ"),
        ]
        for original, translated in pairs:
            with self.subTest(original=original):
                self.assertTrue(_looks_untranslated(Cue(1, 2, original), Cue(1, 2, translated), self.settings))

    def test_compare_with_corrected_translation_input(self):
        self.settings.source_lang = "en"
        source = Cue(1, 2, "Come home", src_message="Come hom")
        self.assertTrue(_looks_untranslated(source, Cue(1, 2, "Come home"), self.settings))

    def test_nonverbal_numbers_punctuation_and_same_language_are_allowed(self):
        for original, translated in [("んんっ…", "んんっ…"), ("はぁ…", "ハァ…"),
                                     ("123", "123"), ("…", "…"), ("こんにちは", "你好・欢迎"),
                                     ("天界", "天界"), ("未来", "未来")]:
            with self.subTest(original=original):
                self.assertFalse(_looks_untranslated(Cue(1, 2, original), Cue(1, 2, translated), self.settings))
        self.settings.target_lang = "ja-JP"
        self.assertFalse(_looks_untranslated(Cue(1, 2, "こんにちは"), Cue(1, 2, "こんにちは"), self.settings))
        self.assertTrue(_looks_untranslated(Cue(1, 2, "んっ"), Cue(1, 2, ""), self.settings))

    def test_index_mapping_preserves_duplicate_text_and_source_timing(self):
        cues = [Cue(1, 2, "はい"), Cue(3, 4, "はい")]
        results = _merge_translation_items([
            dict(index=2, start=999, end=1000, message="好的"),
            dict(index=1, start=999, end=1000, message="是"),
        ], cues)
        self.assertEqual([cue.message for cue in results], ["是", "好的"])
        self.assertEqual([(cue.start, cue.end) for cue in results], [(1, 2), (3, 4)])

    def test_missing_rows_remain_detectable_and_unknown_rows_do_not_shift_cues(self):
        cues = [Cue(1, 2, "123"), Cue(3, 4, "ありがとう")]
        results = _merge_translation_items([
            dict(index=2, message="谢谢"), dict(index=99, message="未知"),
            dict(index=2, message="重复"),
        ], cues)
        self.assertEqual([cue.message for cue in results], ["", "谢谢"])
        self.assertTrue(_looks_untranslated(cues[0], results[0], self.settings))
        results = _merge_translation_items([dict(src_message="不存在", message="未知")], cues)
        self.assertEqual([cue.message for cue in results], ["", ""])

    def test_legacy_rows_match_duplicate_source_using_timing(self):
        cues = [Cue(1, 2, "はい"), Cue(3, 4, "はい")]
        results = _merge_translation_items([
            dict(src_message="はい", start=3, end=4, message="好的"),
            dict(src_message="はい", start=1, end=2, message="是"),
        ], cues)
        self.assertEqual([cue.message for cue in results], ["是", "好的"])
        self.assertEqual(_merge_translation_items([dict(message="无标识")], cues)[0].message, "")

    def test_invalid_output_rows_are_not_coerced_into_translation(self):
        cues = [Cue(1, 2, "こんにちは")]
        for row in [None, dict(index=True, message="你好"), dict(index="1", message="你好"),
                    dict(index=1, message=["你好"]), dict(start="broken", message="你好")]:
            with self.subTest(row=row):
                self.assertEqual(_merge_translation_items([row], cues)[0].message, "")

    def test_retry_is_per_cue_with_context_and_keeps_original_settings(self):
        cues = [Cue(1, 2, "こんにちは"), Cue(3, 4, "待って"), Cue(5, 6, "ありがとう")]
        self.settings.translate.prompt = "保留人物说话风格"
        self.settings.translate.batch_size = 8
        with patch("kt.stages.translate._translate_cues", side_effect=[
            [Cue(1, 2, "你好"), Cue(3, 4, "稍等ね"), Cue(5, 6, "谢谢")], [Cue(0, 0, "请稍等")],
        ]) as backend:
            result = translate_cues(cues, Path("synthetic-job"), self.settings)
        self.assertEqual([cue.message for cue in result], ["你好", "请稍等", "谢谢"])
        self.assertEqual((result[1].start, result[1].end), (3, 4))
        args = backend.call_args_list[1].args
        self.assertEqual(args[0], [cues[1]])
        self.assertEqual(args[2].translate.batch_size, 1)
        self.assertIn("保留人物说话风格", args[2].translate.prompt)
        self.assertIn("こんにちは", args[2].translate.prompt)
        self.assertIn("ありがとう", args[2].translate.prompt)
        self.assertEqual(self.settings.translate.batch_size, 8)
        self.assertEqual(self.settings.translate.prompt, "保留人物说话风格")

    def test_failed_retry_does_not_prevent_repairing_other_cues(self):
        cues = [Cue(1, 2, "こんにちは"), Cue(3, 4, "ありがとう")]
        with patch("kt.stages.translate._translate_cues", side_effect=[
            cues, RuntimeError("synthetic connection failure"), [Cue(3, 4, "谢谢")], [Cue(1, 2, "你好")],
        ]) as backend:
            result = translate_cues(cues, Path("synthetic-job"), self.settings)
        self.assertEqual([cue.message for cue in result], ["你好", "谢谢"])
        self.assertEqual(backend.call_count, 4)
        self.assertNotEqual(backend.call_args_list[1].args[1], backend.call_args_list[3].args[1])

    def test_persistent_untranslated_result_is_failure_with_cue_and_time(self):
        cues = [Cue(7, 8, "こんにちは")]
        with patch("kt.stages.translate._translate_cues", return_value=cues) as backend:
            with self.assertRaisesRegex(RuntimeError, r"1 \(7\.000s\).*未导出"):
                translate_cues(cues, Path("synthetic-job"), self.settings)
        self.assertEqual(backend.call_count, 3)

    def test_short_backend_result_is_not_silently_accepted(self):
        with patch("kt.stages.translate._translate_cues", return_value=[]):
            with self.assertRaisesRegex(RuntimeError, "条目数不完整"):
                translate_cues([Cue(1, 2, "こんにちは")], Path("synthetic-job"), self.settings)

    def test_cancellation_in_retry_is_never_swallowed_without_event(self):
        cues = [Cue(1, 2, "こんにちは")]
        with patch("kt.stages.translate._translate_cues", side_effect=[cues, TaskCancelled()]):
            with self.assertRaises(TaskCancelled):
                translate_cues(cues, Path("synthetic-job"), self.settings)
        stop = Event()
        def stop_after_initial(*_args, **_kwargs):
            stop.set()
            return cues
        with patch("kt.stages.translate._translate_cues", side_effect=stop_after_initial) as backend:
            with self.assertRaises(TaskCancelled):
                translate_cues(cues, Path("synthetic-job"), self.settings, stop_event=stop)
        self.assertEqual(backend.call_count, 1)

    def test_real_galtransl_serialization_preserves_indices_through_pipeline_retry(self):
        ensure_galtransl_path()
        from GalTransl.Loader import load_transList
        from GalTransl.CSerialize import update_json_with_transList
        calls = []
        async def simulated_job(workspace, settings, _stop):
            items = json.loads((workspace/"gt_input"/"cues.json").read_text(encoding="utf-8"))
            trans, originals = load_transList(items)
            calls.append(items)
            for row in trans:
                row.post_dst = "你好" if row.pre_src == "こんにちは" else (
                    "谢谢ね" if len(items) > 1 else "谢谢"
                )
            output = update_json_with_transList(trans, originals)
            (workspace/"gt_output"/"cues.json").write_text(json.dumps(output, ensure_ascii=False), encoding="utf-8")
            return SimpleNamespace(success=True, status="done")
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)/"track.lrc"
            path.write_text("[00:01.000] こんにちは\n[00:03.000] ありがとう\n", encoding="utf-8")
            self.settings.output = OutputSettings(directory=tmp, preset="target_lrc")
            with patch("kt.stages.translate._run_job", side_effect=simulated_job), patch(
                "kt.stages.translate.galtransl_cwd", return_value=nullcontext()
            ):
                result = process_file(str(path), self.settings, StageFlags(), Path(tmp)/"job", emit=lambda *_a, **_k: None)
            self.assertEqual(result.status, "done", result.error)
            text = Path(result.outputs[0]).read_text(encoding="utf-8")
            self.assertIn("[00:01.000] 你好", text)
            self.assertIn("[00:03.000] 谢谢", text)
            self.assertNotIn("ね", text)
        self.assertEqual([item["index"] for item in calls[0]], [1, 2])
        self.assertEqual(len(calls), 2)

    def test_pipeline_does_not_export_untranslated_results_as_success(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp)/"track.lrc"
            source.write_text("[00:01.000] こんにちは\n", encoding="utf-8")
            self.settings.output = OutputSettings(directory=tmp, preset="target_lrc")
            with patch("kt.stages.translate._translate_cues", return_value=[Cue(1, 4, "こんにちは")]):
                result = process_file(str(source), self.settings, StageFlags(), Path(tmp)/"job", emit=lambda *_a, **_k: None)
            self.assertEqual(result.status, "failed")
            self.assertEqual(result.outputs, [])
            self.assertFalse((Path(tmp)/"track.zh.lrc").exists())


if __name__ == "__main__":
    unittest.main()
