import json
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))

from kt.models import AppSettings, CorrectionSettings, Cue, OutputSettings, StageFlags
from kt.pipeline import process_file
from kt.stages.correct import correct_cues
from kt.stages.correction_result import CorrectionReview, parse_correction_response


def response(*items):
    return json.dumps(items, ensure_ascii=False)


def decision(text, needs_review=False, reason=""):
    return dict(text=text, needs_review=needs_review, reason=reason)


class CorrectionReviewTests(unittest.TestCase):
    def test_uncertain_candidate_is_not_written_into_subtitle(self):
        cues = [Cue(1, 2, "展開に帰ります"), Cue(3, 4, "先生、たまたま…")]
        parsed = parse_correction_response(response(
            decision("天界に帰ります", reason="天使返回的场景支持同音词天界"),
            decision("先生、田中様…", True, "称呼无法确定，需回听"),
        ), cues)
        self.assertEqual([item.text for item in parsed], ["天界に帰ります", cues[1].message])
        self.assertFalse(parsed[0].needs_review)
        self.assertTrue(parsed[1].needs_review)

    def test_model_reformatting_is_rejected_without_losing_other_corrections(self):
        originals = ["一行\n二行", " 本文 ", "何ですか?", "名前…", "one two", "何ですか?"]
        candidates = ["一行二行", "本文", "何ですか？", "名前", "onetwo ", "?何ですか"]
        for original, candidate in zip(originals, candidates):
            with self.subTest(original=original):
                parsed = parse_correction_response(response(
                    decision(candidate, reason="格式修改"),
                    decision("天界", reason="场景支持同音词天界"),
                ), [Cue(1, 2, original), Cue(3, 4, "展開")])
                self.assertEqual(parsed[0].text, original)
                self.assertTrue(parsed[0].needs_review)
                self.assertEqual(parsed[1].text, "天界")

    def test_pure_nonverbal_and_missing_evidence_remain_original(self):
        cues = [Cue(1, 2, "んんっ"), Cue(3, 4, "展開")]
        parsed = parse_correction_response(response(
            decision("こんにちは", reason="改写气声"), decision("天界"),
        ), cues)
        self.assertEqual([item.text for item in parsed], [item.message for item in cues])
        self.assertTrue(all(item.needs_review for item in parsed))

    def test_remaining_damage_is_reported_even_if_model_claims_no_issue(self):
        cue = Cue(1, 2, "こ�にちは")
        parsed = parse_correction_response(response(decision(cue.message)), [cue])
        self.assertEqual(parsed[0].text, cue.message)
        self.assertTrue(parsed[0].needs_review)

    def test_review_fields_are_validated(self):
        source = [Cue(1, 2, "原文")]
        malformed = [
            [], [dict(text="原文", needs_review="false")],
            [dict(text="原文", needs_review=0)],
            [dict(text="原文", needs_review=False, reason=[])],
            [dict(text="", needs_review=True, reason="复核")], [3],
        ]
        for payload in malformed:
            with self.subTest(payload=payload):
                with self.assertRaises(RuntimeError):
                    parse_correction_response(json.dumps(payload), source)

    def test_legacy_response_does_not_claim_review_was_performed(self):
        cue = Cue(1, 2, "展開")
        for payload in ('["天界"]', '[00:99.000] 天界',
                        '1\n99:99:99,999 --> 00:00:00,000\n天界'):
            with self.subTest(payload=payload):
                parsed = parse_correction_response(payload, [cue])
                self.assertEqual(parsed[0].text, "天界")
                self.assertFalse(parsed[0].assessed)
                self.assertEqual((cue.start, cue.end), (1, 2))

    def test_batches_keep_uncertain_originals_in_context_and_report_indices(self):
        cues = [Cue(i*2, i*2+1, f"原文{i}") for i in range(11)]
        first = [decision(c.message) for c in cues[:10]]
        first[9] = decision("猜测9", True, "需回听")
        report = CorrectionReview(source_file="demo.srt")
        settings = AppSettings(correct=CorrectionSettings(base_url="https://example.test", model="demo"))
        with patch("kt.stages.correct._chat", side_effect=[
            json.dumps(first), response(decision("修正10", reason="明确同音错词")),
        ]) as chat:
            corrected = correct_cues(cues, settings, review=report)
        self.assertIn("原文9", chat.call_args_list[1].args[1])
        self.assertNotIn("猜测9", chat.call_args_list[1].args[1])
        self.assertEqual(corrected[9].message, "原文9")
        self.assertEqual(corrected[10].message, "修正10")
        self.assertEqual([item["index"] for item in report.entries], [10, 11])
        self.assertEqual((report.changed_count, report.review_count), (1, 1))
        self.assertEqual([(c.start, c.end) for c in corrected], [(c.start, c.end) for c in cues])

    def test_report_survives_export_and_is_listed_with_subtitle(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "track.srt"
            path.write_text("1\n00:00:01,000 --> 00:00:03,000\n展開\n\n"
                            "2\n00:00:02,000 --> 00:00:04,000\n先生、たまたま…\n", encoding="utf-8")
            settings = AppSettings(
                correct=CorrectionSettings(base_url="https://example.test", model="demo"),
                output=OutputSettings(directory=tmp, preset="target_srt"),
            )
            events = []
            with patch("kt.stages.correct._chat", return_value=response(
                decision("天界", reason="天使返回天界的同音误识"),
                decision("田中先生", True, "称呼不明确"),
            )):
                result = process_file(str(path), settings, StageFlags(enable_correct=True, enable_translate=False),
                    Path(tmp)/"job", emit=lambda event, **payload: events.append((event, payload)))
            self.assertEqual(result.status, "done", result.error)
            self.assertEqual(len(result.outputs), 2)
            subtitle, report_path = map(Path, result.outputs)
            self.assertEqual(subtitle.name, "track.fix.srt")
            self.assertEqual(report_path.name, "track.fix.correction.json")
            report = json.loads(report_path.read_text(encoding="utf-8"))
            self.assertEqual((report["changed_cue_count"], report["review_cue_count"]), (1, 1))
            self.assertEqual(report["mode"], "text_only")
            self.assertEqual(len(report["timing_notes"]), 1)
            self.assertIn("先生、たまたま…", subtitle.read_text(encoding="utf-8"))
            self.assertNotIn("田中先生", subtitle.read_text(encoding="utf-8"))
            done = [payload for event, payload in events if event == "file_done"]
            self.assertEqual(done[0]["outputs"], result.outputs)
            self.assertTrue(all(Path(output).is_file() for output in result.outputs))

    def test_legacy_report_records_changes_without_asserting_accuracy(self):
        report = CorrectionReview()
        cue = Cue(1, 2, "展開")
        report.prepare([cue], [cue], "demo")
        report.add([cue], parse_correction_response('["天界"]', [cue]), 0)
        self.assertEqual(report.unassessed_count, 1)
        self.assertFalse(report.entries[0]["review_assessed"])
        self.assertEqual(report.entries[0]["original"], "展開")

    def test_translation_export_keeps_report_in_source_language(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp)/"track.lrc"
            source.write_text("[00:01.000] 展開に帰ります\n", encoding="utf-8")
            settings = AppSettings(
                correct=CorrectionSettings(base_url="https://example.test", model="demo"),
                output=OutputSettings(directory=tmp, preset="target_lrc"),
            )
            with patch("kt.stages.correct._chat", return_value=response(
                decision("天界に帰ります", reason="同音词符合天使返回天界的场景"),
            )), patch("kt.stages.translate.translate_cues", return_value=[
                Cue(1, 4, "返回天界", src_message="天界に帰ります"),
            ]) as translate:
                result = process_file(str(source), settings,
                    StageFlags(enable_correct=True, enable_translate=True), Path(tmp)/"job",
                    emit=lambda *_args, **_kwargs: None)
            self.assertEqual(result.status, "done", result.error)
            self.assertEqual(translate.call_args.args[0][0].message, "天界に帰ります")
            report = json.loads(Path(result.outputs[1]).read_text(encoding="utf-8"))
            self.assertEqual(report["entries"][0]["corrected"], "天界に帰ります")
            self.assertEqual(Path(result.outputs[1]).name, "track.zh.correction.json")
            self.assertIn("返回天界", Path(result.outputs[0]).read_text(encoding="utf-8"))

    def test_report_is_not_uploaded_or_cached_as_a_lyric(self):
        from kt import kikoeta_cache, lls_sync
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            lyric, report = folder/"track.lrc", folder/"track.correction.json"
            lyric.write_text("[00:01.00] 文本\n", encoding="utf-8")
            report.write_text('{"mode":"text_only"}', encoding="utf-8")
            job = SimpleNamespace(job_id="review-test", source="kikoeta", status="completed",
                cache_context=dict(work_id="RJ123", track_paths=["track.mp3"]),
                results=[SimpleNamespace(outputs=[str(report), str(lyric)])])
            with patch.object(kikoeta_cache, "CACHE_DIR", folder/"cache"), patch.object(
                kikoeta_cache, "INDEX_PATH", folder/"cache"/"index.json"
            ):
                self.assertEqual(kikoeta_cache.cache_completed_job(job), 1)
                self.assertEqual(kikoeta_cache.cached_file("review-test", 0).read_text(encoding="utf-8"),
                                 lyric.read_text(encoding="utf-8"))
            with patch("kt.lls_sync._upload_lyric") as upload:
                self.assertEqual(lls_sync.sync_completed_job(job,
                    OutputSettings(lls_sync=True, lls_key="a1B2c3D4e5F6")), 1)
            self.assertEqual(upload.call_count, 1)
            self.assertEqual(upload.call_args.args[-1], lyric.read_bytes())

    def test_report_distinguishes_input_timing_from_normalized_cues(self):
        cues = [Cue(2, 2, "正文"), Cue(1, 1.5, "展開"), Cue(1, 2, "に帰る")]
        report = CorrectionReview()
        settings = AppSettings(correct=CorrectionSettings(base_url="https://example.test", model="demo"))
        with patch("kt.stages.correct._chat", return_value=response(
            decision("天界 に帰る", reason="同音词语境校订"), decision("正文"),
        )):
            corrected = correct_cues(cues, settings, review=report)
        self.assertEqual((report.input_count, report.output_count), (3, 2))
        self.assertEqual(report.timing_notes[0]["index_scope"], "input")
        self.assertEqual((report.timing_notes[0]["index"], report.timing_notes[0]["end"]), (1, 2))
        self.assertEqual(cues[0].end, 2)
        self.assertEqual(corrected[0].start, 1)
        self.assertEqual(corrected[0].src_message, "展開 に帰る")

    def test_invalid_timing_can_still_be_saved_in_review_json(self):
        cues = [Cue(1, float("nan"), "原文"), Cue(2, float("inf"), "原文")]
        report = CorrectionReview()
        report.prepare(cues, cues, "demo")
        report.add(cues, parse_correction_response(response(
            decision("原文", True, "需要回听"), decision("原文", True, "需要回听"),
        ), cues), 0)
        with tempfile.TemporaryDirectory() as tmp:
            destination = report.write(Path(tmp)/"track.lrc")
            payload = json.loads(Path(destination).read_text(encoding="utf-8"))
        self.assertTrue(all(item["end"] is None for item in payload["entries"]))
        self.assertEqual(len(payload["timing_notes"]), 2)
        self.assertTrue(all(item["issue"] == "时间值不是有限数" for item in payload["timing_notes"]))


if __name__ == "__main__":
    unittest.main()
