#!/usr/bin/env python3
"""Extract transcription text from a ReadAlong or ELAN file."""

import argparse
from pathlib import Path
import xml.etree.ElementTree as ET


def local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def extract_text(source: Path, tier_name: str = "Transcription") -> str:
    root = ET.parse(source).getroot()
    root_name = local_name(root.tag)
    if root_name == "read-along":
        words = [
            "".join(element.itertext()).strip()
            for element in root.iter()
            if local_name(element.tag) == "w"
        ]
        return " ".join(word for word in words if word) + "\n"
    if root_name == "ANNOTATION_DOCUMENT":
        tiers = [
            element for element in root.iter()
            if local_name(element.tag) == "TIER" and element.get("TIER_ID") == tier_name
        ]
        if len(tiers) != 1:
            raise ValueError(f"{source}: expected exactly one ELAN tier named {tier_name!r}")
        values = [
            "".join(element.itertext()).strip()
            for element in tiers[0].iter()
            if local_name(element.tag) == "ANNOTATION_VALUE"
        ]
        return "\n".join(value for value in values if value) + "\n"
    raise ValueError(f"{source}: unsupported XML root {root_name!r}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="ReadAlong or ELAN XML file")
    parser.add_argument("--output", type=Path, help="output text file (default: source with .txt extension)")
    parser.add_argument("--tier", default="Transcription", help="ELAN tier ID (default: Transcription)")
    args = parser.parse_args()
    output = args.output or args.source.with_suffix(".txt")
    if output.resolve() == args.source.resolve():
        parser.error("source and output must be different files")
    text = extract_text(args.source, args.tier)
    output.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
