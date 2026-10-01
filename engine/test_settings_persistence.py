from __future__ import annotations

import json
import sys
import tempfile
import threading
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
from urllib.request import ProxyHandler, Request, build_opener

ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from kt.models import AppSettings, StageFlags
from kt.recent import list_recent_jobs, record_finished_job
from kt.settings import load_settings, save_settings
from server import Handler, _EngineHTTPServer


def fixture() -> dict:
    return {
        "ffmpeg_path": "工具/ffmpeg.exe", "ffprobe_path": "工具/ffprobe.exe",
        "crispasr_dir": "模型/asr", "llama_dir": "模型/llama", "llama_model": "demo.gguf",
        "proxy": "", "theme": "dark", "remote_access": True,
        "remote_username": "tester", "remote_password": "test-password",
        "source_lang": "en", "target_lang": "ja",
        "flags": {"enable_correct": True, "enable_translate": False},
        "asr": {
            "model": "asr.gguf", "aligner": "aligner.gguf", "backend": "whisper",
            "language": "en", "extra_args": "--threads 9 --custom-option abc",
            "threads": 9, "processors": 2, "offset_t": 123, "offset_n": 2,
            "duration": 500, "max_context": 1024, "max_len": 50,
            "hotwords": "hello world", "beam_size": "5", "best_of": 7,
            "audio_ctx": 3, "word_thold": 0.05, "entropy_thold": 1.4,
            "logprob_thold": -0.5, "no_speech_thold": 0.4,
            "sensitivity": "aggressive", "seed": 42, "temperature_inc": 0.3,
            "no_fallback": True, "no_punctuation": True,
            "punc_model": "custom-punc", "truecase_model": "custom-case",
            "flush_after": 0, "chunk_seconds": 40, "chunk_overlap": 2.5,
            "no_gpu": True, "device": 2, "gpu_backend": "cpu", "flash_attn": False,
            "enable_vad": False, "vad_max_speech_duration_s": 12,
            "vad_min_silence_duration_ms": 200, "max_new_tokens": 700,
            "frequency_penalty": 0.7, "repetition_penalty": 1.3,
            "condition_on_previous_text": False, "temperature": 0.4,
            "split_on_punct": False, "split_on_word": True,
            "vad_model": "silero", "vad_threshold": 0.7, "force_aligner": False,
        },
        "correct": {
            "provider": "local_llama", "base_url": "https://correct.example/v1",
            "model": "correct-model", "api_key": "test-correct-key", "prompt": "校对规则",
            "temperature": 0.6, "max_tokens": 2048, "enable_thinking": True,
        },
        "translate": {
            "provider": "online", "translator": "ForGal-tsv",
            "openai": {"base_url": "https://translate.example/v1", "model": "translate-model", "api_key": "test-translate-key"},
            "sakura_endpoint": "http://127.0.0.1:8888", "sakura_model": "sakura-test",
            "prompt_mode": "overwrite", "prompt": "翻译规则", "context_num": 5,
            "batch_size": 6, "token_limit": 2000, "enable_thinking": False,
        },
        "output": {
            "directory": "导出目录", "preset": "source_target_srt", "formats": ["srt"],
            "bilingual": True, "keep_gt_cache": False, "suffix": ".ja",
            "lls_sync": True, "lls_url": "https://lls.example", "lls_auth_mode": "basic",
            "lls_username": "test-user", "lls_password": "test-password", "lls_key": "test-key-123",
        },
        "dict_pre": "字典/译前.txt", "dict_gpt": "字典/gpt.txt", "dict_after": "字典/译后.txt",
    }


class SettingsPersistenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="kt_settings_test_")
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.settings_path = self.directory / "settings.json"
        self.data_patch = patch("kt.settings.DATA_DIR", self.directory)
        self.path_patch = patch("kt.settings.SETTINGS_PATH", self.settings_path)
        self.data_patch.start()
        self.path_patch.start()
        self.addCleanup(self.data_patch.stop)
        self.addCleanup(self.path_patch.stop)

    def test_every_settings_section_survives_real_file_round_trip(self):
        payload = fixture()
        saved = save_settings(AppSettings.from_dict(payload))
        restored = load_settings().to_dict()
        self.assertEqual(restored, saved.to_dict())
        self.assertEqual(json.loads(self.settings_path.read_text(encoding="utf-8")), restored)
        for section in ("flags", "correct", "translate", "output"):
            self.assertEqual(restored[section], payload[section])
        for key, value in payload["asr"].items():
            with self.subTest(asr_field=key):
                self.assertEqual(restored["asr"][key], value)
        for key in ("theme", "proxy", "remote_access", "remote_password", "dict_pre", "dict_gpt", "dict_after"):
            self.assertEqual(restored[key], payload[key])

    def test_optional_fields_can_be_cleared_in_the_saved_file(self):
        payload = fixture()
        save_settings(AppSettings.from_dict(payload))
        for key in ("ffmpeg_path", "ffprobe_path", "crispasr_dir", "llama_dir", "llama_model", "proxy", "dict_pre", "dict_gpt", "dict_after"):
            payload[key] = ""
        for section in (payload["correct"], payload["translate"]["openai"]):
            for key in ("base_url", "model", "api_key"):
                section[key] = ""
        payload["correct"]["prompt"] = ""
        payload["translate"]["prompt"] = ""
        for key in ("directory", "suffix", "lls_url", "lls_username", "lls_password", "lls_key"):
            payload["output"][key] = ""
        save_settings(AppSettings.from_dict(payload))
        self.assertEqual(load_settings().to_dict(), AppSettings.from_dict(payload).to_dict())

    def test_http_settings_survive_server_recreation(self):
        opener = build_opener(ProxyHandler({}))
        payload = fixture()
        expected = AppSettings.from_dict(payload).to_dict()
        for index in range(2):
            server = _EngineHTTPServer(("127.0.0.1", 0), Handler)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            url = f"http://127.0.0.1:{server.server_address[1]}/api/settings"
            try:
                if index == 0:
                    request = Request(url, data=json.dumps(payload).encode(), method="PUT", headers={"content-type": "application/json"})
                    with opener.open(request, timeout=5) as response:
                        self.assertEqual(json.load(response), expected)
                with opener.open(url, timeout=5) as response:
                    self.assertEqual(json.load(response), expected)
            finally:
                server.shutdown()
                server.server_close()
                thread.join(timeout=5)

    def test_recent_results_survive_reopening_from_disk(self):
        work = self.directory / "work"
        job_id = "123456abcdef"
        folder = work / job_id
        folder.mkdir(parents=True)
        output = folder / "字幕.lrc"
        output.write_text("[00:01.00]测试", encoding="utf-8")
        job = SimpleNamespace(
            job_id=job_id, source="desktop", status="done", created_at="2026-10-01T00:00:00+00:00",
            flags=StageFlags(enable_translate=True), files=["输入.mp3"],
            results=[SimpleNamespace(outputs=[str(output)])],
        )
        with patch("kt.recent.WORK_DIR", work):
            record_finished_job(job)
            restored = list_recent_jobs()
        self.assertEqual(len(restored), 1)
        self.assertEqual(restored[0]["job_id"], job_id)
        self.assertEqual(restored[0]["files"], ["输入.mp3"])
        self.assertEqual(restored[0]["outputs"], [{"path": str(output), "exists": True}])


if __name__ == "__main__":
    unittest.main()
