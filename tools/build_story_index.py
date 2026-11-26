#!/usr/bin/env python3
"""Build word-to-entry indexes for one or more plain text files."""

import argparse
from collections import deque
import csv
import json
from pathlib import Path
import sys
from typing import NotRequired, TypedDict
import unicodedata
import warnings
import xml.etree.ElementTree as ET

from mvskoke_lemmatizer import lemmatize


DEFAULT_LEXICON = Path(__file__).resolve().parents[2] / "mvskoke-dictionary" / "lexicon" / "lexicon.lift"


class StoryEntry(TypedDict):
    headword: str | None
    entries: dict[str, list[str]]
    definition: NotRequired[str]


class Override(TypedDict):
    headword: str | None
    definition: str


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


def tokens_with_offsets(text: str):
    token = ""
    start = 0
    for position, char in enumerate(text):
        if unicodedata.category(char)[0] in "LMN" or char in "-'’":
            if not token:
                start = position
            token += char
        else:
            word = token.strip("-'’")
            if word:
                left = len(token) - len(token.lstrip("-'’"))
                right = len(token.rstrip("-'’"))
                yield normalize(word), start + left, start + right
            token = ""
    word = token.strip("-'’")
    if word:
        left = len(token) - len(token.lstrip("-'’"))
        right = len(token.rstrip("-'’"))
        yield normalize(word), start + left, start + right


def tokenize(text: str):
    for word, _, _ in tokens_with_offsets(text):
        yield word


def read_overrides(source: Path) -> dict[str, Override]:
    overrides: dict[str, Override] = {}
    with source.open(encoding="utf-8-sig", newline="") as file:
        for line_number, row in enumerate(csv.reader(file, delimiter="\t", strict=True), start=1):
            if not row:
                continue
            if len(row) != 3:
                raise ValueError(f"{source}:{line_number}: expected three tab-separated columns")
            word, headword, definition = (column.strip() for column in row)
            key = normalize(" ".join(word.split()))
            if not key or " ".join(tokenize(word)) != key:
                raise ValueError(f"{source}:{line_number}: invalid override word {word!r}")
            if not headword:
                raise ValueError(f"{source}:{line_number}: headword must not be empty; use null to skip")
            if key in overrides:
                raise ValueError(f"{source}:{line_number}: duplicate override word {word!r}")
            overrides[key] = {
                "headword": None if headword.lower() == "null" else headword,
                "definition": definition,
            }
    return overrides


def build_index(
    text: str,
    dictionary: dict[str, dict[str, list[str]]],
    overrides: dict[str, Override] | None = None,
) -> dict[str, StoryEntry]:
    overrides = overrides or {}
    phrases: dict[str, list[tuple[str, ...]]] = {}
    for word in overrides:
        parts = tuple(word.split(" "))
        if len(parts) > 1:
            phrases.setdefault(parts[0], []).append(parts)

    result: dict[str, StoryEntry] = {}
    tokens = list(tokens_with_offsets(text))

    def add_word(word: str) -> None:
        if word in result:
            return
        override = overrides.get(word)
        if override is not None:
            lemma = override["headword"]
            if lemma is None:
                return
        else:
            lemmas = lemmatize(word)
            lemma = lemmas[0] if lemmas else None
        entries = dictionary.get(normalize(lemma), {}) if lemma is not None else {}
        entry: StoryEntry = {
            "headword": lemma,
            "entries": {entry_id: definitions.copy() for entry_id, definitions in entries.items()},
        }
        if not entries and override is not None and override["definition"]:
            entry["definition"] = override["definition"]
        result[word] = entry

    for i, (word, _, _) in enumerate(tokens):
        add_word(word)
        for parts in phrases.get(word, []):
            matched = tokens[i:i + len(parts)]
            if len(matched) == len(parts) and all(
                token[0] == part for token, part in zip(matched, parts)
            ) and all(
                text[matched[j - 1][2]:matched[j][1]].isspace()
                for j in range(1, len(matched))
            ):
                add_word(" ".join(parts))
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
    override_paths = [source.with_name(f"{source.stem}_words.tsv") for source in args.sources]
    protected = [*args.sources, args.lexicon, *override_paths]

    def same_file(left: Path, right: Path) -> bool:
        return left.resolve() == right.resolve() or (
            left.exists() and right.exists() and left.samefile(right)
        )

    if any(same_file(output, path) for output in outputs for path in protected) or any(
        same_file(output, other) for i, output in enumerate(outputs) for other in outputs[:i]
    ):
        parser.error("outputs must be distinct and must not overwrite an input or dictionary")
    dictionary = read_dictionary(args.lexicon)
    for source, output, override_path in zip(args.sources, outputs, override_paths):
        overrides = read_overrides(override_path) if override_path.exists() else {}
        index = build_index(source.read_text(encoding="utf-8"), dictionary, overrides)
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
