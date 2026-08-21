#!/usr/bin/env python3
"""Convert a flat Korean Bible JSON reference map to the canonical XML corpus."""

from __future__ import annotations

import argparse
from collections import defaultdict
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_TEMPLATE = ROOT / "assets" / "data" / "bible" / "kor_wrm.xml"
REFERENCE_PATTERN = re.compile(r"^([^0-9]+)([0-9]+):([0-9]+)(?:-([0-9]+))?$")
BOOK_CODES = (
    "창", "출", "레", "민", "신", "수", "삿", "룻", "삼상", "삼하", "왕상", "왕하",
    "대상", "대하", "스", "느", "에", "욥", "시", "잠", "전", "아", "사", "렘",
    "애", "겔", "단", "호", "욜", "암", "옵", "욘", "미", "나", "합", "습", "학",
    "슥", "말", "마", "막", "눅", "요", "행", "롬", "고전", "고후", "갈", "엡",
    "빌", "골", "살전", "살후", "딤전", "딤후", "딛", "몬", "히", "약", "벧전",
    "벧후", "요일", "요이", "요삼", "유", "계",
)
# The downloaded source splits the second sentence of John 18:38 under a corrupt key.
REFERENCE_CONTINUATIONS = {"요18:이": "요18:38"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--id", required=True, dest="bible_id")
    parser.add_argument("--name", required=True)
    parser.add_argument("--template", type=Path, default=DEFAULT_TEMPLATE)
    parser.add_argument(
        "--write",
        action="store_true",
        help="Write the XML; without this flag, only validate and report the conversion.",
    )
    return parser.parse_args()


def load_verses(source: Path) -> dict[tuple[str, int, int], tuple[int, str]]:
    raw = json.loads(source.read_text())
    if not isinstance(raw, dict):
        raise ValueError("Bible JSON root must be an object.")

    verses: dict[tuple[str, int, int], tuple[int, str]] = {}
    continuations: defaultdict[tuple[str, int, int], list[str]] = defaultdict(list)
    for reference, value in raw.items():
        if not isinstance(reference, str) or not isinstance(value, str):
            raise ValueError(f"Invalid Bible JSON entry: {reference!r}")
        value = value.rstrip("\x00").strip()
        if not value:
            raise ValueError(f"Empty Bible JSON entry: {reference!r}")
        invalid_characters = [
            character
            for character in value
            if not (
                ord(character) in (9, 10, 13)
                or 0x20 <= ord(character) <= 0xD7FF
                or 0xE000 <= ord(character) <= 0xFFFD
                or 0x10000 <= ord(character) <= 0x10FFFF
            )
        ]
        if invalid_characters:
            raise ValueError(f"Invalid XML character in Bible JSON entry: {reference!r}")
        canonical_reference = REFERENCE_CONTINUATIONS.get(reference, reference)
        match = REFERENCE_PATTERN.fullmatch(canonical_reference)
        if match is None:
            raise ValueError(f"Invalid Bible reference: {reference}")
        book_code = match.group(1)
        chapter = int(match.group(2))
        verse = int(match.group(3))
        end_verse = int(match.group(4) or match.group(3))
        if end_verse < verse:
            raise ValueError(f"Descending Bible reference: {reference}")
        key = (book_code, chapter, verse)
        if reference in REFERENCE_CONTINUATIONS:
            continuations[key].append(value.strip())
        elif key in verses:
            raise ValueError(f"Duplicate Bible reference: {reference}")
        else:
            verses[key] = (end_verse, value.strip())

    for key, fragments in continuations.items():
        if key not in verses:
            raise ValueError(f"Continuation has no base verse: {key}")
        end_verse, text = verses[key]
        verses[key] = (end_verse, " ".join((text, *fragments)))
    return verses


def build_xml(
    verses: dict[tuple[str, int, int], tuple[int, str]],
    template: Path,
    bible_id: str,
    name: str,
):
    tree = ET.parse(template)
    root = tree.getroot()
    metadata = root.find("metadata")
    books = root.findall("./books/book")
    if metadata is None or len(books) != len(BOOK_CODES):
        raise ValueError("Template does not contain the canonical 66-book structure.")
    metadata_id = metadata.find("id")
    metadata_name = metadata.find("name")
    if metadata_id is None or metadata_name is None:
        raise ValueError("Template metadata is incomplete.")
    metadata_id.text = bible_id
    metadata_name.text = name

    used: set[tuple[str, int, int]] = set()
    for book, book_code in zip(books, BOOK_CODES, strict=True):
        chapter_count = int(book.attrib["chapters"])
        for child in list(book):
            if child.tag == "chapter":
                book.remove(child)
        for chapter_number in range(1, chapter_count + 1):
            chapter = ET.SubElement(book, "chapter", {"number": str(chapter_number)})
            chapter_verses = sorted(
                (key, value)
                for key, value in verses.items()
                if key[0] == book_code and key[1] == chapter_number
            )
            if not chapter_verses:
                raise ValueError(f"Missing chapter: {book_code}{chapter_number}")
            for key, (end_verse, verse_text) in chapter_verses:
                attributes = {"number": str(key[2])}
                if end_verse != key[2]:
                    attributes["end-number"] = str(end_verse)
                ET.SubElement(chapter, "verse", attributes).text = verse_text
                used.add(key)

    unused = set(verses) - used
    if unused:
        raise ValueError(f"References outside the canonical book structure: {sorted(unused)}")
    ET.indent(tree, space="  ")
    return tree


def main() -> None:
    args = parse_args()
    verses = load_verses(args.source)
    tree = build_xml(verses, args.template, args.bible_id, args.name)
    ranged = sum(
        1 for (_, _, start), (end, _) in verses.items() if end != start
    )
    action = "Writing" if args.write else "Would write"
    print(
        f"{action} {args.output}: {len(BOOK_CODES)} books, "
        f"{len(verses)} verse records, {ranged} ranged records"
    )
    if args.write:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        tree.write(args.output, encoding="utf-8", xml_declaration=True)


if __name__ == "__main__":
    main()
