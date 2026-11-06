from __future__ import annotations

import json
import re
import sys
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ENGINE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ENGINE))

from kt.cancellation import TaskCancelled
from kt.models import AppSettings, Cue
from kt.stages.translate import _translate_cues


class GalTranslIntegrationTests(unittest.TestCase):
    """Exercise the vendored engine and plugins against an actual local HTTP API."""

    def setUp(self):
        self.requests = []
        self.translator = "ForGal-json"
        owner = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def do_POST(self):
                body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                owner.requests.append((dict(self.headers), body))
                prompt = next(item["content"] for item in reversed(body["messages"]) if item["role"] == "user")
                current_input = prompt.rsplit("<input>", 1)[-1].split("</input>", 1)[0]
                if prompt == "1+1=":
                    output = "2"
                elif owner.translator == "ForGal-json":
                    rows = re.findall(r'^([a-z0-9]{3})\|(\{.*\})$', prompt, re.M)
                    output = "\n".join(
                        sig + "|" + json.dumps({"id": json.loads(row)["id"], "dst": "你好"}, ensure_ascii=False)
                        for sig, row in rows
                    )
                elif owner.translator == "ForGal-tsv":
                    rows = re.findall(r'^null\t[^\n]+\t(\d+)$', current_input, re.M)
                    output = "NAME\tDST\tID\n" + "\n".join(f"null\t你好\t{index}" for index in rows)
                elif owner.translator == "ForNovel":
                    rows = re.findall(r'^[^\t\n]+\t(\d+)$', current_input, re.M)
                    output = "DST\tID\n" + "\n".join(f"你好\t{index}" for index in rows)
                else:
                    output = "你好"

                self.send_response(200)
                if body.get("stream"):
                    self.send_header("Content-Type", "text/event-stream")
                    self.end_headers()
                    chunk = {"id": "local-test", "object": "chat.completion.chunk", "created": 0,
                             "model": "local-test", "choices": [{"index": 0, "delta": {"content": output + "\n"}, "finish_reason": None}]}
                    self.wfile.write(("data: " + json.dumps(chunk) + "\n\ndata: [DONE]\n\n").encode())
                else:
                    self.send_header("Content-Type", "application/json")
                    self.end_headers()
                    result = {"id": "local-test", "object": "chat.completion", "created": 0,
                              "model": "local-test", "choices": [{"index": 0, "message": {"role": "assistant", "content": output}, "finish_reason": "stop"}]}
                    self.wfile.write(json.dumps(result).encode())

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.worker = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.worker.start()
        self.addCleanup(self.worker.join)
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.server.shutdown)

    def settings(self, translator="ForGal-json"):
        self.translator = translator
        settings = AppSettings()
        settings.translate.translator = translator
        base = f"http://127.0.0.1:{self.server.server_port}"
        settings.translate.openai.base_url = base
        settings.translate.openai.model = "local-test"
        settings.translate.sakura_endpoint = base
        settings.translate.sakura_model = "local-test"
        settings.translate.batch_size = 1
        return settings

    def run_translation(self, settings, workspace):
        cues = [Cue(start=1, end=2, message="こんにちは"), Cue(start=3, end=4, message="こんにちは")]
        result = _translate_cues(cues, workspace, settings)
        self.assertEqual([cue.message for cue in result], ["你好", "你好"])
        self.assertEqual([(cue.start, cue.end) for cue in result], [(1, 2), (3, 4)])
        return result

    def test_index_headers_prompt_and_cache_resume(self):
        settings = self.settings()
        settings.translate.index_compat = True
        settings.translate.openai.api_key = "sk-local-test"
        settings.translate.prompt = "保留字幕语气"
        with tempfile.TemporaryDirectory() as tmp:
            workspace = Path(tmp)
            self.run_translation(settings, workspace)
            self.assertEqual(len(self.requests), 3)  # availability check + two batches
            for headers, body in self.requests:
                self.assertEqual(headers["User-Agent"], "Index-Translate-Client/1.0")
                self.assertNotIn("Authorization", headers)
                self.assertEqual(body["chat_template_kwargs"], {"enable_thinking": False})
            self.assertIn(settings.translate.prompt, self.requests[1][1]["messages"][-1]["content"])
            self.assertTrue(list((workspace / "transl_cache").glob("*.json")))
            self.requests.clear()
            self.run_translation(settings, workspace)
            self.assertEqual(self.requests, [])

    def test_online_thinking_and_prompt_overwrite(self):
        settings = self.settings()
        settings.translate.enable_thinking = False
        settings.translate.prompt_mode = "overwrite"
        settings.translate.prompt = "字幕翻译：\n[Input]"
        with tempfile.TemporaryDirectory() as tmp:
            self.run_translation(settings, Path(tmp))
        self.assertEqual(len(self.requests), 2)
        for headers, body in self.requests:
            self.assertIn("Authorization", headers)
            self.assertEqual(body["thinking"], {"type": "disabled"})
        self.assertTrue(self.requests[0][1]["messages"][-1]["content"].startswith("字幕翻译："))

    def test_legacy_tsv_and_novel_and_sakura(self):
        for translator in ("ForGal-tsv", "ForNovel", "sakura-v1.0", "galtransl-v3"):
            with self.subTest(translator=translator), tempfile.TemporaryDirectory() as tmp:
                self.requests.clear()
                self.run_translation(self.settings(translator), Path(tmp))
                self.assertEqual(len(self.requests), 2)

    def test_real_job_honours_cancellation(self):
        stop = threading.Event()
        stop.set()
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(TaskCancelled):
                _translate_cues([Cue(start=1, end=2, message="こんにちは")], Path(tmp), self.settings(), stop_event=stop)
        self.assertEqual(self.requests, [])


if __name__ == "__main__":
    unittest.main()
