#!/usr/bin/env python3
"""helloao_com_migrate_1.py - Convert helloao commentary dir to XLSX

Reads per-chapter JSON files crawled by helloao_com_crawl.py and
produces XLSX matching format_example/com_kor_mhw.xlsx schema.

Usage:
    python helloao_com_migrate_1.py helloao_com_raw/matthew-henry/
    python helloao_com_migrate_1.py helloao_com_raw/ --output-dir ./xlsx
    python helloao_com_migrate_1.py helloao_com_raw/keil-delitzsch/ -o keil.xlsx
"""

import argparse
import json
import sys
from pathlib import Path

import openpyxl

# helloao book ID -> (book_id, osis, eng_name, testament, chapters)
HELLOAO_BOOKS = {
    "GEN": (1, "Gen", "Genesis", "OT", 50),
    "EXO": (2, "Exod", "Exodus", "OT", 40),
    "LEV": (3, "Lev", "Leviticus", "OT", 27),
    "NUM": (4, "Num", "Numbers", "OT", 36),
    "DEU": (5, "Deut", "Deuteronomy", "OT", 34),
    "JOS": (6, "Josh", "Joshua", "OT", 24),
    "JDG": (7, "Judg", "Judges", "OT", 21),
    "RUT": (8, "Ruth", "Ruth", "OT", 4),
    "1SA": (9, "1Sam", "1 Samuel", "OT", 31),
    "2SA": (10, "2Sam", "2 Samuel", "OT", 24),
    "1KI": (11, "1Kgs", "1 Kings", "OT", 22),
    "2KI": (12, "2Kgs", "2 Kings", "OT", 25),
    "1CH": (13, "1Chr", "1 Chronicles", "OT", 29),
    "2CH": (14, "2Chr", "2 Chronicles", "OT", 36),
    "EZR": (15, "Ezra", "Ezra", "OT", 10),
    "NEH": (16, "Neh", "Nehemiah", "OT", 13),
    "EST": (17, "Esth", "Esther", "OT", 10),
    "JOB": (18, "Job", "Job", "OT", 42),
    "PSA": (19, "Ps", "Psalms", "OT", 150),
    "PRO": (20, "Prov", "Proverbs", "OT", 31),
    "ECC": (21, "Eccl", "Ecclesiastes", "OT", 12),
    "SNG": (22, "Song", "Song of Songs", "OT", 8),
    "ISA": (23, "Isa", "Isaiah", "OT", 66),
    "JER": (24, "Jer", "Jeremiah", "OT", 52),
    "LAM": (25, "Lam", "Lamentations", "OT", 5),
    "EZK": (26, "Ezek", "Ezekiel", "OT", 48),
    "Ezek": (26, "Ezek", "Ezekiel", "OT", 48),  # tyndale variant
    "DAN": (27, "Dan", "Daniel", "OT", 12),
    "HOS": (28, "Hos", "Hosea", "OT", 14),
    "JOL": (29, "Joel", "Joel", "OT", 3),
    "AMO": (30, "Amos", "Amos", "OT", 9),
    "OBA": (31, "Obad", "Obadiah", "OT", 1),
    "JON": (32, "Jonah", "Jonah", "OT", 4),
    "MIC": (33, "Mic", "Micah", "OT", 7),
    "NAM": (34, "Nah", "Nahum", "OT", 3),
    "Nah": (34, "Nah", "Nahum", "OT", 3),  # tyndale variant
    "HAB": (35, "Hab", "Habakkuk", "OT", 3),
    "ZEP": (36, "Zeph", "Zephaniah", "OT", 3),
    "HAG": (37, "Hag", "Haggai", "OT", 2),
    "ZEC": (38, "Zech", "Zechariah", "OT", 14),
    "MAL": (39, "Mal", "Malachi", "OT", 4),
    "MAT": (40, "Matt", "Matthew", "NT", 28),
    "MRK": (41, "Mark", "Mark", "NT", 16),
    "LUK": (42, "Luke", "Luke", "NT", 24),
    "JHN": (43, "John", "John", "NT", 21),
    "ACT": (44, "Acts", "Acts", "NT", 28),
    "ROM": (45, "Rom", "Romans", "NT", 16),
    "1CO": (46, "1Cor", "1 Corinthians", "NT", 16),
    "2CO": (47, "2Cor", "2 Corinthians", "NT", 13),
    "GAL": (48, "Gal", "Galatians", "NT", 6),
    "EPH": (49, "Eph", "Ephesians", "NT", 6),
    "PHP": (50, "Phil", "Philippians", "NT", 4),
    "Phil": (50, "Phil", "Philippians", "NT", 4),  # tyndale variant
    "COL": (51, "Col", "Colossians", "NT", 4),
    "1TH": (52, "1Thess", "1 Thessalonians", "NT", 5),
    "2TH": (53, "2Thess", "2 Thessalonians", "NT", 3),
    "1TI": (54, "1Tim", "1 Timothy", "NT", 6),
    "2TI": (55, "2Tim", "2 Timothy", "NT", 4),
    "TIT": (56, "Titus", "Titus", "NT", 3),
    "PHM": (57, "Phlm", "Philemon", "NT", 1),
    "Phlm": (57, "Phlm", "Philemon", "NT", 1),  # tyndale variant
    "HEB": (58, "Heb", "Hebrews", "NT", 13),
    "JAS": (59, "Jas", "James", "NT", 5),
    "1PE": (60, "1Pet", "1 Peter", "NT", 5),
    "2PE": (61, "2Pet", "2 Peter", "NT", 3),
    "1JN": (62, "1John", "1 John", "NT", 5),
    "2JN": (63, "2John", "2 John", "NT", 1),
    "3JN": (64, "3John", "3 John", "NT", 1),
    "JUD": (65, "Jude", "Jude", "NT", 1),
    "REV": (66, "Rev", "Revelation", "NT", 22),
}


