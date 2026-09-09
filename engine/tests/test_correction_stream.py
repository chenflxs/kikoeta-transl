import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from kt.models import CorrectionSettings
from kt.stages.correct import _chat, _collect_chat_stream, _extract_chat_content


def sse(*chunks):
    return "".join("data: " + json.dumps(chunk) + "\n\n" for chunk in chunks)


class CorrectionStreamTests(unittest.TestCase):
    def test_kimi_stream_reassembles_text_and_uses_configured_budget(self):
        payload = sse(
            {"choices": [{"index": 0, "delta": {"reasoning_content": "private reasoning"}}]},
            {"choices": [{"index": 0, "delta": {"content": '["こん'}}]},
            {"choices": [{"index": 0, "delta": {"content": 'にちは"]'}, "finish_reason": "stop"}]},
            {"choices": [], "usage": {"completion_tokens": 25}},
        ) + "data: [DONE]\n\n"
        response = httpx.Response(200, text=payload, headers={"content-type": "text/event-stream"},
                                  request=httpx.Request("POST", "https://example.test/v1/chat/completions"))
        settings = CorrectionSettings(base_url="https://example.test", model="kimi-k2.5", max_tokens=8192)
        with patch("httpx.stream") as stream, patch("httpx.post") as post:
            stream.return_value.__enter__.return_value = response
            self.assertEqual(_chat(settings, "input", ""), '["こんにちは"]')
        post.assert_not_called()
        self.assertEqual(stream.call_args.kwargs["json"]["max_tokens"], 8192)
        self.assertNotIn("temperature", stream.call_args.kwargs["json"])
        self.assertEqual(stream.call_args.kwargs["json"]["thinking"], {"type": "disabled"})

    def test_truncated_stream_is_not_accepted_as_complete(self):
        lines = sse({"choices": [{"delta": {"content": '["hello"]'}}]}).splitlines()
        with self.assertRaisesRegex(RuntimeError, "中断"):
            _collect_chat_stream(lines)

    def test_heartbeat_cannot_keep_request_alive_forever(self):
        with patch("time.monotonic", side_effect=[0, 601]):
            with self.assertRaisesRegex(RuntimeError, "10 分钟"):
                _collect_chat_stream([": heartbeat"])

    def test_reasoning_is_never_used_as_corrected_text(self):
        lines = sse({"choices": [{"delta": {"reasoning_content": '["hello"]'}, "finish_reason": "stop"}]}).splitlines()
        with self.assertRaisesRegex(RuntimeError, "推理字符数=9"):
            _extract_chat_content(_collect_chat_stream(lines))

    def test_stream_filter_and_errors_remain_failures(self):
        lines = sse({"choices": [{"delta": {}, "finish_reason": "content_filter"}]}).splitlines()
        with self.assertRaisesRegex(RuntimeError, "安全策略"):
            _extract_chat_content(_collect_chat_stream(lines))
        with self.assertRaisesRegex(RuntimeError, "报告错误"):
            _collect_chat_stream(sse({"error": {"message": "upstream failed"}}).splitlines())

    def test_kimi_gateway_may_return_normal_json(self):
        response = httpx.Response(200, json={"choices": [{"message": {"content": "ok"}}]},
                                  request=httpx.Request("POST", "https://example.test/v1/chat/completions"))
        with patch("httpx.stream") as stream:
            stream.return_value.__enter__.return_value = response
            self.assertEqual(_chat(CorrectionSettings(base_url="https://example.test", model="kimi-k2.5"), "input", ""), "ok")


if __name__ == "__main__":
    unittest.main()
