#!/usr/bin/env python3
"""helloao_com_crawl.py - Download Bible commentaries from Free Use Bible API

Usage:
    python helloao_com_crawl.py --list                                   # List all commentaries
    python helloao_com_crawl.py adam-clarke                              # Download Adam Clarke
    python helloao_com_crawl.py adam-clarke,matthew-henry                # Multiple by ID
    python helloao_com_crawl.py adam-clarke --skip-intro                 # Skip book introductions
    python helloao_com_crawl.py adam-clarke --verify                     # Verify SHA256
    python helloao_com_crawl.py --all                                    # Download all commentaries

Deps: requests
"""

import argparse
import hashlib
import json
import os
import sys
import time
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests

API_BASE = "https://bible.helloao.org/api"


# ---------------------------------------------------------------------------
# API
# ---------------------------------------------------------------------------


def fetch_json(url):
    resp = requests.get(url, timeout=120)
    resp.raise_for_status()
    return resp.json()


def get_commentaries():
    data = fetch_json(f"{API_BASE}/available_commentaries.json")
    return data["commentaries"]


# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------


def display_commentaries(commentaries, lang_filter=None):
    by_lang = {}
    for c in commentaries:
        lang = c.get("language", "??")
        if lang_filter and lang.lower() not in lang_filter:
            continue
        by_lang.setdefault(lang, []).append(c)

    for lang in sorted(by_lang.keys()):
        items = by_lang[lang]
        lang_name = (
            items[0].get("languageName") or items[0].get("languageEnglishName") or lang
        )
        print(f"\n  [{lang}] {lang_name}")
        for c in sorted(items, key=lambda x: x["id"]):
            cid = c["id"]
            name = c.get("name", "?")
            books = c.get("numberOfBooks", "?")
            chaps = c.get("totalNumberOfChapters", "?")
            print(f"    {cid:<30} {name}  ({books} books, {chaps} ch)")


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
# Parallel download
# ---------------------------------------------------------------------------

_print_lock = threading.Lock()


def _download_one(url, filepath, label="", retries=3, verbose=False, timeout=300):
    for attempt in range(retries):
        try:
            resp = requests.get(url, timeout=timeout, stream=True)
            resp.raise_for_status()
            # Peek at first byte — bail fast if not JSON
            it = resp.iter_content(chunk_size=65536)
            first = next(it, None)
            if first is None:
                raise ValueError("Empty response")
            if first[0:1] not in (b"{", b"["):
                raise ValueError("Not JSON (HTML error page)")
            os.makedirs(os.path.dirname(filepath), exist_ok=True)
            with open(filepath, "wb") as f:
                f.write(first)
                for chunk in it:
                    f.write(chunk)
            if verbose:
                with _print_lock:
                    print(f"    OK: {label}", flush=True)
            return True
        except ValueError:
            return False  # permanent — HTML error page, don't retry
        except Exception:
            if os.path.exists(filepath):
                os.remove(filepath)
            if attempt < retries - 1:
                time.sleep(2**attempt)
    if verbose:
        with _print_lock:
            print(f"    FAIL: {label}", flush=True)
    return False


# ---------------------------------------------------------------------------
# Commentary download (parallel per-chapter)
# ---------------------------------------------------------------------------


def download_commentary(
    com_info,
    output_dir,
    skip_intro=False,
    verify=False,
    dry_run=False,
    workers=8,
    verbose=False,
    timeout=300,
):
    cid = com_info["id"]
    base_dir = os.path.join(output_dir, cid)
    expected_sha = com_info.get("sha256")

    if dry_run:
        print(f"  [DRY-RUN] {cid}")
        return True

    print(f"\n  Fetching books for {cid} ...")
    try:
        books_data = fetch_json(f"{API_BASE}/c/{cid}/books.json")
    except requests.RequestException as e:
        print(f"    FAIL: books list: {e}", file=sys.stderr)
        return False

    books = books_data["books"]
    print(f"    {len(books)} books found")

    # Collect all chapters to download
    chapters = []
    for book in books:
        bid = book["id"]
        bname = book.get("commonName", bid)
        bdir = os.path.join(base_dir, bid)

        intro = book.get("introduction")
        if intro and not skip_intro:
            intro_path = os.path.join(bdir, "_intro.json")
            if not os.path.exists(intro_path):
                os.makedirs(bdir, exist_ok=True)
                with open(intro_path, "w", encoding="utf-8") as f:
                    json.dump(
                        {"bookId": bid, "introduction": intro}, f, ensure_ascii=False
                    )

        first_ch = book.get("firstChapterNumber") or 1
        last_ch = book.get("lastChapterNumber") or book.get("numberOfChapters") or 0
        for ch_num in range(first_ch, last_ch + 1):
            ch_path = os.path.join(bdir, f"{ch_num}.json")
            if os.path.exists(ch_path):
                continue
            ch_url = f"{API_BASE}/c/{cid}/{bid}/{ch_num}.json"
            label = f"{cid}/{bname} ch{ch_num}"
            chapters.append((ch_url, ch_path, label))

    if not chapters:
        print(f"    All chapters already downloaded")
        return True

    total = len(chapters)
    print(f"    Downloading {total} chapters ({workers} workers) ...")

    succeeded = 0
    failed_labels = []

    with ThreadPoolExecutor(max_workers=workers) as ex:
        fut_map = {
            ex.submit(_download_one, url, path, label, 3, verbose, timeout): label
            for url, path, label in chapters
        }
        for fut in as_completed(fut_map):
            label = fut_map[fut]
            if fut.result():
                succeeded += 1
                if succeeded % 500 == 0 or succeeded == total:
                    print(f"    ... {succeeded}/{total} chapters", flush=True)
            else:
                failed_labels.append(label)

    if failed_labels:
        print(f"    FAILED: {len(failed_labels)}/{total} chapters", flush=True)
        for lbl in failed_labels[:10]:
            print(f"      {lbl}", flush=True)
    else:
        print(f"    OK: {succeeded}/{total} chapters", flush=True)

    if verify and expected_sha:
        print(f"  Assembling full JSON for SHA256 verification ...")
        full = assemble_commentary(cid, base_dir)
        full_path = os.path.join(base_dir, f"_{cid}_full.json")
        with open(full_path, "w", encoding="utf-8") as f:
            json.dump(full, f, ensure_ascii=False)
        verify_sha256(full_path, expected_sha)

    return True


