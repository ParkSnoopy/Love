"""Find and repair missing Bible chapters in crawled SQLite files.

Typical use:
  python tools/fix_missing_verses.py --target aram_phv
  python tools/fix_missing_verses.py --target aram_phv --dry-run

What it fixes:
  - Crawled DB exists, but some articles were skipped because their title did not parse.
  - If an unparseable title is between two parsed chapters from the same book, infer it.
    Example: 2 Corinthians ch.2, "3 Corinthians ch.3", 2 Corinthians ch.4
    -> infer 2 Corinthians ch.3 and upsert verses into SQLite.
"""

import argparse
import os
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(__file__))

from extractors import BOOK_BY_ID, title_to_book_chapter  # noqa: E402
from nocr_crawler import (  # noqa: E402
    BASE_URL,
    NocrBoardCrawler,
    extract_content_html,
    fetch,
)
from run_crawl import _REGISTRY_MAP  # noqa: E402

SQLITE_SUFFIXES = {".sqlite", ".sqlite3", ".db"}


def existing_chapters(db_path: Path) -> set[tuple[int, int]]:
    with sqlite3.connect(db_path) as con:
        rows = con.execute(
            "SELECT DISTINCT book_id, chapter FROM verses WHERE book_id > 0 AND chapter > 0"
        ).fetchall()
    return {(int(book_id), int(chapter)) for book_id, chapter in rows}


def upsert_rows(db_path: Path, rows: list[dict]) -> None:
    with sqlite3.connect(db_path) as con:
        con.executemany(
            "INSERT OR REPLACE INTO verses (book_id, chapter, verse, text) VALUES (?, ?, ?, ?)",
            [(r["book_id"], r["chapter"], r["verse"], r["text"]) for r in rows],
        )
        con.commit()


def synthetic_title(book_id: int, chapter: int) -> str:
    eng_name = BOOK_BY_ID[book_id][2]
    return f"Repair, {eng_name}, Chapter {chapter:02d}"


def infer_unparseable_articles(
    articles: list[tuple[int, str]],
) -> list[tuple[int, str, int, int, str]]:
    """Return (srl, original_title, inferred_book_id, inferred_chapter, reason)."""
    parsed: list[tuple[int, str, tuple[int, int] | None]] = [
        (srl, title, title_to_book_chapter(title)) for srl, title in articles
    ]

    fixes = []
    for idx, (srl, title, current) in enumerate(parsed):
        if current is not None:
            continue

        prev_item = next((p for p in reversed(parsed[:idx]) if p[2] is not None), None)
        next_item = next((p for p in parsed[idx + 1 :] if p[2] is not None), None)
        if not prev_item or not next_item:
            continue

        prev_parsed = prev_item[2]
        next_parsed = next_item[2]
        if prev_parsed is None or next_parsed is None:
            continue
        prev_book, prev_ch = prev_parsed
        next_book, next_ch = next_parsed
        if prev_book == next_book and next_ch == prev_ch + 2:
            fixes.append(
                (
                    srl,
                    title,
                    prev_book,
                    prev_ch + 1,
                    f"between {BOOK_BY_ID[prev_book][2]} {prev_ch} and {next_ch}",
                )
            )

    return fixes


