#!/usr/bin/env python3
"""Convert Bible SQLite databases or legacy raw XML dumps into semantic XML.

Usage:
  python3 tools/sqlite_to_xml.py assets/data
  python3 tools/sqlite_to_xml.py --migrate-legacy assets/data
  python3 tools/sqlite_to_xml.py --validate assets/data

The semantic format is intentionally data-oriented: Bible and commentary files
contain translation metadata, books, chapters, and verses rather than SQLite
schema definitions, rows, columns, or typed values.
"""

import argparse
import sqlite3
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path

SQLITE_SUFFIXES = {".sqlite", ".sqlite3", ".db"}


def xml_type(path: Path) -> str:
    return "commentary" if "commentary" in path.parts else "bible"


def read_sqlite(source: Path) -> tuple[dict[str, str], list[dict], list[dict]]:
    with sqlite3.connect(f"file:{source}?mode=ro", uri=True) as connection:
        connection.row_factory = sqlite3.Row
        version = connection.execute(
            "SELECT slug, label FROM version LIMIT 1"
        ).fetchone()
        if version is None:
            raise ValueError(f"Missing version metadata in {source}")
        books = [
            dict(row)
            for row in connection.execute(
                """
                SELECT book_id, osis, eng_name, name, testament, chapters
                FROM books
                ORDER BY book_id
                """
            )
        ]
        verses = [
            dict(row)
            for row in connection.execute(
                """
                SELECT book_id, chapter, verse, text
                FROM verses
                ORDER BY book_id, chapter, verse
                """
            )
        ]
    return dict(version), books, verses


def legacy_rows(root: ET.Element, table_name: str) -> list[dict[str, str]]:
    table = root.find(f"./data/table[@name='{table_name}']")
    if table is None:
        raise ValueError(f"Missing {table_name} table in legacy XML")

    rows = []
    for row in table.findall("row"):
        values = {}
        for column in row.findall("column"):
            name = column.get("name")
            value = column.find("value")
            if name is None or value is None:
                raise ValueError(f"Malformed {table_name} row in legacy XML")
            values[name] = value.text or ""
        rows.append(values)
    return rows


def read_legacy_xml(source: Path) -> tuple[dict[str, str], list[dict], list[dict]]:
    root = ET.parse(source).getroot()
    if root.tag != "sqlite-database" or root.get("format-version") != "1":
        raise ValueError(f"Not a legacy SQLite XML dump: {source}")

    versions = legacy_rows(root, "version")
    if not versions:
        raise ValueError(f"Missing version metadata in {source}")
    return versions[0], legacy_rows(root, "books"), legacy_rows(root, "verses")


def append_text(parent: ET.Element, tag: str, value: object) -> None:
    ET.SubElement(parent, tag).text = str(value)


def write_semantic_xml(
    output: Path,
    data_type: str,
    metadata: dict[str, str],
    books: list[dict],
    verses: list[dict],
) -> None:
    root = ET.Element(data_type, {"format-version": "1"})
    metadata_element = ET.SubElement(root, "metadata")
    append_text(metadata_element, "id", metadata["slug"])
    append_text(metadata_element, "name", metadata["label"])

    verses_by_book: dict[str, dict[str, list[dict]]] = defaultdict(
        lambda: defaultdict(list)
    )
    for verse in verses:
        verses_by_book[str(verse["book_id"])][str(verse["chapter"])].append(verse)

    books_element = ET.SubElement(root, "books")
    for book in books:
        book_id = str(book["book_id"])
        book_element = ET.SubElement(
            books_element,
            "book",
            {
                "id": book_id,
                "osis": str(book["osis"]),
                "testament": str(book["testament"]),
                "chapters": str(book["chapters"]),
            },
        )
        append_text(book_element, "english-name", book["eng_name"])
        append_text(book_element, "name", book["name"])
        for chapter_number in sorted(verses_by_book[book_id], key=int):
            chapter_verses = sorted(
                verses_by_book[book_id][chapter_number],
                key=lambda verse: int(verse["verse"]),
            )
            chapter = ET.SubElement(book_element, "chapter", {"number": chapter_number})
            for verse in chapter_verses:
                verse_element = ET.SubElement(
                    chapter, "verse", {"number": str(verse["verse"])}
                )
                verse_element.text = str(verse["text"])

    output.parent.mkdir(parents=True, exist_ok=True)
    tree = ET.ElementTree(root)
    ET.indent(tree, space="  ")
    tree.write(output, encoding="utf-8", xml_declaration=True)


def sqlite_files(path: Path) -> list[Path]:
    if path.is_file():
        return [path] if path.suffix.lower() in SQLITE_SUFFIXES else []
    return sorted(
        candidate
        for candidate in path.rglob("*")
        if candidate.is_file() and candidate.suffix.lower() in SQLITE_SUFFIXES
    )


def legacy_xml_files(path: Path) -> list[Path]:
    candidates = [path] if path.is_file() else sorted(path.rglob("*.xml"))
    return [
        candidate
        for candidate in candidates
        if candidate.is_file()
        and ET.parse(candidate).getroot().tag == "sqlite-database"
    ]


