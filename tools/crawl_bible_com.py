#!/usr/bin/env python3
"""Build Korean Bible XML from Bible.com chapter pages.

This program performs no work until its operator explicitly runs it. It uses
only Python's standard library, emits the repository's canonical Bible XML,
and validates the completed document with the checked-in XSD when xmllint is
available.

Examples:
  python3 tools/crawl_bible_com.py --version 86:kor_klb:KLB:한국인의 성경
  python3 tools/crawl_bible_com.py --version 3803:kor_koerv:KOERV:우리말 쉬운성경
  python3 tools/crawl_bible_com.py --version 86:kor_klb:KLB:한국인의 성경 --parallel-version 3803:kor_koerv:KOERV:읽기 쉬운 성경
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
VERSE_REFERENCE_PATTERN = re.compile(r"^([1-3]?[A-Z][A-Z0-9]*)\.(\d+)\.(\d+)$")
BIBLE_COM_BOOK_CODES = {
    "Gen": "GEN", "Exod": "EXO", "Lev": "LEV", "Num": "NUM", "Deut": "DEU",
    "Josh": "JOS", "Judg": "JDG", "Ruth": "RUT", "1Sam": "1SA", "2Sam": "2SA",
    "1Kgs": "1KI", "2Kgs": "2KI", "1Chr": "1CH", "2Chr": "2CH", "Ezra": "EZR",
    "Neh": "NEH", "Esth": "EST", "Job": "JOB", "Ps": "PSA", "Prov": "PRO",
    "Eccl": "ECC", "Song": "SNG", "Isa": "ISA", "Jer": "JER", "Lam": "LAM",
    "Ezek": "EZK", "Dan": "DAN", "Hos": "HOS", "Joel": "JOL", "Amos": "AMO",
    "Obad": "OBA", "Jonah": "JON", "Mic": "MIC", "Nah": "NAM", "Hab": "HAB",
    "Zeph": "ZEP", "Hag": "HAG", "Zech": "ZEC", "Mal": "MAL", "Matt": "MAT",
    "Mark": "MRK", "Luke": "LUK", "John": "JHN", "Acts": "ACT", "Rom": "ROM",
    "1Cor": "1CO", "2Cor": "2CO", "Gal": "GAL", "Eph": "EPH", "Phil": "PHP",
    "Col": "COL", "1Thess": "1TH", "2Thess": "2TH", "1Tim": "1TI", "2Tim": "2TI",
    "Titus": "TIT", "Phlm": "PHM", "Heb": "HEB", "Jas": "JAS", "1Pet": "1PE",
    "2Pet": "2PE", "1John": "1JN", "2John": "2JN", "3John": "3JN", "Jude": "JUD",
    "Rev": "REV",
}


class VersePageParser(HTMLParser):
    """Extract text from Bible.com elements annotated with data-usfm."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.items: list[tuple[str, str | None, list[str]]] = []
        self._active_fragments: list[str] | None = None
        self._active_depth = 0
        self._ignored_depth = 0
        self._ignored_tags: list[bool] = []

    def _start_item(self, kind: str, reference: str | None = None) -> None:
        self._active_fragments = []
        self.items.append((kind, reference, self._active_fragments))
        self._active_depth = 1

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attributes = dict(attrs)
        reference = attributes.get("data-usfm")
        class_name = attributes.get("class") or ""
        if (
            reference
            and "verse" in class_name
            and all(VERSE_REFERENCE_PATTERN.fullmatch(part) for part in reference.split("+"))
        ):
            self._start_item("verse", reference)
            return
        if self._active_fragments is None and "heading" in class_name:
            self._start_item("heading")
            return
        if self._active_fragments is not None:
            self._active_depth += 1
            is_ignored = (
                tag in {"sup", "button"}
                or "label" in class_name
                or class_name.endswith("__fr")
                or class_name.endswith("__ft")
            )
            self._ignored_tags.append(is_ignored)
            if is_ignored:
                self._ignored_depth += 1

    def handle_endtag(self, tag: str) -> None:
        if self._active_fragments is None:
            return
        if self._active_depth > 1 and self._ignored_tags.pop():
            self._ignored_depth -= 1
        self._active_depth -= 1
        if self._active_depth == 0:
            self._active_fragments = None

    def handle_data(self, data: str) -> None:
        if self._active_fragments is not None and not self._ignored_depth:
            self._active_fragments.append(data)

    def parsed_items(self) -> list[tuple[str, str | None, str]]:
        parsed: list[tuple[str, str | None, str]] = []
        for kind, reference, fragments in self.items:
            text = " ".join("".join(fragments).split())
            if text:
                parsed.append((kind, reference, text))
        return parsed


