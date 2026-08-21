#!/usr/bin/env python3
"""Compile canonical XML corpora into SQLite databases and assets/data.zip.

Run explicitly:
  python3 tools/compile_corpus.py
"""

from __future__ import annotations

import json
from pathlib import Path
import shutil
import sqlite3
import tempfile
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "assets" / "data"
OUTPUT_ZIP = ROOT / "assets" / "data.zip"
CANONICAL_BOOK_IDS = {
    book.attrib["osis"]: int(book.attrib["id"])
    for book in ET.parse(DATA_DIR / "bible" / "kor_wrm.xml").findall("./books/book")
}
LANGUAGES = {
    "kor": "Korean",
    "eng": "English",
    "zho": "Chinese",
    "jpn": "Japanese",
}


def text(element: ET.Element | None, description: str) -> str:
    if element is None or element.text is None or not element.text.strip():
        raise ValueError(f"Missing {description}")
    return element.text.strip()


def metadata(root: ET.Element) -> tuple[str, str]:
    metadata_element = root.find("metadata")
    if metadata_element is None:
        raise ValueError("Missing metadata")
    return text(metadata_element.find("id"), "metadata id"), text(
        metadata_element.find("name"), "metadata name"
    )


def create_database(path: Path, slug: str, label: str) -> sqlite3.Connection:
    connection = sqlite3.connect(path)
    connection.executescript(
        """
        PRAGMA foreign_keys = ON;
        CREATE TABLE version (slug TEXT PRIMARY KEY, label TEXT NOT NULL);
        CREATE TABLE books (
          book_id INTEGER PRIMARY KEY,
          osis TEXT NOT NULL,
          name TEXT NOT NULL,
          testament TEXT NOT NULL,
          chapters INTEGER NOT NULL
        );
        CREATE TABLE verses (
          book_id INTEGER NOT NULL,
          chapter INTEGER NOT NULL,
          verse INTEGER NOT NULL,
          end_verse INTEGER,
          position INTEGER NOT NULL,
          text TEXT NOT NULL,
          FOREIGN KEY (book_id) REFERENCES books(book_id)
        );
        CREATE TABLE headings (
          book_id INTEGER NOT NULL,
          chapter INTEGER NOT NULL,
          position INTEGER NOT NULL,
          text TEXT NOT NULL,
          FOREIGN KEY (book_id) REFERENCES books(book_id)
        );
        CREATE INDEX idx_v_bc ON verses(book_id, chapter, verse, position);
        """
    )
    connection.execute("INSERT INTO version VALUES (?, ?)", (slug, label))
    return connection


def compile_bible(source: Path, output: Path) -> tuple[str, str]:
    root = ET.parse(source).getroot()
    if root.tag != "bible":
        raise ValueError(f"Not a Bible corpus: {source}")
    slug, label = metadata(root)
    connection = create_database(output, slug, label)
    try:
        for book in root.findall("./books/book"):
            book_id = CANONICAL_BOOK_IDS.get(book.attrib["osis"], 0)
            connection.execute(
                "INSERT OR IGNORE INTO books VALUES (?, ?, ?, ?, ?)",
                (
                    book_id,
                    book.attrib["osis"],
                    text(book.find("name"), f"book name in {source}"),
                    book.attrib["testament"],
                    int(book.attrib["chapters"]),
                ),
            )
            for chapter in book.findall("chapter"):
                chapter_number = int(chapter.attrib["number"])
                for position, item in enumerate(chapter, start=1):
                    item_text = text(item, f"chapter item in {source}")
                    if item.tag == "heading":
                        connection.execute(
                            "INSERT INTO headings VALUES (?, ?, ?, ?)",
                            (book_id, chapter_number, position, item_text),
                        )
                    elif item.tag == "verse":
                        end_number = item.attrib.get("end-number")
                        connection.execute(
                            "INSERT INTO verses VALUES (?, ?, ?, ?, ?, ?)",
                            (
                                book_id,
                                chapter_number,
                                int(item.attrib["number"]),
                                int(end_number) if end_number is not None else None,
                                position,
                                item_text,
                            ),
                        )
                    else:
                        raise ValueError(f"Unexpected Bible chapter item: {item.tag}")
        connection.commit()
        connection.execute("VACUUM")
    finally:
        connection.close()
    return slug, label


def compile_commentary(source: Path, output: Path) -> tuple[str, str]:
    root = ET.parse(source).getroot()
    if root.tag != "commentary":
        raise ValueError(f"Not a commentary corpus: {source}")
    slug, label = metadata(root)
    connection = create_database(output, slug, label)
    try:
        for book in root.findall("./books/book"):
            book_id = CANONICAL_BOOK_IDS.get(book.attrib["osis"], 0)
            connection.execute(
                "INSERT OR IGNORE INTO books VALUES (?, ?, ?, ?, ?)",
                (
                    book_id,
                    book.attrib["osis"],
                    text(book.find("name"), f"book name in {source}"),
                    book.attrib.get("testament", "INTRO"),
                    int(book.attrib["chapters"]),
                ),
            )
            for chapter in book.findall("chapter"):
                chapter_number = int(chapter.attrib["number"])
                for position, entry in enumerate(chapter.findall("entry"), start=1):
                    reference = entry.find("reference")
                    if reference is None:
                        raise ValueError(f"Missing commentary reference in {source}")
                    verses = (reference.attrib.get("verses") or "0").split("-", 1)[0].split(",", 1)[0]
                    connection.execute(
                        "INSERT INTO verses VALUES (?, ?, ?, NULL, ?, ?)",
                        (
                            book_id,
                            int(reference.attrib["chapter"]),
                            int(verses),
                            position,
                            entry.findtext("body", default=""),
                        ),
                    )
        connection.commit()
        connection.execute("VACUUM")
    finally:
        connection.close()
    return slug, label


def manifest_entry(slug: str, label: str, data_type: str, source: Path) -> dict[str, str]:
    language = next(
        (language for prefix, language in LANGUAGES.items() if source.stem.startswith(prefix)),
        None,
    )
    if language is None:
        raise ValueError(f"Unsupported corpus language: {slug}")
    return {
        "id": slug,
        "shortname": label,
        "name": label,
        "language": language,
        "type": data_type,
        "file": f"{source.stem}.sqlite",
        "source": "canonical-xml",
    }


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="love-data-", dir=ROOT) as temporary:
        staging = Path(temporary) / "data"
        entries: list[dict[str, str]] = []
        for data_type, compiler in (("bible", compile_bible), ("commentary", compile_commentary)):
            destination = staging / data_type
            destination.mkdir(parents=True)
            for source in sorted((DATA_DIR / data_type).glob("*.xml")):
                output = destination / f"{source.stem}.sqlite"
                slug, label = compiler(source, output)
                entries.append(manifest_entry(slug, label, data_type, source))
                print(f"Compiled {source.relative_to(ROOT)}")
        entries.sort(key=lambda entry: (entry["type"], entry["language"], entry["name"], entry["id"]))
        manifest = DATA_DIR / "manifest.json"
        manifest.write_text(json.dumps(entries, ensure_ascii=False, indent=2) + "\n")
        temporary_zip = Path(temporary) / "data.zip"
        with zipfile.ZipFile(temporary_zip, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            for file in sorted(staging.rglob("*.sqlite")):
                archive.write(file, file.relative_to(staging.parent).as_posix())
        shutil.copyfile(temporary_zip, OUTPUT_ZIP)
    print(f"Wrote {manifest.relative_to(ROOT)} and {OUTPUT_ZIP.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
