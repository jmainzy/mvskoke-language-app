# Mvskoke Language App

Language Learning App for the Mvskoke (Muscogee/Creek) Language

## Contribution

Fork and PR!

The app uses the sibling `../readalong` checkout as a local dependency.
Story word indexes are optional assets in `assets/readalongs`. The app looks
for an index named after the text file, for example `story_index.json` for
`story.readalong` or `story.eaf`.

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

Install the sibling `mvskoke-lemmatizer` checkout, then extract a ReadAlong or
ELAN transcription and index its words:

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install ../mvskoke-lemmatizer
python3 tools/extract_story_text.py path/to/story.readalong
python3 tools/build_story_index.py path/to/story.txt
```

The extractor writes `story.txt`; for ELAN it reads the `Transcription` tier
only (choose another tier with `--tier`). ReadAlong extraction uses `<w>`
elements and excludes translations. The indexer writes `story.json`, mapping
each distinct lowercase word to its lemma, LIFT entry IDs, and English
definitions grouped by entry ID. For example:

```json
{"punvttv": {"headword": "ponvttv",
             "entries": {"ponvttv_entry_id": ["example definition"]}}}
```

The `entries` object includes homographic entries and their linked free variants;
entries need not have senses. Each definition list contains the entry's
nonempty English sense definitions in dictionary order and is empty if none
are available. These are LIFT `<entry id>` values, not the
generated sense IDs in `assets/sense_index.json`. An unrecognized word has a
null headword and empty entries. A lemma absent from the selected LIFT file is
kept with empty entries and counted in the diagnostic output. The reader shows
all available definitions for a word; words without definitions are not marked.
The reader matches complete ReadAlong word elements or ELAN annotations, so
individual words inside a multiword ELAN annotation are not separately indexed.

The installed lemmatizer supplies the HFST analysis and fuzzy matching; its
compiled model and the selected LIFT file should come from the same
dictionary version. It selects one lemma, preferring an exact match and then
the longest candidate. Internal hyphens and apostrophes are retained; other
punctuation separates words. Results are candidates, not verified translations.

For per-story corrections, place `story_words.tsv` beside `story.txt` (or
beside `story.readalong`/`story.eaf` for the batch script). Use three tab-separated
columns, with no header: word or phrase, headword, and optional definition.
Leave the third column empty if there is no definition. Matching is
case-insensitive and NFC-normalized; duplicate words are an error. A `null`
headword skips that word entirely. Other overrides bypass the lemmatizer and
look up the supplied headword in the LIFT dictionary. If it has no entry, the
index keeps `entries` empty and stores a nonempty supplied definition in a
separate `definition` field. Existing dictionary definitions take precedence.
Phrases match consecutive tokens separated only by whitespace; individual
tokens are still indexed separately. The current reader does not display
phrase entries spanning multiple word elements.

The indexer reads `../mvskoke-dictionary/lexicon/lexicon.lift` by default.
Pass `--lexicon` to select another LIFT file and `--output` to name the JSON
result. Multiple text files can be indexed in one invocation.

To index all `.readalong` and `.eaf` files recursively under
`assets/readalongs`, run `bash tools/index_readalongs.sh` in the activated
environment. Pass `--lexicon` to that script if needed.
It uses temporary text files and writes a JSON file beside each source. The
extractor and indexers overwrite their output files; save any manual edits
before rerunning. Existing story indexes are not automatically regenerated
and may contain older formats until rerun.
