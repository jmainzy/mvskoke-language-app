#!/usr/bin/env python3
"""Build a sense ID to headword and definition index from a lexicon JSONL file."""

import argparse
import json
from pathlib import Path
from typing import TypedDict


class Sense(TypedDict):
    headword: str
    definition: str | None


def build_index(source: Path) -> dict[str, Sense]:
    index: dict[str, Sense] = {}
    with source.open(encoding="utf-8") as file:
        for line_number, line in enumerate(file, start=1):
            if not line.strip():
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError as error:
                raise ValueError(f"{source}:{line_number}: invalid JSON: {error.msg}") from error
            if not isinstance(row, dict):
                raise ValueError(f"{source}:{line_number}: expected an object")
            sense_id = row.get("sense_id")
            if not isinstance(sense_id, str) or not sense_id:
                raise ValueError(f"{source}:{line_number}: expected a non-empty sense_id")
            headword = row.get("headword")
            if not isinstance(headword, str) or not headword:
                raise ValueError(f"{source}:{line_number}: expected a non-empty headword")
            if "definition" not in row or not isinstance(row["definition"], (str, type(None))):
                raise ValueError(f"{source}:{line_number}: expected a string or null definition")
            if sense_id in index:
                raise ValueError(f"{source}:{line_number}: duplicate sense_id {sense_id!r}")
            index[sense_id] = {"headword": headword, "definition": row["definition"]}
    return index


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="path to lexicon_search.jsonl")
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "assets" / "sense_index.json",
        help="output JSON file (default: assets/sense_index.json)",
    )
    args = parser.parse_args()
    index = build_index(args.source)
    with args.output.open("w", encoding="utf-8") as file:
        json.dump(index, file, ensure_ascii=False, indent=2)
        file.write("\n")


if __name__ == "__main__":
    main()