def read_semantic_xml(source: Path) -> tuple[str, dict[str, str], list[dict], list[dict]]:
    root = ET.parse(source).getroot()
    if root.tag not in {"bible", "commentary"}:
        raise ValueError(f"Not semantic Bible XML: {source}")
    metadata = root.find("metadata")
    if metadata is None:
        raise ValueError(f"Missing metadata in {source}")

    books = []
    verses = []
    for book in root.findall("./books/book"):
        books.append(
            {
                "book_id": book.get("id", ""),
                "osis": book.get("osis", ""),
                "eng_name": book.findtext("english-name", default=""),
                "name": book.findtext("name", default=""),
                "testament": book.get("testament", ""),
                "chapters": book.get("chapters", ""),
            }
        )
        for chapter in book.findall("chapter"):
            for verse in chapter.findall("verse"):
                verses.append(
                    {
                        "book_id": book.get("id", ""),
                        "chapter": chapter.get("number", ""),
                        "verse": verse.get("number", ""),
                        "text": verse.text or "",
                    }
                )
    return (
        root.tag,
        {
            "slug": metadata.findtext("id", default=""),
            "label": metadata.findtext("name", default=""),
        },
        books,
        verses,
    )


def validate_semantic_xml(source: Path) -> tuple[int, int]:
    root = ET.parse(source).getroot()
    if root.tag not in {"bible", "commentary"} or root.get("format-version") != "1":
        raise ValueError(f"Invalid semantic Bible XML root in {source}")
    metadata = root.find("metadata")
    if metadata is None or not metadata.findtext("id") or not metadata.findtext("name"):
        raise ValueError(f"Missing metadata in {source}")

    books = root.findall("./books/book")
    verse_count = 0
    previous_book = -1
    for book in books:
        if not all(book.get(attribute) is not None for attribute in ("id", "osis", "testament", "chapters")):
            raise ValueError(f"Malformed book in {source}")
        if book.find("english-name") is None or book.find("name") is None:
            raise ValueError(f"Missing book name in {source}")
        book_number = int(book.get("id", ""))
        if book_number <= previous_book:
            raise ValueError(f"Books are not ordered in {source}")
        previous_book = book_number
        previous_chapter = -1
        for chapter in book.findall("chapter"):
            if chapter.get("number") is None:
                raise ValueError(f"Malformed chapter in {source}")
            chapter_number = int(chapter.get("number", ""))
            if chapter_number <= previous_chapter:
                raise ValueError(f"Chapters are not ordered in {source}")
            previous_chapter = chapter_number
            previous_verse = -1
            for verse in chapter.findall("verse"):
                if verse.get("number") is None:
                    raise ValueError(f"Malformed verse in {source}")
                verse_number = int(verse.get("number", ""))
                if verse_number <= previous_verse:
                    raise ValueError(f"Verses are not ordered in {source}")
                previous_verse = verse_number
                verse_count += 1
    return len(books), verse_count


def main() -> int:
    parser = argparse.ArgumentParser(description="Create and validate semantic Bible XML.")
    parser.add_argument("path", type=Path, help="SQLite database, XML file, or directory")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--migrate-legacy", action="store_true")
    mode.add_argument("--normalize", action="store_true")
    mode.add_argument("--validate", action="store_true")
    args = parser.parse_args()

    if args.validate:
        files = [args.path] if args.path.is_file() else sorted(args.path.rglob("*.xml"))
        if not files:
            print(f"No XML files found under {args.path}", file=sys.stderr)
            return 1
        for source in files:
            books, verses = validate_semantic_xml(source)
            print(f"Validated {source}: {books} books, {verses} verses")
        return 0

    if args.migrate_legacy:
        sources = legacy_xml_files(args.path)
        if not sources:
            print(f"No legacy XML dumps found under {args.path}", file=sys.stderr)
            return 1
        for source in sources:
            metadata, books, verses = read_legacy_xml(source)
            write_semantic_xml(source, xml_type(source), metadata, books, verses)
            print(f"Migrated {source}: {len(books)} books, {len(verses)} verses")
        return 0

    if args.normalize:
        files = [args.path] if args.path.is_file() else sorted(args.path.rglob("*.xml"))
        if not files:
            print(f"No XML files found under {args.path}", file=sys.stderr)
            return 1
        for source in files:
            data_type, metadata, books, verses = read_semantic_xml(source)
            write_semantic_xml(source, data_type, metadata, books, verses)
            print(f"Normalized {source}: {len(books)} books, {len(verses)} verses")
        return 0

    sources = sqlite_files(args.path)
    if not sources:
        print(f"No SQLite databases found under {args.path}", file=sys.stderr)
        return 1
    for source in sources:
        metadata, books, verses = read_sqlite(source)
        output = source.with_suffix(".xml")
        write_semantic_xml(output, xml_type(source), metadata, books, verses)
        print(f"Dumped {source} -> {output}: {len(books)} books, {len(verses)} verses")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())