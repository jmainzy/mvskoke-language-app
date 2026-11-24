# Mvskoke Language App

Language Learning App for the Mvskoke (Muscogee/Creek) Language

## Contribution

Fork and PR!

The app uses the sibling `../readalong` checkout as a local dependency.
Story word indexes are optional assets: set `wordIndexFile` on a content item
to a JSON list of single-entry objects mapping words to definitions.

To generate the sense ID to headword and definition index from a lexicon export, run:

```sh
python3 tools/build_sense_index.py /path/to/lexicon_search.jsonl
```

This writes `assets/sense_index.json` with each sense ID mapping to an object
containing `headword` and `definition`, preserving null definitions. Use
`--output /path/to/file.json` to write the index elsewhere.

To generate a word-to-sense lookup using the Punvyvs checkout and its installed
Ruby bundle, run from that checkout:

```sh
cd /path/to/punvyvs
bundle exec ruby -E UTF-8:UTF-8 /path/to/mvskoke-language-app/tools/build_conjugation_index.rb
```

By default this reads `storage/lexicon_search.jsonl` and writes
`assets/word_index.json` in this app; `--source` and `--output` override
those paths. No database is modified. The JSON maps a lowercase word or phrase
directly to an array of possible sense IDs (look up their definitions in
`sense_index.json`). It includes dictionary headwords, the action and stative
paradigms supported by Punvyvs, and first-word keys for multiword conjugations.
Keys include NFC spellings and Punvyvs-normalized spellings (NFKD, combining
marks removed, lowercase, and trimmed); normalize input the same way for
accent-insensitive lookup. Strip surrounding story punctuation before lookup.
Multiple IDs are candidates, not a disambiguated answer.

Generated forms are not linguist-verified and do not cover every possible
inflection or Punvyvs database curation. The script reports conjugations the
library cannot generate to stderr. The full index is large; loading it into
memory on a mobile device has a corresponding cost.

## Story morphology indexes

Install the Python dependency, then extract a ReadAlong or ELAN transcription
and index its words:

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r ../mus_segmenter/requirements.txt
python3 tools/extract_story_text.py path/to/story.readalong
python3 tools/build_story_index.py path/to/story.txt
```

The extractor writes `story.txt`; for ELAN it reads the `Transcription` tier
only (choose another tier with `--tier`). ReadAlong extraction uses `<w>`
elements and excludes translations. The indexer writes `story.json`, mapping
each distinct lowercase word to `{"stem": <dictionary headword or null>,
"sense_ids": [<entry IDs>]}`. Despite the field name, the array contains the
LIFT `<entry id>` values for the selected stem, including any entries linked
as free variants. These IDs differ from the generated IDs used by
`assets/sense_index.json` and cannot be looked up in that file. A matched
entry has an ID even if it has no senses. For a combined `em` plus verb,
`stem` contains the separated surface words and the IDs include the available
entries for both. It prefers a direct dictionary
headword, then an exact spelling over an accent-insensitive analysis;
ambiguities between different stems are resolved deterministically, not
contextually. If neither matches, it tries vowel substitutions (`v`/`a` and
`u`/`o`), written `f` for dictionary `h`, and single versus double `c`;
`ē`/`e` is already covered by accent-insensitive matching. The
fewest changes win, but the result is still a candidate, not a
verified match. Internal hyphens and apostrophes are retained; other
punctuation separates words.

The indexer imports the analyzer from the sibling `../mus_segmenter` checkout.
Its `segment.py` compiles a PyFoma right-linear grammar into a bidirectional
FST. It reads the sibling
`../mvskoke-dictionary/lexicon/lexicon.lift` by default. Pass `--lexicon` to
select another LIFT file. Use `--output` to name the JSON result. Multiple
text files can be indexed in one invocation. To inspect
analyses directly, run `python3 ../mus_segmenter/segment.py word1 word2`.

The initial grammar models action-verb present, past, future, imperative,
vhan and selected auxiliary forms, L/H-grade alternations, and regular
stative forms including documented diminutive and augmentative derivations.
It also recognizes subject `-t`, definite subject `-at` replacing final
`e`/`ē` (including `-etv` verb headwords), direct object `-n`, selected
verb adverbs including present endings with final `-n`, verb stems without
final `-tv`, and initial-`e` contractions. It recognizes stative past-five
forms, H-grade `-et`, possessive prefixes, and combined `em` plus verb forms.
Dictionary verb phrases beginning with `etem` also match joined forms,
including phrases that already contain `-ho-`.
It uses LIFT grammatical categories for statives and avoids regular plural
stative/action analyses when the dictionary marks an irregular plural, except
for imperative `-vkēs`. It
uses linked dual and triplural action stems where available. Other irregular
plurals, many affixes and multiword expressions are not yet modeled. The
rules and automatic disambiguation require linguistic review;
an FST analysis is a candidate, not a verified translation.

To index all `.readalong` and `.eaf` files recursively under
`assets/readalongs`, run `bash tools/index_readalongs.sh` in the activated
environment. Pass `--lexicon` to that script if needed.
It uses temporary text files and writes a JSON file beside each source. The
extractor and indexers overwrite their output files; save any manual edits
before rerunning. Existing story indexes are not automatically regenerated
and may contain older sense IDs until rerun.
These indexes are not the definition-list format currently expected by
`wordIndexFile`, so they cannot yet be used directly by the reader.
