import unittest

from GalTransl.COpenAI import normalize_sakura_endpoints


class SakuraEndpointNormalizationTests(unittest.TestCase):
    def test_normalizes_endpoint_list(self) -> None:
        self.assertEqual(
            normalize_sakura_endpoints(
                {
                    "endpoints": [
                        " http://127.0.0.1:8501 ",
                        "",
                        "http://127.0.0.1:8501",
                        "http://127.0.0.1:8502",
                        None,
                    ]
                }
            ),
            ["http://127.0.0.1:8501", "http://127.0.0.1:8502"],
        )

    def test_accepts_legacy_single_endpoint(self) -> None:
        self.assertEqual(
            normalize_sakura_endpoints({"endpoint": " http://127.0.0.1:8503/ "}),
            ["http://127.0.0.1:8503/"],
        )

    def test_accepts_string_endpoints_value(self) -> None:
        self.assertEqual(
            normalize_sakura_endpoints({"endpoints": " http://127.0.0.1:8504 "}),
            ["http://127.0.0.1:8504"],
        )

    def test_uses_worker_endpoint_fallback_before_default(self) -> None:
        self.assertEqual(
            normalize_sakura_endpoints({"endpoints": []}, " http://127.0.0.1:8505 "),
            ["http://127.0.0.1:8505"],
        )

    def test_uses_default_when_all_entries_are_empty(self) -> None:
        self.assertEqual(
            normalize_sakura_endpoints({"endpoints": ["", "   ", None]}),
            ["http://127.0.0.1:8501"],
        )


if __name__ == "__main__":
    unittest.main()