def parse_chapter_html(
    content: str,
    expected_book_code: str,
    expected_chapter: int,
) -> list[tuple[str, int | None, int | None, str]]:
    parser = VersePageParser()
    parser.feed(content)
    parser.close()
    raw_items = parser.parsed_items()
    if not any(kind == "verse" for kind, _, _ in raw_items):
        raise ValueError(
            f"No data-usfm verse elements found for {expected_book_code}.{expected_chapter}. "
            "Bible.com may have changed its rendered page format."
        )
    chapter_items: list[tuple[str, int | None, int | None, str]] = []
    verse_starts: list[int] = []
    for kind, reference, text in raw_items:
        if kind == "heading":
            chapter_items.append(("heading", None, None, text))
            continue
        if reference is None:
            raise ValueError("Verse item is missing a scripture reference.")
        parts = [VERSE_REFERENCE_PATTERN.fullmatch(part) for part in reference.split("+")]
        if any(part is None for part in parts):
            raise ValueError(f"Invalid scripture reference: {reference}")
        matches = [part for part in parts if part is not None]
        if any(
            match.group(1) != expected_book_code.upper()
            or int(match.group(2)) != expected_chapter
            for match in matches
        ):
            raise ValueError(f"Unexpected scripture reference: {reference}")
        numbers = [int(match.group(3)) for match in matches]
        if numbers != list(range(numbers[0], numbers[-1] + 1)):
            raise ValueError(f"Non-contiguous scripture reference: {reference}")
        verse_starts.append(numbers[0])
        chapter_items.append(("verse", numbers[0], numbers[-1], text))
    if min(verse_starts) != 1:
        raise ValueError(f"{expected_book_code}.{expected_chapter} begins after verse 1.")
    return normalize_chapter_items(chapter_items)


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


def chapter_url(version_id: str, version_code: str, book_code: str, chapter: int) -> str:
    return f"https://www.bible.com/ko/bible/{version_id}/{book_code}.{chapter}.{version_code.upper()}"


def fetch(url: str, timeout: int, retries: int, retry_delay: float) -> str:
    request = Request(url, headers={"User-Agent": "Love corpus builder/1.0"})
    for attempt in range(retries + 1):
        try:
            with urlopen(request, timeout=timeout) as response:
                charset = response.headers.get_content_charset() or "utf-8"
                return response.read().decode(charset)
        except HTTPError as error:
            retryable = error.code == 429 or 500 <= error.code < 600
            if not retryable or attempt == retries:
                raise
        except (URLError, TimeoutError):
            if attempt == retries:
                raise
        delay = retry_delay * (attempt + 1)
        print(
            f"Request failed; retrying {attempt + 1}/{retries} in {delay:g}s: {url}",
            file=sys.stderr,
        )
        time.sleep(delay)
    raise AssertionError("Retry loop completed without returning or raising.")


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


def normalize_chapter_items(
    items: list[tuple[str, int | None, int | None, str]],
) -> list[tuple[str, int | None, int | None, str]]:
    headings = [item for item in items if item[0] == "heading"]
    verses: dict[tuple[int, int], list[str]] = {}
    for kind, start, end, text in items:
        if kind == "verse":
            if start is None or end is None:
                raise ValueError("Verse is missing its number range.")
            verses.setdefault((start, end), []).append(text)
    return headings + [
        ("verse", start, end, " ".join(texts))
        for (start, end), texts in sorted(verses.items())
    ]


def decode_chapter_items(serialized: list[dict[str, object]]) -> list[tuple[str, int | None, int | None, str]]:
    decoded: list[tuple[str, int | None, int | None, str]] = []
    for item in serialized:
        kind = item["kind"]
        text = item["text"]
        if kind == "heading":
            decoded.append(("heading", None, None, text))
        else:
            decoded.append(("verse", int(item["number"]), int(item["end-number"]), text))
    return normalize_chapter_items(decoded)


