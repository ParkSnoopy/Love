#!/usr/bin/env python3
"""
fix_book_names.py — Localize books.name in non-Korean Bible SQLite databases.

Usage:
  python tools/fix_book_names.py
  python tools/fix_book_names.py --dir path/to/sqlite/files
  python tools/fix_book_names.py --dry-run
"""

import argparse
import os
import sqlite3
from pathlib import Path
from book_names_localization import get_localized_book_names


def fix_database(db_path: Path, dry_run: bool = False) -> bool:
    filename = db_path.name
    print(f"\nProcessing database: {db_path.resolve().relative_to(Path.cwd().resolve())}")

    # Check if Korean
    if "kor_" in filename or filename.startswith("kor"):
        print("  [SKIP] Korean database, keeping Korean names.")
        return False

    # Try to get localized book names mapping
    mapping = get_localized_book_names(filename)

    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        # Check if books table exists
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='books';")
        if not cursor.fetchone():
            print("  [SKIP] No 'books' table found in this database.")
            conn.close()
            return False

        # Read existing books
        cursor.execute("SELECT book_id, osis, eng_name, name FROM books;")
        books = cursor.fetchall()

        if not books:
            print("  [SKIP] 'books' table is empty.")
            conn.close()
            return False

        updates = []
        for book_id, osis, eng_name, current_name in books:
            new_name = None
            if mapping is None:
                # English or fallback to eng_name
                new_name = eng_name
            else:
                new_name = mapping.get(book_id)

            if new_name and current_name != new_name:
                updates.append((new_name, book_id, current_name))

        if not updates:
            print("  [OK] All book names are already correctly localized.")
            conn.close()
            return False

        print(f"  Found {len(updates)} book name(s) to localize:")
        for new_name, book_id, old_name in updates[:5]:
            print(f"    Book {book_id}: '{old_name}' -> '{new_name}'")
        if len(updates) > 5:
            print(f"    ... and {len(updates) - 5} more")

        if dry_run:
            print("  [DRY RUN] Skipping actual updates.")
            conn.close()
            return True

        # Perform update
        for new_name, book_id, _ in updates:
            cursor.execute(
                "UPDATE books SET name = ? WHERE book_id = ?;",
                (new_name, book_id)
            )

        conn.commit()
        print("  [SUCCESS] Updated book names in 'books' table.")

        # Re-verify and VACUUM
        print("  Optimizing database with VACUUM...")
        cursor.execute("VACUUM;")
        conn.close()
        return True

    except Exception as exc:
        print(f"  [ERROR] Failed to process database {filename}: {exc}")
        return False


def main():
    parser = argparse.ArgumentParser(description="Fix and localize Bible book names in SQLite files")
    parser.add_argument(
        "--dir",
        "-d",
        default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "data"),
        help="Directory containing SQLite files to process (default: tools/data/)"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Display updates without writing them to disk"
    )
    args = parser.parse_args()

    search_path = Path(args.dir).resolve()
    if not search_path.exists():
        print(f"[ERROR] Path does not exist: {search_path}")
        return

    sqlite_files = []
    # Recursively find all sqlite files
    for root, _, files in os.walk(search_path):
        for file in files:
            if file.endswith((".sqlite", ".sqlite3", ".db")):
                sqlite_files.append(Path(root) / file)

    if not sqlite_files:
        print(f"No SQLite databases found in {search_path}")
        return

    print(f"Found {len(sqlite_files)} SQLite database(s).")
    updated_count = 0
    for db_path in sorted(sqlite_files):
        if fix_database(db_path, dry_run=args.dry_run):
            updated_count += 1

    print(f"\nDone. Processed {len(sqlite_files)} databases. Updated {updated_count}.")


if __name__ == "__main__":
    main()
