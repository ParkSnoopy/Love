#!/usr/bin/env python3
"""Build Korean Bible XML from Bible.com chapter pages.

This program performs no work until its operator explicitly runs it. It uses
only Python's standard library, emits the repository's canonical Bible XML,
and validates the completed document with the checked-in XSD when xmllint is
available.

Examples:
  python3 tools/crawl_bible_com.py --version 86:kor_klb:KLB:한국인의 성경
  python3 tools/crawl_bible_com.py --version 3803:kor_koerv:KOERV:우리말 쉬운성경
  python3 tools/crawl_bible_com.py --self-test

The crawl state contains only completion metadata and is written outside the
canonical corpus. Remove it with --reset after a successful crawl.
"""

from __future__ import annotations

import argparse
import html
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import subprocess
import sys
import time
from typing import Iterable
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_TEMPLATE = ROOT / "assets/data/bible/kor_wrm.xml"
DEFAULT_SCHEMA = ROOT / "assets/data/schema/bible.xml"
VERSE_PATTERN = re.compile(r"^([1-3]?[A-Z][A-Z0-9]*)\.(\d+)\.(\d+)$")


class VersePageParser(HTMLParser):
    """Extract text from Bible.com elements annotated with data-usfm."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.verses: dict[int, list[str]] = {}
        self._active_verse: int | None = None
        self._active_depth = 0
        self._ignored_depth = 0

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attributes = dict(attrs)
        reference = attributes.get("data-usfm")
        match = VERSE_PATTERN.fullmatch(reference or "")
        if match:
            self._active_verse = int(match.group(3))
            self._active_depth = 1
            self.verses.setdefault(self._active_verse, [])
            return
        if self._active_verse is not None:
            self._active_depth += 1
            class_name = attributes.get("class") or ""
            if tag in {"sup", "button"} or "label" in class_name:
                self._ignored_depth += 1

    def handle_endtag(self, tag: str) -> None:
        if self._active_verse is None:
            return
        if self._ignored_depth:
            self._ignored_depth -= 1
        self._active_depth -= 1
        if self._active_depth == 0:
            self._active_verse = None

    def handle_data(self, data: str) -> None:
        if self._active_verse is not None and not self._ignored_depth:
            self.verses[self._active_verse].append(data)

    def parsed_verses(self) -> dict[int, str]:
        parsed: dict[int, str] = {}
        for number, fragments in self.verses.items():
            text = " ".join("".join(fragments).split())
            if text:
                parsed[number] = text
        return parsed


def parse_chapter_html(content: str, expected_osis: str, expected_chapter: int) -> dict[int, str]:
    parser = VersePageParser()
    parser.feed(content)
    parser.close()
    verses = parser.parsed_verses()
    if not verses:
        raise ValueError(
            f"No data-usfm verse elements found for {expected_osis}.{expected_chapter}. "
            "Bible.com may have changed its rendered page format."
        )
    if min(verses) != 1:
        raise ValueError(f"{expected_osis}.{expected_chapter} begins at verse {min(verses)}, not verse 1.")
    expected_prefix = f'{expected_osis}.{expected_chapter}.'
    for reference in re.findall(r'data-usfm=["\']([^"\']+)["\']', content):
        if reference.startswith(expected_prefix):
            break
    else:
        raise ValueError(f"The response has no verse reference for {expected_osis}.{expected_chapter}.")
    return verses


def load_books(template_path: Path) -> list[ET.Element]:
    root = ET.parse(template_path).getroot()
    books = root.find("books")
    if books is None:
        raise ValueError(f"Template has no books element: {template_path}")
    return [book for book in books.findall("book")]


def chapter_requests(books: Iterable[ET.Element]) -> Iterable[tuple[ET.Element, ET.Element]]:
    for book in books:
        for chapter in book.findall("chapter"):
            yield book, chapter


def chapter_url(version_id: str, version_code: str, osis: str, chapter: int) -> str:
    return f"https://www.bible.com/ko/bible/{version_id}/{osis.upper()}.{chapter}.{version_code.upper()}"


def fetch(url: str, timeout: int) -> str:
    request = Request(url, headers={"User-Agent": "Love corpus builder/1.0"})
    with urlopen(request, timeout=timeout) as response:
        charset = response.headers.get_content_charset() or "utf-8"
        return response.read().decode(charset)


def load_state(path: Path) -> dict[str, object]:
    if not path.exists():
        return {"completed": {}}
    state = json.loads(path.read_text())
    if not isinstance(state.get("completed"), dict):
        raise ValueError(f"Invalid crawl state: {path}")
    return state


def write_state(path: Path, state: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n")
    temporary.replace(path)


def replace_chapter(chapter: ET.Element, verses: dict[int, str]) -> None:
    for verse in list(chapter):
        chapter.remove(verse)
    for number in sorted(verses):
        verse = ET.SubElement(chapter, "verse", {"number": str(number)})
        verse.text = verses[number]


def build_tree(books: list[ET.Element], bible_id: str, name: str) -> ET.Element:
    root = ET.Element("bible", {"format-version": "1"})
    metadata = ET.SubElement(root, "metadata")
    ET.SubElement(metadata, "id").text = bible_id
    ET.SubElement(metadata, "name").text = name
    books_element = ET.SubElement(root, "books")
    for book in books:
        books_element.append(book)
    return root


def validate_output(output: Path, schema: Path) -> None:
    result = subprocess.run(
        ["xmllint", "--noout", "--schema", str(schema), str(output)],
        text=True,
        capture_output=True,
    )
    if result.returncode:
        raise ValueError(f"Schema validation failed for {output}: {result.stderr.strip()}")


def write_output(root: ET.Element, output: Path) -> None:
    ET.indent(root, space="  ")
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(".tmp")
    ET.ElementTree(root).write(temporary, encoding="utf-8", xml_declaration=True)
    temporary.replace(output)


def crawl(args: argparse.Namespace) -> None:
    version_id, bible_id, version_code, name = args.version.split(":", 3)
    output = ROOT / "assets/data/bible" / f"{bible_id}.xml"
    state_path = ROOT / ".crawl-state" / f"{bible_id}.json"
    if args.reset and state_path.exists():
        state_path.unlink()

    books = load_books(args.template)
    state = load_state(state_path)
    completed = state["completed"]
    if not isinstance(completed, dict):
        raise ValueError("Crawl state completed field must be an object.")

    for book, chapter in chapter_requests(books):
        osis = book.attrib["osis"]
        chapter_number = int(chapter.attrib["number"])
        key = f"{osis}.{chapter_number}"
        if key in completed:
            replace_chapter(chapter, {int(number): text for number, text in completed[key].items()})
            continue

        url = chapter_url(version_id, version_code, osis, chapter_number)
        print(f"Fetching {url}", file=sys.stderr)
        try:
            verses = parse_chapter_html(fetch(url, args.timeout), osis, chapter_number)
        except (HTTPError, URLError, TimeoutError, ValueError) as error:
            raise RuntimeError(f"Stopped at {key}: {error}") from error
        replace_chapter(chapter, verses)
        completed[key] = {str(number): text for number, text in verses.items()}
        write_state(state_path, state)
        time.sleep(args.delay)

    write_output(build_tree(books, bible_id, name), output)
    validate_output(output, args.schema)
    print(f"Wrote and validated {output}", file=sys.stderr)


def self_test() -> None:
    fixture = """
    <article>
      <span data-usfm="GEN.1.1"><span class="label">1</span>태초에 <em>말씀</em>이 계셨다.</span>
      <span data-usfm="GEN.1.2"><span class="label">2</span>그 빛은 참빛이다.</span>
    </article>
    """
    verses = parse_chapter_html(fixture, "GEN", 1)
    expected = {1: "태초에 말씀이 계셨다.", 2: "그 빛은 참빛이다."}
    if verses != expected:
        raise AssertionError(f"Parser output differs: {verses!r}")
    root = build_tree(load_books(DEFAULT_TEMPLATE), "kor_test", "Parser Test")
    serialized = ET.tostring(root, encoding="unicode")
    if "<bible format-version=\"1\">" not in serialized or "<verse number=\"1\">" not in serialized:
        raise AssertionError("Generated XML does not match the canonical Bible structure.")
    print("Parser self-test passed.")


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--version",
        help="Bible.com version-id:output-id:version-code:display-name",
    )
    parser.add_argument("--template", type=Path, default=DEFAULT_TEMPLATE)
    parser.add_argument("--schema", type=Path, default=DEFAULT_SCHEMA)
    parser.add_argument("--delay", type=float, default=1.0)
    parser.add_argument("--timeout", type=int, default=30)
    parser.add_argument("--reset", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        return args
    if not args.version:
        parser.error("--version is required unless --self-test is used")
    if args.delay < 0:
        parser.error("--delay must be non-negative")
    if not args.template.is_file() or not args.schema.is_file():
        parser.error("--template and --schema must name existing files")
    if len(args.version.split(":", 3)) != 4:
        parser.error("--version must be version-id:output-id:version-code:display-name")
    return args


if __name__ == "__main__":
    parsed_arguments = arguments()
    if parsed_arguments.self_test:
        self_test()
    else:
        crawl(parsed_arguments)