def encode_chapter_items(items: list[tuple[str, int | None, int | None, str]]) -> list[dict[str, object]]:
    serialized: list[dict[str, object]] = []
    for kind, start, end, text in items:
        if kind == "heading":
            serialized.append({"kind": "heading", "text": text})
        else:
            serialized.append({"kind": "verse", "number": start, "end-number": end, "text": text})
    return serialized


def replace_chapter(chapter: ET.Element, items: list[tuple[str, int | None, int | None, str]]) -> None:
    for item in list(chapter):
        chapter.remove(item)
    for kind, start, end, text in items:
        if kind == "heading":
            ET.SubElement(chapter, "heading").text = text
            continue
        attributes = {"number": str(start)}
        if end != start:
            attributes["end-number"] = str(end)
        ET.SubElement(chapter, "verse", attributes).text = text


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


def parse_compare_html(
    content: str,
    versions: dict[str, tuple[str, int]],
) -> dict[str, list[tuple[str, int | None, int | None, str]]]:
    markers = list(re.finditer(r'<div class="version vid(\d+)\b[^>]*>', content))
    sections: dict[str, str] = {}
    for index, marker in enumerate(markers):
        version_id = marker.group(1)
        if version_id in versions:
            end = markers[index + 1].start() if index + 1 < len(markers) else len(content)
            sections[version_id] = content[marker.end():end]
    if sections.keys() != versions.keys():
        raise ValueError(f"Compare response omitted versions: {sorted(versions.keys() - sections.keys())}")
    return {
        version_id: parse_chapter_html(section, book_code, chapter_number)
        for version_id, (book_code, chapter_number) in versions.items()
        for section in [sections[version_id]]
    }


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
        book_code = BIBLE_COM_BOOK_CODES[osis]
        chapter_number = int(chapter.attrib["number"])
        key = f"{osis}.{chapter_number}"
        if key in completed:
            replace_chapter(chapter, decode_chapter_items(completed[key]))
            continue

        url = chapter_url(version_id, version_code, book_code, chapter_number)
        print(f"Fetching {url}", file=sys.stderr)
        try:
            verses = parse_chapter_html(
                fetch(url, args.timeout, args.retries, args.retry_delay),
                book_code,
                chapter_number,
            )
        except (HTTPError, URLError, TimeoutError, ValueError) as error:
            raise RuntimeError(f"Stopped at {key}: {error}") from error
        replace_chapter(chapter, verses)
        completed[key] = encode_chapter_items(verses)
        write_state(state_path, state)
        time.sleep(args.delay)

    write_output(build_tree(books, bible_id, name), output)
    validate_output(output, args.schema)
    print(f"Wrote and validated {output}", file=sys.stderr)


def crawl_compare(args: argparse.Namespace) -> None:
    primary_id, primary_output_id, primary_code, primary_name = args.version.split(":", 3)
    parallel_id, parallel_output_id, parallel_code, parallel_name = args.parallel_version.split(":", 3)
    state_path = ROOT / ".crawl-state" / f"{primary_output_id}-{parallel_output_id}.json"
    if args.reset and state_path.exists():
        state_path.unlink()

    primary_books = load_books(args.template)
    parallel_books = load_books(args.template)
    state = load_state(state_path)
    completed = state["completed"]
    if not isinstance(completed, dict):
        raise ValueError("Crawl state completed field must be an object.")

    for (primary_book, primary_chapter), (parallel_book, parallel_chapter) in zip(
        chapter_requests(primary_books), chapter_requests(parallel_books),
        strict=True,
    ):
        osis = primary_book.attrib["osis"]
        book_code = BIBLE_COM_BOOK_CODES[osis]
        chapter_number = int(primary_chapter.attrib["number"])
        key = f"{osis}.{chapter_number}"
        if key in completed:
            replace_chapter(primary_chapter, decode_chapter_items(completed[key][primary_id]))
            replace_chapter(parallel_chapter, decode_chapter_items(completed[key][parallel_id]))
            continue

        url = f"{chapter_url(primary_id, primary_code, book_code, chapter_number)}?parallel={parallel_id}"
        print(f"Fetching {url}", file=sys.stderr)
        try:
            parsed = parse_compare_html(
                fetch(url, args.timeout, args.retries, args.retry_delay),
                {
                    primary_id: (book_code, chapter_number),
                    parallel_id: (book_code, chapter_number),
                },
            )
        except (HTTPError, URLError, TimeoutError, ValueError) as error:
            raise RuntimeError(f"Stopped at {key}: {error}") from error
        replace_chapter(primary_chapter, parsed[primary_id])
        replace_chapter(parallel_chapter, parsed[parallel_id])
        completed[key] = {
            primary_id: encode_chapter_items(parsed[primary_id]),
            parallel_id: encode_chapter_items(parsed[parallel_id]),
        }
        write_state(state_path, state)
        time.sleep(args.delay)

    primary_output = ROOT / "assets/data/bible" / f"{primary_output_id}.xml"
    parallel_output = ROOT / "assets/data/bible" / f"{parallel_output_id}.xml"
    write_output(build_tree(primary_books, primary_output_id, primary_name), primary_output)
    write_output(build_tree(parallel_books, parallel_output_id, parallel_name), parallel_output)
    validate_output(primary_output, args.schema)
    validate_output(parallel_output, args.schema)
    print(f"Wrote and validated {primary_output} and {parallel_output}", file=sys.stderr)