def convert_com_to_xlsx(com_dir: Path, output_dir: Path, verbose: bool = False) -> bool:
    com_id = com_dir.name

    book_dirs = sorted(d for d in com_dir.iterdir() if d.is_dir() and not d.name.startswith("_"))

    # Deduplicate by canonical book_id
    found = {}  # book_id -> (helloao_id, dir_path)
    dupes = set()
    for bd in book_dirs:
        hid = bd.name
        if hid not in HELLOAO_BOOKS:
            print(f"  [SKIP] Unknown book '{hid}' in {com_id}", flush=True)
            continue
        bid = HELLOAO_BOOKS[hid][0]
        if bid in found:
            dupes.add(hid)
            if verbose:
                print(f"  [WARN] Dup book '{hid}' (same as '{found[bid][0]}'), skipping", flush=True)
            continue
        found[bid] = (hid, bd)

    if not found:
        print(f"  [SKIP] No recognized books in {com_id}", flush=True)
        return False

    # Build books sheet
    wb = openpyxl.Workbook()
    ws_books = wb.active
    ws_books.title = "books"
    ws_books.append(("book_id", "osis", "eng_name", "name", "testament", "chapters"))
    ws_books.append((0, "INTRO", "General Intro", "General Introduction", "INTRO", 0))

    # Sort found by canonical book_id
    for bid in sorted(found):
        hid, _ = found[bid]
        _, osis, eng_name, testament, chapters = HELLOAO_BOOKS[hid]
        ws_books.append((bid, osis, eng_name, eng_name, testament, chapters))

    # Verses sheet
    ws_verses = wb.create_sheet("verses")
    ws_verses.append(("book_id", "chapter", "verse", "text"))

    total_rows = 0
    for bid in sorted(found):
        hid, bd = found[bid]

        # Book-level intro
        intro_file = bd / "_intro.json"
        if intro_file.exists():
            try:
                intro_data = json.loads(intro_file.read_text(encoding="utf-8"))
                intro_text = intro_data.get("introduction", "")
                if intro_text:
                    ws_verses.append((bid, 0, 0, intro_text))
                    total_rows += 1
            except (json.JSONDecodeError, OSError) as e:
                if verbose:
                    print(f"  [WARN] Can't read intro {intro_file}: {e}", flush=True)

        # Chapter files
        ch_files = sorted(
            f for f in bd.iterdir()
            if f.suffix == ".json" and not f.name.startswith("_")
        )

        for ch_file in ch_files:
            try:
                ch_num = int(ch_file.stem)
            except ValueError:
                if verbose:
                    print(f"  [WARN] Non-numeric chapter file: {ch_file}", flush=True)
                continue

            try:
                ch_data = json.loads(ch_file.read_text(encoding="utf-8"))
            except (json.JSONDecodeError, OSError) as e:
                if verbose:
                    print(f"  [WARN] Can't read {ch_file}: {e}", flush=True)
                continue

            chapter = ch_data.get("chapter")
            if not isinstance(chapter, dict):
                continue

            ch_intro = chapter.get("introduction", "")
            content = chapter.get("content", [])

            # Extract verse content
            verses_map = {}
            for item in content:
                if isinstance(item, dict) and item.get("type") == "verse":
                    vnum = item.get("number")
                    texts = item.get("content", [])
                    if texts and vnum is not None:
                        verses_map[vnum] = "\n\n".join(texts)

            # Chapter intro → attach to verse 1 if exists, otherwise verse 1 with intro only
            if ch_intro:
                if 1 in verses_map:
                    verses_map[1] = ch_intro + "\n\n" + verses_map[1]
                else:
                    verses_map[1] = ch_intro

            for vnum in sorted(verses_map):
                ws_verses.append((bid, ch_num, vnum, verses_map[vnum]))
                total_rows += 1

    # Version sheet
    label = com_id.replace("-", " ").title()
    ws_ver = wb.create_sheet("version")
    ws_ver.append(("slug", "label"))
    ws_ver.append((com_id, label))

    out_path = output_dir / f"{com_id}.xlsx"
    output_dir.mkdir(parents=True, exist_ok=True)
    wb.save(str(out_path))
    print(f"  OK: {out_path}  ({total_rows} verses, {len(found)} books)", flush=True)
    return True


