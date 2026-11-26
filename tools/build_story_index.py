#!/usr/bin/env python3
"""Build word-to-entry indexes for one or more plain text files."""

import argparse
from collections import deque
import json
from pathlib import Path
import sys
from typing import TypedDict
import unicodedata
import warnings
import xml.etree.ElementTree as ET

from mvskoke_lemmatizer import lemmatize


DEFAULT_LEXICON = Path(__file__).resolve().parents[2] / "mvskoke-dictionary" / "lexicon" / "lexicon.lift"


class StoryEntry(TypedDict):
    headword: str | None
    entries: dict[str, list[str]]


def normalize(text: str) -> str:
    return unicodedata.normalize("NFC", text).lower()


def read_dictionary(source: Path) -> dict[str, dict[str, list[str]]]:
    entries: dict[str, tuple[str, list[str]]] = {}
    words: dict[str, list[str]] = {}
    variants: dict[str, list[str]] = {}
    for _, entry in ET.iterparse(source, events=("end",)):
        if entry.tag != "entry":
            continue
        entry_id = entry.get("id")
        if not entry_id or not entry_id.strip():
            raise ValueError(f"{source}: missing entry id")
        key = unicodedata.normalize("NFC", entry_id)
        if key in entries:
            raise ValueError(f"{source}: duplicate entry id {entry_id!r}")
        definitions = []
        for text in entry.findall("./sense/definition/form[@lang='en']/text"):
            definition = "".join(text.itertext()).strip()
            if definition:
                definitions.append(definition)
        entries[key] = (entry_id, definitions)
        text = entry.find("./lexical-unit/form[@lang='mus']/text")
        if text is not None:
            headword = "".join(text.itertext()).strip()
            if headword:
                words.setdefault(normalize(headword), []).append(key)
        for relation in entry.findall("./relation"):
            if relation.get("type") == "_component-lexeme" and any(
                trait.get("name") == "variant-type" and trait.get("value") == "Free Variant"
                for trait in relation.findall("./trait")
            ):
                ref = relation.get("ref")
                if not ref or not ref.strip():
                    warnings.warn(f"{source}: free variant {entry_id!r} has no reference", stacklevel=2)
                else:
                    variants.setdefault(key, []).append(unicodedata.normalize("NFC", ref))
        entry.clear()

    if not words:
        raise ValueError(f"{source}: no Mvskoke headwords found")
    for key, refs in variants.items():
        for ref in refs:
            if ref not in entries:
                warnings.warn(
                    f"{source}: free variant {entries[key][0]!r} references missing entry {ref!r}",
                    stacklevel=2,
                )

    result = {}
    for word, keys in words.items():
        pending = deque(keys)
        seen = set(keys)
        ordered = list(keys)
        while pending:
            for ref in variants.get(pending.popleft(), []):
                if ref in entries and ref not in seen:
                    seen.add(ref)
                    ordered.append(ref)
                    pending.append(ref)
        result[word] = {entries[key][0]: entries[key][1] for key in ordered}
    return result


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


def build_index(
    text: str, dictionary: dict[str, dict[str, list[str]]]
) -> dict[str, StoryEntry]:
    result: dict[str, StoryEntry] = {}
    for word in tokenize(text):
        if word in result:
            continue
        lemmas = lemmatize(word)
        lemma = lemmas[0] if lemmas else None
        entries = dictionary.get(normalize(lemma), {}) if lemma is not None else {}
        result[word] = {
            "headword": lemma,
            "entries": {entry_id: definitions.copy() for entry_id, definitions in entries.items()},
        }
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
    protected = [*args.sources, args.lexicon]

    def same_file(left: Path, right: Path) -> bool:
        return left.resolve() == right.resolve() or (
            left.exists() and right.exists() and left.samefile(right)
        )

    if any(same_file(output, path) for output in outputs for path in protected) or any(
        same_file(output, other) for i, output in enumerate(outputs) for other in outputs[:i]
    ):
        parser.error("outputs must be distinct and must not overwrite an input or dictionary")
    dictionary = read_dictionary(args.lexicon)
    for source, output in zip(args.sources, outputs):
        index = build_index(source.read_text(encoding="utf-8"), dictionary)
        with output.open("w", encoding="utf-8") as file:
            json.dump(index, file, ensure_ascii=False, indent=2)
            file.write("\n")
        missing_lemma = sum(entry["headword"] is None for entry in index.values())
        missing_entry = sum(not entry["entries"] for entry in index.values())
        print(
            f"{source}: {len(index)} words, {missing_lemma} without lemmas, "
            f"{missing_entry} without entry IDs -> {output}", file=sys.stderr
        )


if __name__ == "__main__":
    main()