def self_test() -> None:
    fixture = """
    <article>
      <span class="heading">세상의 시작</span>
      <span class="verse" data-usfm="GEN.1.1+GEN.1.2"><span class="label">1-2</span>태초에 <em>말씀</em>이 계셨다.</span>
      <span class="verse" data-usfm="GEN.1.3"><span class="label">3</span>그 빛은</span>
      <span class="verse" data-usfm="GEN.1.3">참빛이다.</span>
    </article>
    """
    verses = parse_chapter_html(fixture, BIBLE_COM_BOOK_CODES["Gen"], 1)
    expected = [
        ("heading", None, None, "세상의 시작"),
        ("verse", 1, 2, "태초에 말씀이 계셨다."),
        ("verse", 3, 3, "그 빛은 참빛이다."),
    ]
    if verses != expected:
        raise AssertionError(f"Parser output differs: {verses!r}")
    if chapter_url("86", "KLB", BIBLE_COM_BOOK_CODES["Exod"], 1).endswith("/EXO.1.KLB") is False:
        raise AssertionError("Bible.com book-code mapping did not translate Exod to EXO.")
    books = load_books(DEFAULT_TEMPLATE)
    missing_codes = {book.attrib["osis"] for book in books} - BIBLE_COM_BOOK_CODES.keys()
    if missing_codes:
        raise AssertionError(f"Bible.com book-code mapping is missing: {sorted(missing_codes)}")
    root = build_tree(books, "kor_test", "Parser Test")
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
    parser.add_argument(
        "--parallel-version",
        help="Compared Bible.com version-id:output-id:version-code:display-name",
    )
    parser.add_argument("--template", type=Path, default=DEFAULT_TEMPLATE)
    parser.add_argument("--schema", type=Path, default=DEFAULT_SCHEMA)
    parser.add_argument("--delay", type=float, default=1.0)
    parser.add_argument("--timeout", type=int, default=30)
    parser.add_argument("--retries", type=int, default=5)
    parser.add_argument("--retry-delay", type=float, default=5.0)
    parser.add_argument("--reset", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        return args
    if not args.version:
        parser.error("--version is required unless --self-test is used")
    if args.delay < 0:
        parser.error("--delay must be non-negative")
    if args.retries < 0 or args.retry_delay < 0:
        parser.error("--retries and --retry-delay must be non-negative")
    if not args.template.is_file() or not args.schema.is_file():
        parser.error("--template and --schema must name existing files")
    for option, value in (("--version", args.version), ("--parallel-version", args.parallel_version)):
        if value is not None and len(value.split(":", 3)) != 4:
            parser.error(f"{option} must be version-id:output-id:version-code:display-name")
    return args


if __name__ == "__main__":
    parsed_arguments = arguments()
    if parsed_arguments.self_test:
        self_test()
    else:
        if parsed_arguments.parallel_version:
            crawl_compare(parsed_arguments)
        else:
            crawl(parsed_arguments)
