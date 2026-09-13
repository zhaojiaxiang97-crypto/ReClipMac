"""Build-time tests of the bundled adapter using the pinned development Python."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest

adapter_path = Path(__file__).resolve().parents[1] / "runtime/python/reclip_ytdlp/__init__.py"
spec = importlib.util.spec_from_file_location("reclip_ytdlp", adapter_path)
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


class AdapterTests(unittest.TestCase):
    def test_probe(self):
        result = json.loads(adapter.run('{"operation":"probe"}', lambda: False))
        self.assertTrue(result["ok"])
        self.assertEqual(result["payload"]["python"], "3.13.15")
        self.assertEqual(result["payload"]["ytDlp"], "2026.08.19")

    def test_cancel_before_work(self):
        result = json.loads(adapter.run('{"operation":"probe"}', lambda: True))
        self.assertEqual(result["code"], "cancelled")

    def test_process_blocked(self):
        with self.assertRaisesRegex(RuntimeError, "external-process-disabled"):
            subprocess.run([sys.executable, "-c", "raise SystemExit(91)"], check=False)

    def test_no_user_plugins(self):
        self.assertEqual(adapter.plugin_dirs.value, [])

    def test_url_redaction(self):
        self.assertNotIn("private-token", adapter._safe_error(ValueError("HTTP error: https://a.example/file?private-token=1")))


if __name__ == "__main__":
    unittest.main()