def assemble_commentary(cid, base_dir):
    books_list = []
    for entry in sorted(os.listdir(base_dir)):
        entry_path = os.path.join(base_dir, entry)
        if not os.path.isdir(entry_path):
            continue
        bid = entry
        chapters = []
        for ch_file in sorted(os.listdir(entry_path)):
            if ch_file.startswith("_") or not ch_file.endswith(".json"):
                continue
            ch_path = os.path.join(entry_path, ch_file)
            try:
                with open(ch_path, "r", encoding="utf-8") as f:
                    ch_data = json.load(f)
                chapters.append(ch_data.get("chapter", ch_data))
            except (json.JSONDecodeError, OSError):
                pass
        if chapters:
            json_files = sorted(
                f
                for f in os.listdir(entry_path)
                if f.endswith(".json") and not f.startswith("_")
            )
            if json_files:
                try:
                    with open(
                        os.path.join(entry_path, json_files[0]), "r", encoding="utf-8"
                    ) as f:
                        first_data = json.load(f)
                    book_info = first_data.get("book", {"id": bid, "name": bid})
                except (OSError, json.JSONDecodeError):
                    book_info = {"id": bid, "name": bid}
            else:
                book_info = {"id": bid, "name": bid}
            book_info["chapters"] = chapters
            books_list.append(book_info)
    return {"commentary": {"id": cid}, "books": books_list}


# ---------------------------------------------------------------------------
# Resolve
# ---------------------------------------------------------------------------


def build_id_map(commentaries):
    return {c["id"].lower(): c for c in commentaries}


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main():
    ap = argparse.ArgumentParser(
        description="Download Bible commentaries from Free Use Bible API (bible.helloao.org)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    ap.add_argument(
        "ids",
        nargs="*",
        help="Commentary ID(s) to download (e.g. adam-clarke matthew-henry)",
    )
    ap.add_argument("--list", action="store_true", help="List available commentaries")
    ap.add_argument(
        "--lang", help="Filter by language code(s) comma-separated (e.g. 'eng')"
    )
    ap.add_argument("--all", action="store_true", help="Download all commentaries")
    ap.add_argument(
        "--output-dir",
        default="./helloao_com",
        help="Download directory (default: ./helloao_com)",
    )
    ap.add_argument(
        "--verify", action="store_true", help="Verify SHA256 checksums after download"
    )
    ap.add_argument(
        "--dry-run", action="store_true", help="Show what would download, don't fetch"
    )
    ap.add_argument("--skip-intro", action="store_true", help="Skip book introductions")
    ap.add_argument(
        "--workers", type=int, default=8, help="Parallel download workers (default: 8)"
    )
    ap.add_argument(
        "--verbose", "-v", action="store_true", help="Log each chapter download"
    )
    ap.add_argument(
        "--timeout", type=int, default=300, help="Request timeout in seconds (default: 300)"
    )
    args = ap.parse_args()

    lang_filter = None
    if args.lang:
        lang_filter = set(c.strip().lower() for c in args.lang.split(","))

    print("Fetching commentaries list ...", file=sys.stderr)
    try:
        commentaries = get_commentaries()
    except requests.RequestException as e:
        print(f"Error fetching commentaries: {e}", file=sys.stderr)
        sys.exit(1)

    if args.list:
        display_commentaries(commentaries, lang_filter)
        return

    id_map = build_id_map(commentaries)

    if args.all:
        selected = commentaries
        if lang_filter:
            selected = [
                c for c in selected if c.get("language", "").lower() in lang_filter
            ]
    elif args.ids:
        selected = []
        for raw_id in args.ids:
            key = raw_id.lower()
            if key in id_map:
                selected.append(id_map[key])
            else:
                print(
                    f"  WARN: commentary '{raw_id}' not found, skipping",
                    file=sys.stderr,
                )
        if not selected:
            print("No matching commentaries found.", file=sys.stderr)
            sys.exit(1)
    else:
        display_commentaries(commentaries, lang_filter)
        print("\nPass --all, commentary ID(s), or --list. See --help.")
        return

    if not selected:
        print("No commentaries match filters.", flush=True)
        sys.exit(0)

    print(f"\nDownloading {len(selected)} commentary/ies:")
    for c in selected:
        print(f"  {c['id']}: {c.get('name', '?')}")

    os.makedirs(args.output_dir, exist_ok=True)
    for c in selected:
        download_commentary(
            c,
            args.output_dir,
            args.skip_intro,
            args.verify,
            args.dry_run,
            args.workers,
            args.verbose,
            args.timeout,
        )

    print("\nDone.")


if __name__ == "__main__":
    main()