def collect_com_dirs(path: Path) -> list[Path]:
    if path.is_file():
        return []
    if path.is_dir():
        # Check if this is a commentary dir (has book subdirs)
        has_subdirs = any(p.is_dir() and not p.name.startswith("_") for p in path.iterdir())
        if has_subdirs and (path / "..").resolve().name:
            # Could be a single commentary dir or a parent of many
            # Heuristic: if it has a book dir that's in HELLOAO_BOOKS, it's single
            for p in path.iterdir():
                if p.is_dir() and p.name in HELLOAO_BOOKS:
                    return [path]
            # Otherwise treat as parent of multiple commentary dirs
            return sorted(p for p in path.iterdir() if p.is_dir() and not p.name.startswith("_"))
        return sorted(p for p in path.iterdir() if p.is_dir() and not p.name.startswith("_"))
    print(f"  [SKIP] Not found: {path}", flush=True)
    return []


def main():
    ap = argparse.ArgumentParser(
        description="Convert helloao commentary directory to XLSX.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    ap.add_argument("input", nargs="+", help="Commentary directory or parent dir")
    ap.add_argument(
        "--output-dir", "-o", default="./xlsx", help="Output directory (default: ./xlsx)"
    )
    ap.add_argument("--verbose", "-v", action="store_true", help="Log warnings")
    args = ap.parse_args()

    output_dir = Path(args.output_dir)

    com_dirs = []
    for inp in args.input:
        com_dirs.extend(collect_com_dirs(Path(inp)))
    com_dirs = sorted(set(com_dirs))
    if not com_dirs:
        print("No commentary directories found.", flush=True)
        sys.exit(1)

    ok = 0
    for cd in com_dirs:
        if convert_com_to_xlsx(cd, output_dir, args.verbose):
            ok += 1

    print(f"\nDone: {ok}/{len(com_dirs)} converted -> {output_dir}/", flush=True)
    sys.exit(0 if ok == len(com_dirs) else 1)


if __name__ == "__main__":
    main()
