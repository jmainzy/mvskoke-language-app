import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("build_sense_index.py")


class BuildSenseIndexTests(unittest.TestCase):
    def run_script(self, source_text):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source.jsonl"
            output = Path(directory) / "index.json"
            source.write_text(source_text, encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(SCRIPT), str(source), "--output", str(output)],
                capture_output=True,
                text=True,
            )
            content = output.read_text(encoding="utf-8") if output.exists() else None
        return result, content

    def test_preserves_unicode_and_null_definitions(self):
        result, content = self.run_script(
            '{"sense_id":"one","headword":"ē","definition":"first"}\n\n'
            '{"sense_id":"two","headword":"second","definition":null}\n'
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(content),
            {
                "one": {"headword": "ē", "definition": "first"},
                "two": {"headword": "second", "definition": None},
            },
        )
        self.assertIn("ē", content)

    def test_rejects_duplicate_ids_without_writing_output(self):
        result, content = self.run_script(
            '{"sense_id":"one","headword":"word","definition":"first"}\n'
            '{"sense_id":"one","headword":"word","definition":"second"}\n'
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("duplicate sense_id", result.stderr)
        self.assertIsNone(content)

    def test_rejects_missing_definition(self):
        result, content = self.run_script('{"sense_id":"one","headword":"word"}\n')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("expected a string or null definition", result.stderr)
        self.assertIsNone(content)

    def test_rejects_missing_headword(self):
        result, content = self.run_script('{"sense_id":"one","definition":"first"}\n')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("expected a non-empty headword", result.stderr)
        self.assertIsNone(content)


if __name__ == "__main__":
    unittest.main()
