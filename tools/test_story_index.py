import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from build_story_index import build_index, read_dictionary, read_overrides, tokenize
from extract_story_text import extract_text


TOOLS = Path(__file__).parent
LIFT = """<lift>
<entry id="night1"><lexical-unit><form lang="mus"><text>nerē</text></form></lexical-unit>
<sense><definition><form lang="en"><text>night <span>time</span></text></form>
<form lang="mus"><text>not English</text></form></definition></sense>
<sense><definition><form lang="en"><text>darkness</text></form></definition></sense>
<relation type="_component-lexeme" ref="variant">
<trait name="variant-type" value="Free Variant"/></relation></entry>
<entry id="night2"><lexical-unit><form lang="mus"><text>nerē</text></form></lexical-unit>
<sense><definition><form lang="en"><text>another night</text></form></definition></sense></entry>
<entry id="variant"><lexical-unit><form lang="mus"><text>other</text></form></lexical-unit>
<relation type="_component-lexeme" ref="night1">
<trait name="variant-type" value="Free Variant"/></relation></entry>
<entry id="pon"><lexical-unit><form lang="mus"><text>ponvttv</text></form></lexical-unit></entry>
<entry id="see"><lexical-unit><form lang="mus"><text>hecetv</text></form></lexical-unit></entry>
</lift>"""


class StoryIndexTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.lift = self.root / "dictionary.lift"
        self.lift.write_text(LIFT, encoding="utf-8")

    def test_dictionary_collects_homographs_and_free_variants(self):
        dictionary = read_dictionary(self.lift)
        self.assertEqual(dictionary["nerē"], {
            "night1": ["night time", "darkness"], "night2": ["another night"], "variant": [],
        })
        self.assertEqual(dictionary["other"], {
            "variant": [], "night1": ["night time", "darkness"],
        })
        self.assertEqual(dictionary["ponvttv"], {"pon": []})

    def test_tokenization_normalizes_and_preserves_internal_punctuation(self):
        self.assertEqual(
            list(tokenize("HĒ, he\u0304! ’s-vyetv. ‘word’")),
            ["hē", "hē", "s-vyetv", "word"],
        )

    def test_dictionary_rejects_missing_or_duplicate_entry_ids(self):
        for contents, error in (
            ("<lift><entry/></lift>", "missing entry id"),
            ('<lift><entry id="same"/><entry id="same"/></lift>', "duplicate entry id"),
            ("<lift/>", "no Mvskoke headwords"),
        ):
            with self.subTest(contents=contents):
                self.lift.write_text(contents, encoding="utf-8")
                with self.assertRaisesRegex(ValueError, error):
                    read_dictionary(self.lift)

    def test_missing_free_variant_is_reported(self):
        self.lift.write_text(LIFT.replace('ref="variant"', 'ref="missing"'), encoding="utf-8")
        with self.assertWarnsRegex(UserWarning, "references missing entry"):
            dictionary = read_dictionary(self.lift)
        self.assertEqual(list(dictionary["nerē"]), ["night1", "night2"])

    def test_index_maps_selected_lemmas_and_keeps_unmatched_words(self):
        dictionary = read_dictionary(self.lift)
        results = {
            "nere": ["NERĒ"], "neret": ["nerē"], "unmatched": ["missing"],
            "unknown": [],
        }
        with patch("build_story_index.lemmatize", side_effect=lambda word: results[word]) as lookup:
            index = build_index("Nere, nere NERET unmatched unknown", dictionary)
        self.assertEqual(lookup.call_count, 4)
        self.assertEqual(index, {
            "nere": {"headword": "NERĒ", "entries": {"night1": ["night time", "darkness"],
                                                       "night2": ["another night"], "variant": []}},
            "neret": {"headword": "nerē", "entries": {"night1": ["night time", "darkness"],
                                                        "night2": ["another night"], "variant": []}},
            "unmatched": {"headword": "missing", "entries": {}},
            "unknown": {"headword": None, "entries": {}},
        })
        index["nere"]["entries"]["night1"].clear()
        self.assertEqual(index["neret"]["entries"]["night1"], ["night time", "darkness"])
        self.assertEqual(dictionary["nerē"]["night1"], ["night time", "darkness"])

    def test_overrides_match_words_and_phrases_and_skip_null(self):
        source = self.root / "story_words.tsv"
        source.write_text(
            "NeRe\u0304\tNERĒ\tignored\n"
            "skip\tnull\tignored\n"
            "skip over\tmissing phrase\tphrase definition\n"
            "other\tunknown\tcustom definition\n"
            "empty\tunknown\t\n",
            encoding="utf-8",
        )
        overrides = read_overrides(source)
        dictionary = read_dictionary(self.lift)
        with patch("build_story_index.lemmatize", return_value=[]) as lookup:
            index = build_index("NERĒ skip over. skip, over other empty ordinary", dictionary, overrides)
        self.assertEqual(index["nerē"], {
            "headword": "NERĒ",
            "entries": {"night1": ["night time", "darkness"], "night2": ["another night"], "variant": []},
        })
        self.assertNotIn("skip", index)
        self.assertEqual(index["skip over"], {
            "headword": "missing phrase", "entries": {}, "definition": "phrase definition",
        })
        self.assertEqual(index["other"], {
            "headword": "unknown", "entries": {}, "definition": "custom definition",
        })
        self.assertEqual(index["empty"], {"headword": "unknown", "entries": {}})
        self.assertEqual(index["ordinary"], {"headword": None, "entries": {}})
        self.assertEqual(lookup.call_count, 2)

        with patch("build_story_index.lemmatize", return_value=[]):
            self.assertNotIn("skip over", build_index("skip, over", dictionary, overrides))

    def test_override_file_rejects_bad_rows_and_normalized_duplicates(self):
        source = self.root / "story_words.tsv"
        for contents, error in (
            ("word headword definition\n", "three tab-separated columns"),
            ("word\t\tdefinition\n", "headword must not be empty"),
            ("word!\theadword\t\n", "invalid override word"),
            ("Nerē\tone\t\nnere\u0304\ttwo\t\n", "duplicate override word"),
        ):
            with self.subTest(contents=contents):
                source.write_text(contents, encoding="utf-8")
                with self.assertRaisesRegex(ValueError, error):
                    read_overrides(source)

    def test_cli_uses_real_lemmatizer_and_protects_inputs(self):
        source = self.root / "story.txt"
        source.write_text("Punvttv neret hēces zzqxx", encoding="utf-8")
        output = self.root / "story.json"
        command = [
            sys.executable, str(TOOLS / "build_story_index.py"), str(source),
            "--lexicon", str(self.lift), "--output", str(output),
        ]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(output.read_text(encoding="utf-8")), {
            "punvttv": {"headword": "ponvttv", "entries": {"pon": []}},
            "neret": {"headword": "nerē", "entries": {"night1": ["night time", "darkness"],
                                                        "night2": ["another night"], "variant": []}},
            "hēces": {"headword": "Hecetv", "entries": {"see": []}},
            "zzqxx": {"headword": None, "entries": {}},
        })
        self.assertIn("1 without lemmas, 1 without entry IDs", result.stderr)
        linked_output = self.root / "hardlink.json"
        os.link(source, linked_output)
        for protected in (self.lift, source, linked_output):
            with self.subTest(protected=protected):
                result = subprocess.run(command[:-1] + [str(protected)], capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
        self.assertEqual(source.read_text(encoding="utf-8"), "Punvttv neret hēces zzqxx")
        self.assertEqual(self.lift.read_text(encoding="utf-8"), LIFT)

    def test_cli_batch_and_colliding_output_names(self):
        first = self.root / "one.txt"
        second = self.root / "two.txt"
        first.write_text("nere", encoding="utf-8")
        second.write_text("punvttv", encoding="utf-8")
        command = [
            sys.executable, str(TOOLS / "build_story_index.py"), str(first), str(second),
            "--lexicon", str(self.lift),
        ]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads((self.root / "two.json").read_text(encoding="utf-8")),
            {"punvttv": {"headword": "ponvttv", "entries": {"pon": []}}},
        )
        collision = self.root / "one.md"
        collision.write_text("unchanged", encoding="utf-8")
        result = subprocess.run(
            [sys.executable, str(TOOLS / "build_story_index.py"), str(first), str(collision),
             "--lexicon", str(self.lift)],
            capture_output=True, text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("outputs must be distinct", result.stderr)
        self.assertEqual(collision.read_text(encoding="utf-8"), "unchanged")

    def test_cli_finds_each_story_override_and_protects_it_from_output(self):
        first = self.root / "one.txt"
        second = self.root / "two.txt"
        first.write_text("punvttv unknown skip", encoding="utf-8")
        second.write_text("punvttv", encoding="utf-8")
        overrides = self.root / "one_words.tsv"
        overrides.write_text(
            "punvttv\tnerē\tignored\nunknown\tmissing\tcustom\nskip\tnull\t\n",
            encoding="utf-8",
        )
        command = [
            sys.executable, str(TOOLS / "build_story_index.py"), str(first), str(second),
            "--lexicon", str(self.lift),
        ]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        first_index = json.loads((self.root / "one.json").read_text(encoding="utf-8"))
        second_index = json.loads((self.root / "two.json").read_text(encoding="utf-8"))
        self.assertEqual(first_index["punvttv"]["headword"], "nerē")
        self.assertEqual(list(first_index["punvttv"]["entries"]), ["night1", "night2", "variant"])
        self.assertEqual(first_index["unknown"], {
            "headword": "missing", "entries": {}, "definition": "custom",
        })
        self.assertNotIn("skip", first_index)
        self.assertEqual(second_index["punvttv"]["headword"], "ponvttv")
        result = subprocess.run(
            [sys.executable, str(TOOLS / "build_story_index.py"), str(first),
             "--lexicon", str(self.lift), "--output", str(overrides)],
            capture_output=True, text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("must not overwrite", result.stderr)
        self.assertTrue(overrides.read_text(encoding="utf-8").startswith("punvttv\t"))

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


if __name__ == "__main__":
    unittest.main()
