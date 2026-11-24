import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from build_story_index import build_index
from extract_story_text import extract_text
from mus_segmenter import segment
from mus_segmenter.segment import Morphology, h_grade, l_grade


TOOLS = Path(__file__).parent
LIFT = """<lift>
<entry id="like"><lexical-unit><form lang="mus"><text>liketv</text></form></lexical-unit>
<relation type="EntryDu" ref="kaketv"/>
<sense id="one"><grammatical-info value="verb"/></sense>
<sense id="aaa-second"><grammatical-info value="verb"/></sense></entry>
<entry id="kaketv"><lexical-unit><form lang="mus"><text>kaketv</text></form></lexical-unit>
<sense id="kake"><grammatical-info value="verb"/></sense></entry>
<entry id="he"><lexical-unit><form lang="mus"><text>hē</text></form></lexical-unit>
<sense id="three"><grammatical-info value="noun"/></sense></entry>
<entry id="ome"><lexical-unit><form lang="mus"><text>omē</text></form></lexical-unit>
<sense id="four"><grammatical-info value="adjective"/></sense></entry>
<entry id="punvn"><lexical-unit><form lang="mus"><text>punvnetv</text></form></lexical-unit>
<sense id="five"><grammatical-info value="verb"/></sense></entry>
<entry id="hvok"><lexical-unit><form lang="mus"><text>hvokē</text></form></lexical-unit>
<sense id="six"><grammatical-info value="adjective"/></sense></entry>
<entry id="no-sense"><lexical-unit><form lang="mus"><text>nene</text></form></lexical-unit></entry>
</lift>"""


class StoryIndexTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.lift = self.root / "dictionary.lift"
        self.lift.write_text(LIFT, encoding="utf-8")
        self.analyzer = Morphology(self.lift)

    def test_analysis_exact_folded_and_missing(self):
        result = build_index("HĒ, he\u0304! HE nene unknown.", self.analyzer)
        self.assertEqual(result, {
            "hē": {"stem": "hē", "sense_ids": ["he"]},
            "he": {"stem": "hē", "sense_ids": ["he"]},
            "nene": {"stem": "nene", "sense_ids": ["no-sense"]},
            "unknown": {"stem": None, "sense_ids": []},
        })

    def test_fst_models_affixes_and_stem_alternations_bidirectionally(self):
        for surface in ("likes", "likis", "likarēs", "likvs", "likvhanes", "lihkes", "liket"):
            self.assertEqual(self.analyzer.analyze(surface), ("liketv", ["like"]), surface)
            self.assertIn(surface, self.analyzer.fst.generate("liketv"))
        self.assertEqual(self.analyzer.analyze("punanes"), ("punvnetv", ["punvn"]))
        self.assertEqual(self.analyzer.analyze("omēs"), ("omē", ["ome"]))
        self.assertEqual(self.analyzer.analyze("vcomēs"), ("omē", ["ome"]))
        self.assertEqual(self.analyzer.analyze("hvokusē"), ("hvokē", ["hvok"]))
        self.assertEqual(self.analyzer.analyze("hvokuses"), ("hvokē", ["hvok"]))
        self.assertEqual(self.analyzer.analyze("kakes"), ("liketv", ["like"]))
        self.assertEqual(self.analyzer.analyze("likonsense"), (None, []))
        self.assertNotIn("liketv", self.analyzer.fst.analyze("likakes"))
        self.assertEqual(self.analyzer.analyze("likatskes"), (None, []))
        self.assertEqual(self.analyzer.analyze("hēs"), (None, []))

    def test_analysis_returns_entry_ids_for_exact_and_inflected_words(self):
        result = build_index("liketv likes", self.analyzer)
        expected = {"stem": "liketv", "sense_ids": ["like"]}
        self.assertEqual(result["liketv"], expected)
        self.assertEqual(result["likes"], expected)
        result["liketv"]["sense_ids"].clear()
        self.assertEqual(result["likes"]["sense_ids"], ["like"])

    def test_rejects_missing_or_duplicate_lift_sense_ids(self):
        self.lift.write_text(LIFT.replace('id="one"', ''), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "missing sense id"):
            Morphology(self.lift)
        self.lift.write_text(LIFT.replace('id="aaa-second"', 'id="one"'), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "duplicate sense id"):
            Morphology(self.lift)

    def test_reads_ids_across_homographic_entries(self):
        extra = (
            '<entry id="like2"><lexical-unit><form lang="mus"><text>liketv</text></form>'
            '</lexical-unit><sense id="other"/></entry>'
        )
        self.lift.write_text(LIFT.replace("</lift>", extra + "</lift>"), encoding="utf-8")
        self.assertEqual(Morphology(self.lift).analyze("liketv"), ("liketv", ["like", "like2"]))

    def test_grade_rules_handle_diphthongs_and_consonant_clusters(self):
        self.assertEqual(l_grade("punvn"), "punan")
        self.assertEqual(l_grade("homp"), "homp")
        self.assertEqual(l_grade("hopue"), "hopue")
        self.assertEqual(h_grade("hopuec"), ("hopuehc", False))
        self.assertEqual(h_grade("vok"), ("vwik", False))
        self.assertEqual(h_grade("homp"), ("homip", False))
        self.assertEqual(h_grade("lik"), ("lihk", True))

    def test_extracts_only_readalong_words_and_selected_elan_tier(self):
        path = self.root / "story.xml"
        path.write_text(
            '<read-along xmlns="urn:readalong"><text><s>'
            '<w>Hello</w>, <w>world</w>!</s>'
            '<s class="sentence__translation">not included</s></text></read-along>',
            encoding="utf-8",
        )
        self.assertEqual(extract_text(path), "Hello world\n")
        path.write_text(
            '<ANNOTATION_DOCUMENT><TIER TIER_ID="Transcription">'
            '<ANNOTATION><ALIGNABLE_ANNOTATION><ANNOTATION_VALUE>Hēsci!</ANNOTATION_VALUE>'
            '</ALIGNABLE_ANNOTATION></ANNOTATION></TIER>'
            '<TIER TIER_ID="Translation"><ANNOTATION_VALUE>Hello!</ANNOTATION_VALUE></TIER>'
            '</ANNOTATION_DOCUMENT>',
            encoding="utf-8",
        )
        self.assertEqual(extract_text(path), "Hēsci!\n")
        self.assertEqual(extract_text(path, "Translation"), "Hello!\n")
        with self.assertRaisesRegex(ValueError, "expected exactly one ELAN tier"):
            extract_text(path, "missing")

    def test_cli_writes_named_json_and_rejects_input_overwrite(self):
        source = self.root / "story.txt"
        source.write_text("Likes mystery", encoding="utf-8")
        command = [
            sys.executable, str(TOOLS / "build_story_index.py"), str(source),
            "--lexicon", str(self.lift),
        ]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads((self.root / "story.json").read_text()), {
            "likes": {"stem": "liketv", "sense_ids": ["like"]},
            "mystery": {"stem": None, "sense_ids": []},
        })
        result = subprocess.run(command + ["--output", str(self.lift)], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.lift.read_text(encoding="utf-8"), LIFT)

    def test_batch_recurses_and_detects_colliding_stems(self):
        tools = self.root / "app" / "tools"
        stories = self.root / "app" / "assets" / "readalongs"
        tools.mkdir(parents=True)
        (stories / "nested").mkdir(parents=True)
        for name in ("index_readalongs.sh", "build_story_index.py", "extract_story_text.py"):
            shutil.copy(TOOLS / name, tools / name)
        segmenter = self.root / "mus_segmenter"
        segmenter.mkdir()
        shutil.copy(Path(segment.__file__), segmenter / "segment.py")
        activation = segmenter / ".venv" / "bin" / "activate"
        activation.parent.mkdir(parents=True)
        activation.write_text("", encoding="utf-8")
        (stories / "nested" / "story.readalong").write_text(
            "<read-along><w>Likes</w></read-along>", encoding="utf-8"
        )
        command = ["bash", str(tools / "index_readalongs.sh"), "--lexicon", str(self.lift)]
        env = dict(os.environ, PATH=str(Path(sys.executable).parent) + os.pathsep + os.environ["PATH"])
        result = subprocess.run(command, capture_output=True, text=True, env=env, cwd=tools)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((stories / "nested" / "story.json").exists(), result.stdout + result.stderr)
        self.assertEqual(
            json.loads((stories / "nested" / "story.json").read_text()),
            {"likes": {"stem": "liketv", "sense_ids": ["like"]}},
        )
        (stories / "nested" / "story.eaf").write_text(
            '<ANNOTATION_DOCUMENT><TIER TIER_ID="Transcription">'
            "<ANNOTATION_VALUE>Hello</ANNOTATION_VALUE></TIER></ANNOTATION_DOCUMENT>",
            encoding="utf-8",
        )
        result = subprocess.run(command, capture_output=True, text=True, env=env, cwd=tools)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Multiple source files", result.stderr)


if __name__ == "__main__":
    unittest.main()
