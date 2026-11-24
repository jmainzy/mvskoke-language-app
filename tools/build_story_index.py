#!/usr/bin/env python3
"""Build word-to-entry indexes for one or more plain text files."""

import argparse
import json
from pathlib import Path
import sys
from typing import TypedDict
import unicodedata

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from mus_segmenter.segment import DEFAULT_LEXICON, Morphology # type: ignore


class StoryEntry(TypedDict):
    stem: str | None
    sense_ids: list[str]


def tokenize(text: str):
    token = ""
    for char in text:
        if unicodedata.category(char)[0] in "LMN" or char in "-'’":
            token += char
        else:
            word = token.strip("-'’")
            if word:
                yield unicodedata.normalize("NFC", word).lower()
            token = ""
    word = token.strip("-'’")
    if word:
        yield unicodedata.normalize("NFC", word).lower()


def build_index(text: str, analyzer: Morphology) -> dict[str, StoryEntry]:
    result: dict[str, StoryEntry] = {}
    for word in tokenize(text):
        if word in result:
            continue
        stem, entry_ids = analyzer.analyze(word)
        result[word] = {"stem": stem, "sense_ids": entry_ids}
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sources", type=Path, nargs="+", help="plain text files to index")
    parser.add_argument("--lexicon", type=Path, default=DEFAULT_LEXICON, help="dictionary LIFT file")
    parser.add_argument("--output", type=Path, help="output JSON file (only with one source)")
    args = parser.parse_args()
    if args.output and len(args.sources) != 1:
        parser.error("--output requires exactly one source")
    outputs = [args.output or source.with_suffix(".json") for source in args.sources]
    protected = {source.resolve() for source in args.sources} | {args.lexicon.resolve()}
    if len({output.resolve() for output in outputs}) != len(outputs) or any(
        output.resolve() in protected for output in outputs
    ):
        parser.error("outputs must be distinct and must not overwrite an input or dictionary")
    analyzer = Morphology(args.lexicon)
    for source, output in zip(args.sources, outputs):
        index = build_index(source.read_text(encoding="utf-8"), analyzer)
        with output.open("w", encoding="utf-8") as file:
            json.dump(index, file, ensure_ascii=False, indent=2)
            file.write("\n")
        missing_stem = sum(entry["stem"] is None for entry in index.values())
        missing_entry = sum(not entry["sense_ids"] for entry in index.values())
        print(
            f"{source}: {len(index)} words, {missing_stem} without stems, "
            f"{missing_entry} without entry IDs -> {output}", file=sys.stderr
        )


if __name__ == "__main__":
    main()
