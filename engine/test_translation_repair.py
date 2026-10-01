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
from kt.stages.translation_result import TranslationReview, UNTRANSLATED_REPORT_NAME


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

    def test_three_failed_repairs_preserve_result_and_record_position(self):
        cues = [Cue(7, 8, "こんにちは")]
        review = TranslationReview()
        with patch("kt.stages.translate._translate_cues", return_value=cues) as backend:
            result = translate_cues(cues, Path("synthetic-job"), self.settings, review=review)
        self.assertEqual(backend.call_count, 4)
        self.assertEqual(result[0].message, "こんにちは")
        self.assertEqual((review.entries[0]["index"], review.entries[0]["start"], review.entries[0]["attempts"]), (1, 7, 3))

    def test_third_repair_can_succeed_without_remaining_issue(self):
        cues = [Cue(1, 2, "こんにちは")]
        review = TranslationReview()
        with patch("kt.stages.translate._translate_cues", side_effect=[
            cues, cues, cues, [Cue(1, 2, "你好")],
        ]) as backend:
            result = translate_cues(cues, Path("synthetic-job"), self.settings, review=review)
        self.assertEqual(backend.call_count, 4)
        self.assertEqual(result[0].message, "你好")
        self.assertEqual(review.entries, [])

    def test_empty_output_falls_back_to_original_after_failed_requests(self):
        cues = [Cue(1, 2, "123")]
        review = TranslationReview()
        with patch("kt.stages.translate._translate_cues", side_effect=[
            [Cue(1, 2, "")], RuntimeError("offline"), RuntimeError("offline"), RuntimeError("offline"),
        ]) as backend:
            result = translate_cues(cues, Path("synthetic-job"), self.settings, review=review)
        self.assertEqual(backend.call_count, 4)
        self.assertEqual(result[0].message, "123")
        self.assertEqual(review.entries[0]["output"], "123")

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

    def test_pipeline_exports_untranslated_results_with_directory_report(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp)/"track.lrc"
            source.write_text("[00:01.000] こんにちは\n", encoding="utf-8")
            self.settings.output = OutputSettings(directory=tmp, preset="target_lrc")
            with patch("kt.stages.translate._translate_cues", return_value=[Cue(1, 4, "こんにちは")]):
                result = process_file(str(source), self.settings, StageFlags(), Path(tmp)/"job", emit=lambda *_a, **_k: None)
            self.assertEqual(result.status, "done", result.error)
            self.assertEqual(len(result.outputs), 2)
            self.assertIn("こんにちは", (Path(tmp)/"track.zh.lrc").read_text(encoding="utf-8"))
            record = Path(result.outputs[1])
            self.assertEqual(record.name, UNTRANSLATED_REPORT_NAME)
            text = record.read_text(encoding="utf-8")
            self.assertIn("第 1 条，时间 1.000s → 4.000s", text)
            self.assertIn("补译 3 次", text)
            self.assertIn("track.zh.lrc", text)
            self.assertIn("仍有 1 条疑似漏译", result.message)

    def test_multiple_lyrics_append_to_one_report_in_processing_order(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.settings.output = OutputSettings(directory=tmp, preset="target_lrc")
            results = []
            for name in ["first", "second"]:
                source = Path(tmp)/f"{name}.lrc"
                source.write_text("[00:07.000] こんにちは\n", encoding="utf-8")
                with patch("kt.stages.translate._translate_cues", return_value=[Cue(7, 10, "こんにちは")]):
                    results.append(process_file(str(source), self.settings, StageFlags(), Path(tmp)/name,
                                                emit=lambda *_a, **_k: None))
            self.assertTrue(all(result.status == "done" for result in results))
            self.assertEqual(results[0].outputs[1], results[1].outputs[1])
            self.assertEqual(len(list(Path(tmp).glob("*.txt"))), 1)
            text = Path(results[0].outputs[1]).read_text(encoding="utf-8")
            self.assertLess(text.index("first.zh.lrc"), text.index("second.zh.lrc"))
            self.assertEqual(text.count("未翻译位置记录（按处理顺序追加）"), 1)

    def test_successful_lyrics_do_not_create_or_clear_existing_report(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp)/"track.lrc"
            source.write_text("[00:01.000] こんにちは\n", encoding="utf-8")
            self.settings.output = OutputSettings(directory=tmp, preset="target_lrc")
            def run_success():
                with patch("kt.stages.translate._translate_cues", return_value=[Cue(1, 4, "你好")]):
                    return process_file(str(source), self.settings, StageFlags(), Path(tmp)/"job",
                                        emit=lambda *_a, **_k: None)
            result = run_success()
            self.assertEqual(result.status, "done", result.error)
            self.assertEqual(len(result.outputs), 1)
            report = Path(tmp)/UNTRANSLATED_REPORT_NAME
            self.assertFalse(report.exists())
            report.write_text("此前歌词的漏译记录\n", encoding="utf-8")
            result = run_success()
            self.assertEqual(len(result.outputs), 1)
            self.assertEqual(report.read_text(encoding="utf-8"), "此前歌词的漏译记录\n")

    def test_existing_directory_report_is_appended_and_other_directories_are_separate(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            report = folder/UNTRANSLATED_REPORT_NAME
            report.write_text("之前的记录\n", encoding="utf-8")
            review = TranslationReview(source_file="current.lrc")
            review.add(2, Cue(3, 4, "待って"), Cue(3, 4, "稍等ね"), 3)
            self.assertEqual(review.write(folder/"current.zh.lrc"), str(report))
            text = report.read_text(encoding="utf-8")
            self.assertTrue(text.startswith("之前的记录\n"))
            self.assertIn("稍等ね", text)
            other = folder/"other"
            other.mkdir()
            self.assertEqual(Path(review.write(other/"current.zh.srt")).parent, other)
            self.assertEqual(report.read_text(encoding="utf-8"), text)

    def test_directory_report_appends_whole_blocks_for_concurrent_jobs(self):
        from concurrent.futures import ThreadPoolExecutor
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            def append(index):
                review = TranslationReview(source_file=f"track-{index}.lrc")
                review.add(index, Cue(index, index+1, "待って"), Cue(index, index+1, "待って"), 3)
                return review.write(folder/f"track-{index}.zh.lrc")
            with ThreadPoolExecutor(max_workers=4) as pool:
                outputs = list(pool.map(append, range(1, 9)))
            self.assertEqual(len(set(outputs)), 1)
            text = Path(outputs[0]).read_text(encoding="utf-8")
            self.assertEqual(text.count("未翻译位置记录（按处理顺序追加）"), 1)
            self.assertEqual(text.count("记录时间："), 8)
            for index in range(1, 9):
                self.assertIn(f"track-{index}.zh.lrc", text)

    def test_cancellation_does_not_export_or_append_an_untranslated_report(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp)/"track.lrc"
            source.write_text("[00:01.000] こんにちは\n", encoding="utf-8")
            self.settings.output = OutputSettings(directory=tmp, preset="target_lrc")
            with patch("kt.stages.translate._translate_cues", side_effect=[
                [Cue(1, 4, "こんにちは")], TaskCancelled(),
            ]):
                result = process_file(str(source), self.settings, StageFlags(), Path(tmp)/"job",
                                      emit=lambda *_a, **_k: None)
            self.assertEqual(result.status, "cancelled")
            self.assertFalse((Path(tmp)/"track.zh.lrc").exists())
            self.assertFalse((Path(tmp)/UNTRANSLATED_REPORT_NAME).exists())


if __name__ == "__main__":
    unittest.main()