def repair_target(
    target_id: str, db_path: str | None, dry_run: bool, retries: int
) -> int:
    if target_id not in _REGISTRY_MAP:
        print(f"[ERROR] Unknown target: {target_id}")
        return 1

    entry = _REGISTRY_MAP[target_id]
    if entry["type"] != "bible":
        print(f"[ERROR] Only bible targets supported: {target_id}")
        return 1

    sqlite_path = Path(db_path or entry["out_path"])
    if not sqlite_path.exists():
        print(f"[ERROR] SQLite file not found: {sqlite_path}")
        return 1

    crawler = NocrBoardCrawler(
        board_id=entry["board_id"],
        extractor=entry["extractor"],
        packager=None,
        retries=retries,
    )
    articles = crawler.collect_article_list()
    fixes = infer_unparseable_articles(articles)
    present = existing_chapters(sqlite_path)

    print(f"[{target_id}] inferred fix candidates: {len(fixes)}")
    repaired = 0
    skipped_present = 0
    failed = 0

    for srl, original_title, book_id, chapter, reason in fixes:
        book_name = BOOK_BY_ID[book_id][2]
        if (book_id, chapter) in present:
            skipped_present += 1
            print(f"  [SKIP] already present: {book_name} {chapter} from srl={srl}")
            continue

        fixed_title = synthetic_title(book_id, chapter)
        print(
            f"  [FIX] srl={srl}: '{original_title}' -> {book_name} {chapter} ({reason})",
            flush=True,
        )
        if dry_run:
            continue

        try:
            url = f"{BASE_URL}/{entry['board_id']}/{srl}?listStyle=viewer"
            html = fetch(url, retries=retries, label=f"article {srl}")
            content_html = extract_content_html(html)
            if content_html is None:
                print(f"    [ERROR] No content div: {url}")
                failed += 1
                continue
            rows = entry["extractor"].extract(srl, fixed_title, content_html)
            if not rows:
                print(f"    [ERROR] Extracted 0 rows: srl={srl}")
                failed += 1
                continue
            upsert_rows(sqlite_path, rows)
            repaired += 1
            present.add((book_id, chapter))
            print(f"    Upserted {len(rows)} verse rows")
        except Exception as exc:
            print(f"    [ERROR] repair failed: {exc}")
            failed += 1

    print(
        f"Done. repaired={repaired}, skipped_present={skipped_present}, failed={failed}, dry_run={dry_run}"
    )
    return 0 if failed == 0 else 1


def iter_sqlite_files(folder: Path):
    for path in sorted(folder.rglob("*")):
        if path.is_file() and path.suffix.lower() in SQLITE_SUFFIXES:
            yield path


def target_for_db_path(db_path: Path) -> str | None:
    """Infer target id by matching sqlite filename to run_crawl registry output filename."""
    matches = [
        target_id
        for target_id, entry in _REGISTRY_MAP.items()
        if entry.get("type") == "bible" and Path(entry["out_path"]).name == db_path.name
    ]
    if len(matches) == 1:
        return matches[0]
    return None


def repair_folder(folder: Path, dry_run: bool, retries: int) -> int:
    db_files = list(iter_sqlite_files(folder))
    print(f"Found {len(db_files)} SQLite file(s) under {folder}", flush=True)
    repaired_targets = 0
    skipped_unknown = 0
    failed = 0

    for db_file in db_files:
        target_id = target_for_db_path(db_file)
        if target_id is None:
            skipped_unknown += 1
            print(f"[SKIP] Cannot infer target for {db_file}", flush=True)
            continue

        print(
            f"\n{'=' * 60}\nTarget: {target_id}\nDB: {db_file}\n{'=' * 60}", flush=True
        )
        code = repair_target(target_id, str(db_file), dry_run, retries)
        if code == 0:
            repaired_targets += 1
        else:
            failed += 1

    print(
        f"Folder done. ok={repaired_targets}, skipped_unknown={skipped_unknown}, failed={failed}",
        flush=True,
    )
    return 0 if failed == 0 else 1


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Find and repair missing chapters in crawled Bible SQLite files"
    )
    parser.add_argument(
        "--target",
        "-t",
        help="Target ID from run_crawl.py, e.g. aram_phv. Optional when --db is a folder.",
    )
    parser.add_argument(
        "--db",
        help="SQLite path override, or folder to scan recursively. Defaults to target output path.",
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="Only report fixes; do not write SQLite"
    )
    parser.add_argument(
        "--retries", type=int, default=5, help="HTTP retries for article repair fetches"
    )
    args = parser.parse_args()

    if args.db and Path(args.db).is_dir():
        return repair_folder(Path(args.db), args.dry_run, args.retries)

    if not args.target:
        print("[ERROR] --target is required unless --db is a folder")
        return 1

    return repair_target(args.target, args.db, args.dry_run, args.retries)


if __name__ == "__main__":
    raise SystemExit(main())
