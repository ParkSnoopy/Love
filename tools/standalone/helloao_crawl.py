#!/usr/bin/env python3
"""helloao_crawl.py - Download Bibles from Free Use Bible API (bible.helloao.org)

Usage:
    python helloao_crawl.py --list                   # List all translations
    python helloao_crawl.py --list --lang eng         # List English only
    python helloao_crawl.py --lang eng                # Download all English translations
    python helloao_crawl.py BSB                       # Download BSB only
    python helloao_crawl.py BSB,WEB,ESV               # Multiple by ID
    python helloao_crawl.py BSB --verify              # Verify SHA256 checksum
    python helloao_crawl.py BSB --full-only           # Only full Bibles (66 books, 1189 chapters)

Deps: requests (pip install requests)
"""

import argparse
import hashlib
import json
import os
import sys

import requests

API_BASE = "https://bible.helloao.org/api"


# ---------------------------------------------------------------------------
# API
# ---------------------------------------------------------------------------


def fetch_json(url):
    resp = requests.get(url, timeout=300)
    resp.raise_for_status()
    return resp.json()


def get_translations():
    """Return list of translation objects from available_translations.json."""
    data = fetch_json(f"{API_BASE}/available_translations.json")
    return data["translations"]


# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------


def display_translations(translations, lang_filter=None):
    by_lang = {}
    for t in translations:
        lang = t.get("language", "??")
        if lang_filter:
            if lang.lower() not in lang_filter:
                continue
        by_lang.setdefault(lang, []).append(t)

    for lang in sorted(by_lang.keys()):
        items = by_lang[lang]
        lang_name = (
            items[0].get("languageName") or items[0].get("languageEnglishName") or lang
        )
        print(f"\n  [{lang}] {lang_name}")
        for t in sorted(items, key=lambda x: x["id"]):
            tid = t["id"]
            name = t.get("name", "?")
            books = t.get("numberOfBooks", "?")
            chaps = t.get("totalNumberOfChapters", "?")
            print(f"    {tid:<20} {name}  ({books} books, {chaps} ch)")


# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------


def verify_sha256(filepath, expected_sha):
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while True:
            chunk = f.read(65536)
            if not chunk:
                break
            h.update(chunk)
    actual = h.hexdigest()
    if actual.lower() != expected_sha.lower():
        print(f"    SHA256 FAIL: {os.path.basename(filepath)}")
        print(f"      expected: {expected_sha}")
        print(f"      actual:   {actual}")
        return False
    print(f"    SHA256 OK")
    return True


# ---------------------------------------------------------------------------
# Download
# ---------------------------------------------------------------------------


def download_translation(translation, output_dir, verify=False, dry_run=False):
    tid = translation["id"]
    expected_sha = translation.get("sha256")
    filename = f"{tid}.json"
    filepath = os.path.join(output_dir, filename)
    url = f"{API_BASE}/{tid}/complete.json"

    if dry_run:
        print(f"  [DRY-RUN] {tid} -> {filename}")
        return True

    if os.path.exists(filepath):
        print(f"  EXISTS: {filename}")
        if verify and expected_sha:
            verify_sha256(filepath, expected_sha)
        return True

    print(f"  DOWNLOAD: {filename}")
    try:
        resp = requests.get(url, timeout=600, stream=True)
        resp.raise_for_status()
        with open(filepath, "wb") as f:
            for chunk in resp.iter_content(chunk_size=65536):
                f.write(chunk)
        print(f"    OK -> {filepath}")
        if expected_sha and verify:
            verify_sha256(filepath, expected_sha)
        return True
    except Exception as e:
        print(f"    FAIL: {e}", file=sys.stderr)
        if os.path.exists(filepath):
            os.remove(filepath)
        return False


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def resolve_ids(translations, lang_filter=None):
    """Return list of translation ID strings matching filters."""
    ids = [t["id"] for t in translations]
    if lang_filter:
        ids = [
            t["id"]
            for t in translations
            if t.get("language", "").lower() in lang_filter
        ]
    return sorted(ids)


def build_id_map(translations):
    """Build case-insensitive map: lower_id -> translation object."""
    m = {}
    for t in translations:
        m[t["id"].lower()] = t
    return m


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main():
    ap = argparse.ArgumentParser(
        description="Download Bibles from Free Use Bible API (bible.helloao.org)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    ap.add_argument(
        "ids", nargs="*", help="Translation ID(s) to download (e.g. BSB WEB ESV)"
    )
    ap.add_argument("--list", action="store_true", help="List available translations")
    ap.add_argument(
        "--lang",
        help="Filter by language code(s) comma-separated (e.g. 'eng' or 'eng,spa')",
    )
    ap.add_argument(
        "--output-dir",
        default="./helloao",
        help="Download directory (default: ./helloao)",
    )
    ap.add_argument(
        "--verify", action="store_true", help="Verify SHA256 checksums after download"
    )
    ap.add_argument(
        "--dry-run", action="store_true", help="Show what would download, don't fetch"
    )
    ap.add_argument(
        "--full-only",
        action="store_true",
        help="Only download full Bibles (66 canonical books)",
    )
    args = ap.parse_args()

    lang_filter = None
    if args.lang:
        lang_filter = set(c.strip().lower() for c in args.lang.split(","))

    print("Fetching translations list ...", file=sys.stderr)
    try:
        translations = get_translations()
    except requests.RequestException as e:
        print(f"Error fetching translations: {e}", file=sys.stderr)
        sys.exit(1)

    if args.list:
        display_translations(translations, lang_filter)
        return

    # Resolve which translations to download
    id_map = build_id_map(translations)

    if not args.ids:
        if args.lang:
            selected = resolve_ids(translations, lang_filter)
            selected = [id_map[s.lower()] for s in selected]
        else:
            display_translations(translations, lang_filter)
            print("\nUse --lang or pass translation ID(s) to download. See --help.")
            return
    else:
        # Match provided IDs case-insensitively against the map
        selected = []
        for raw_id in args.ids:
            key = raw_id.lower()
            if key in id_map:
                selected.append(id_map[key])
            else:
                print(
                    f"  WARN: translation '{raw_id}' not found, skipping",
                    file=sys.stderr,
                )
        if not selected:
            print("No matching translations found.", file=sys.stderr)
            sys.exit(1)

    if args.full_only:
        print("\nChecking book/chapter counts for --full-only filter ...", flush=True)
        filtered = []
        for t in selected:
            tid = t["id"]
            books = t.get("numberOfBooks", 0)
            chaps = t.get("totalNumberOfChapters", 0)
            if books >= 66 and chaps >= 1189:
                filtered.append(t)
                print(f"  {tid}: {books} books, {chaps} ch - OK", flush=True)
            else:
                print(
                    f"  {tid}: {books} books, {chaps} ch - SKIP (partial)", flush=True
                )
        selected = filtered

    if not selected:
        print("No full-Bible translations match filters.", flush=True)
        sys.exit(0)

    print(f"\nDownloading {len(selected)} translation(s):")
    for t in selected:
        tid = t["id"]
        name = t.get("name", "?")
        lang = t.get("language", "??")
        print(f"  {tid}: {name} [{lang}]")

    os.makedirs(args.output_dir, exist_ok=True)
    for t in selected:
        download_translation(t, args.output_dir, args.verify, args.dry_run)

    print("\nDone.")


if __name__ == "__main__":
    main()
