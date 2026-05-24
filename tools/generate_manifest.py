#!/usr/bin/env python3
"""
generate_manifest.py — Generate assets/data/manifest.json from SQLite databases.

This script scans assets/data/ recursively for SQLite databases, queries each
database's 'version' table to extract slug and label, determines type, language,
source, and relative path, and writes a pretty-printed JSON manifest.

Usage:
  python tools/generate_manifest.py
  python tools/generate_manifest.py --dir assets/data
"""

import argparse
import json
import os
import sqlite3
from pathlib import Path

# Language prefix to display name mapping
LANG_MAP = {
    "da": "Danish",
    "de": "German",
    "eo": "Esperanto",
    "es": "Spanish",
    "fi": "Finnish",
    "fr": "French",
    "he": "Hebrew",
    "hr": "Croatian",
    "hu": "Hungarian",
    "it": "Italian",
    "la": "Latin",
    "lt": "Lithuanian",
    "mi": "Maori",
    "my": "Burmese",
    "nl": "Dutch",
    "no": "Norwegian",
    "pt": "Portuguese",
    "ro": "Romanian",
    "sv": "Swedish",
    "th": "Thai",
    "tl": "Tagalog",
    "tr": "Turkish",
    "vi": "Vietnamese",
    "kor": "Korean",
    "eng": "English",
    "grk": "Greek",
    "heb": "Hebrew",
    "aram": "Aramaic",
    "lat": "Latin",
    "ja": "Japanese",
    "jap": "Japanese",
    "jpn": "Japanese",
    "zh": "Chinese",
    "zho": "Chinese",
    "chi": "Chinese",
    "cmn": "Chinese",
    "deu": "German",
}


def get_metadata_from_db(db_path: Path) -> tuple[str, str]:
    """Query slug and label from the version table of the database."""
    slug, label = "", ""
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        # Check if version table exists
        cursor.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='version';"
        )
        if cursor.fetchone():
            cursor.execute("SELECT slug, label FROM version LIMIT 1;")
            row = cursor.fetchone()
            if row:
                slug, label = str(row[0]), str(row[1])
        conn.close()
    except Exception as exc:
        print(f"  [WARN] Failed to read version table from {db_path.name}: {exc}")

    return slug, label


def process_database(db_path: Path, data_dir: Path) -> dict | None:
    filename = db_path.name
    # Compute relative path using forward slashes for cross-platform compatibility
    rel_path = db_path.relative_to(data_dir).as_posix()

    # 1. Read metadata from DB
    db_slug, db_label = get_metadata_from_db(db_path)

    # Fallback values if DB metadata is missing
    basename = db_path.stem
    if not db_slug:
        db_slug = basename
    if not db_label:
        db_label = basename.replace("_", " ").title()

    # 2. Determine type (commentary vs bible)
    # Check if the path contains 'comment' or starts with 'com_'
    is_commentary = "comment" in db_path.parts or basename.lower().startswith("com_")
    db_type = "commentary" if is_commentary else "bible"

    # 3. Determine source
    # We use 'getbible' or 'nocr' based on folder/filename
    if "getbible" in db_path.parts:
        source = "getbible"
    else:
        source = "nocr"

    # 4. Determine language
    parts = basename.lower().split("_")
    if basename.startswith("com_kor_"):
        lang_prefix = "kor"
    elif basename.startswith("com_") and len(parts) > 1:
        lang_prefix = parts[1]
    else:
        lang_prefix = parts[0] if parts else "unknown"

    language = LANG_MAP.get(lang_prefix, lang_prefix.capitalize())

    # Build the pack manifest dictionary
    return {
        "id": basename,
        "shortname": db_label,  # JSON key in Dart model is 'shortname'
        "name": db_label,
        "language": language,
        "type": db_type,
        "file": rel_path,
        "source": source,
    }


def pack_sort_key(pack: dict) -> tuple:
    type_rank = {"bible": 0, "commentary": 1}.get(pack["type"], 2)
    korean_rank = 0 if pack["language"] == "Korean" else 1
    return (type_rank, korean_rank, pack["language"].lower(), pack["name"].lower(), pack["id"].lower())


def main():
    # Allow running from anywhere, but default to root workspace path
    default_dir = Path(__file__).resolve().parent.parent / "assets" / "data"

    parser = argparse.ArgumentParser(
        description="Generate manifest.json for assets/data/"
    )
    parser.add_argument(
        "--dir",
        "-d",
        default=str(default_dir),
        help="Directory containing assets/data/ (default: assets/data/)",
    )
    args = parser.parse_args()

    data_dir = Path(args.dir).resolve()
    if not data_dir.exists():
        print(f"[ERROR] Directory does not exist: {data_dir}")
        return

    print(f"Scanning directory: {data_dir}")

    sqlite_files = []
    for root, _, files in os.walk(data_dir):
        for file in files:
            if file.endswith((".sqlite", ".sqlite3", ".db")):
                sqlite_files.append(Path(root) / file)

    if not sqlite_files:
        print("No SQLite databases found.")
        return

    print(f"Found {len(sqlite_files)} SQLite database(s). Processing...")

    packs = []
    for db_path in sorted(sqlite_files):
        pack = process_database(db_path, data_dir)
        if pack:
            packs.append(pack)

    # Sort packs: Bibles, then Commentaries. Inside each: Korean first, then others sorted.
    packs.sort(key=pack_sort_key)

    # Write manifest.json
    output_path = data_dir / "manifest.json"
    try:
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(packs, f, ensure_ascii=False, indent=2)
        print(
            f"\n[SUCCESS] Generated manifest with {len(packs)} packs at: {output_path}"
        )

        # Summary counts
        bibles_count = sum(1 for p in packs if p["type"] == "bible")
        comments_count = sum(1 for p in packs if p["type"] == "commentary")
        print(f"  - Bibles: {bibles_count}")
        print(f"  - Commentaries: {comments_count}")

    except Exception as exc:
        print(f"[ERROR] Failed to write manifest: {exc}")


if __name__ == "__main__":
    main()
