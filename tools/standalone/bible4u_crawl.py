#!/usr/bin/env python3
"""bible4u_crawl.py - Download Bibles from bible4u.net

Usage:
    python bible4u_crawl.py --list                  # List all available
    python bible4u_crawl.py                         # Same as --list
    python bible4u_crawl.py --lang en                # Download all English Bibles (all formats)
    python bible4u_crawl.py --lang en --format pdf   # English Bibles, PDF only
    python bible4u_crawl.py --lang en,kor --format pdf,xml  # Multi-lang, multi-format
    python bible4u_crawl.py --lang en --output-dir ./my_bibles
    python bible4u_crawl.py --lang en --verify       # Verify checksums after dl

Deps: requests, beautifulsoup4
    pip install requests beautifulsoup4
"""

import argparse
import hashlib
import os
import re
import sys
from urllib.parse import urljoin

import requests
from bs4 import BeautifulSoup

BASE_URL = "https://bible4u.net"
DOWNLOAD_PAGE = f"{BASE_URL}/en/download"


# ---------------------------------------------------------------------------
# Scrape
# ---------------------------------------------------------------------------


def fetch_page(url):
    resp = requests.get(url, timeout=30)
    resp.raise_for_status()
    return resp.text


def _parse_size(size_str):
    """'9.9 MB' -> (9.9, 'MB'), '394.8 kB' -> (394.8, 'kB')"""
    m = re.match(r"([\d.]+)\s*(k?M?B)", size_str)
    if m:
        return float(m.group(1)), m.group(2)
    return None, None


def _parse_translation(item):
    h5 = item.find("h5")
    trans_id = h5["id"]
    trans_name = h5.get_text(strip=True)

    tabs = item.find("div", class_="tabs-container")
    formats = []

    if tabs:
        for tab in tabs.find_all("div", class_="tabs-container__item", recursive=False):
            label_el = tab.find("label", class_="tabs-container__label")
            if not label_el:
                continue
            fmt = label_el.get_text(strip=True).lower()

            content = tab.find("div", class_="tabs-container__content")
            if not content:
                continue

            links = content.find_all("a", href=True)
            if not links:
                continue

            href = links[0]["href"]
            url = urljoin(BASE_URL, href)

            link_text = links[0].get_text(strip=True)
            # "SVD.pdf (9.9 MB, last modified: October 23, 2025)"
            size_str = ""
            date_str = ""
            size_m = re.search(r"\(([^,]+)", link_text)
            if size_m:
                size_str = size_m.group(1).strip()
            date_m = re.search(r"last modified:\s*(.+)\)", link_text)
            if date_m:
                date_str = date_m.group(1).strip()

            # Hashes from <pre> block
            pre = content.find("pre")
            hashes = {}
            if pre:
                pt = pre.get_text()
                for algo in ("md5", "sha256", "sha512"):
                    m = re.search(rf"{algo.upper()}:\s+(\S+)", pt, re.IGNORECASE)
                    if m:
                        hashes[algo] = m.group(1)

            formats.append(
                {
                    "format": fmt,
                    "url": url,
                    "size": size_str,
                    "date": date_str,
                    "hashes": hashes,
                }
            )

    return {
        "id": trans_id,
        "name": trans_name,
        "formats": formats,
    }


def scrape_download_page():
    html = fetch_page(DOWNLOAD_PAGE)
    soup = BeautifulSoup(html, "html.parser")

    results = []
    current_lang = None

    for item in soup.find_all("div", class_="main-row__item"):
        h3 = item.find("h3", class_="text-center")
        if h3 and h3.get("id"):
            lang_id = h3["id"]
            lang_text = h3.get_text(strip=True)
            code_m = re.search(r"\(([^)]+)\)", lang_text)
            lang_code = code_m.group(1) if code_m else lang_id
            current_lang = {
                "lang_code": lang_code,
                "lang_id": lang_id,
                "lang_name": lang_text,
                "translations": [],
            }
            results.append(current_lang)
            continue

        if current_lang is None:
            continue

        h5 = item.find("h5")
        if h5 and h5.get("id"):
            current_lang["translations"].append(_parse_translation(item))

    return results


# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------


def display_data(data, lang_filter=None):
    for lang in data:
        if lang_filter and lang["lang_code"].lower() not in lang_filter:
            continue
        if not lang["translations"]:
            continue

        print(f"\n{'=' * 60}")
        print(f"  {lang['lang_name']}")

        for t in lang["translations"]:
            print(f"\n  [{t['id']}] {t['name']}")
            fmt_line = "  Formats: " + ", ".join(
                f"{f['format'].upper():>4} ({f['size']})" for f in t["formats"]
            )
            print(fmt_line)

    print()


def display_languages(data):
    """Compact lang list for --list."""
    print(f"\n{'Code':<6} {'Language':<30} {'Translations'}")
    print("-" * 60)
    for lang in data:
        if not lang["translations"]:
            continue
        n = sum(len(t["formats"]) for t in lang["translations"])
        print(
            f"{lang['lang_code']:<6} {lang['lang_name']:<30} {len(lang['translations'])} trans ({n} files)"
        )


# ---------------------------------------------------------------------------
# Download
# ---------------------------------------------------------------------------


def verify_checksum(filepath, hashes):
    if not hashes:
        return None
    for algo, expected in hashes.items():
        h = hashlib.new(algo)
        with open(filepath, "rb") as f:
            while True:
                chunk = f.read(65536)
                if not chunk:
                    break
                h.update(chunk)
        actual = h.hexdigest()
        if actual.lower() != expected.lower():
            print(f"    CHECKSUM FAIL ({algo}): {filepath}")
            print(f"      expected: {expected}")
            print(f"      actual:   {actual}")
            return False
        else:
            print(f"    {algo.upper()} OK")
    return True


def unzip_file(zip_path, delete_zip=False):
    import zipfile

    extract_dir = os.path.dirname(zip_path)
    print(f"    EXTRACT: {zip_path} -> {extract_dir}/")
    with zipfile.ZipFile(zip_path, "r") as zf:
        zf.extractall(extract_dir)
        for name in zf.namelist():
            print(f"      {name}")
    if delete_zip:
        os.remove(zip_path)
        print(f"    REMOVED: {zip_path}")


def download_bibles(
    data, lang_codes, formats, output_dir, verify=False, dry_run=False, keep_zip=True
):
    os.makedirs(output_dir, exist_ok=True)

    for lang in data:
        if lang_codes and lang["lang_code"].lower() not in lang_codes:
            continue
        for t in lang["translations"]:
            for f in t["formats"]:
                if formats and f["format"] not in formats:
                    continue

                url_path = f["url"].split("/")[-1]
                filename = url_path
                filepath = os.path.join(output_dir, filename)

                if dry_run:
                    print(
                        f"  [DRY-RUN] {lang['lang_code']}/{t['id']} -> {filename} ({f['size']})"
                    )
                    continue

                if os.path.exists(filepath):
                    print(f"  EXISTS: {filename}")
                    if verify:
                        verify_checksum(filepath, f["hashes"])
                    continue

                print(f"  DOWNLOAD: {filename} ({f['size']})")
                try:
                    resp = requests.get(f["url"], timeout=120, stream=True)
                    resp.raise_for_status()
                    with open(filepath, "wb") as out:
                        for chunk in resp.iter_content(chunk_size=65536):
                            out.write(chunk)
                    print(f"    OK -> {filepath}")

                    if verify:
                        verify_checksum(filepath, f["hashes"])

                    if filename.endswith(".zip"):
                        unzip_file(filepath, delete_zip=not keep_zip)

                except Exception as e:
                    print(f"    FAIL: {e}", file=sys.stderr)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main():
    ap = argparse.ArgumentParser(
        description="Download Bibles from bible4u.net",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    ap.add_argument(
        "--lang",
        help="Language code(s) comma-separated (e.g. 'en' or 'en,kor'). Omit = all.",
    )
    ap.add_argument("--format", help="Format filter: pdf,xml,txt,tex. Omit = all.")
    ap.add_argument(
        "--list", action="store_true", help="List available languages and exit"
    )
    ap.add_argument(
        "--output-dir",
        default="./bibles",
        help="Download directory (default: ./bibles)",
    )
    ap.add_argument(
        "--dry-run", action="store_true", help="Show what would download, don't fetch"
    )
    ap.add_argument(
        "--verify", action="store_true", help="Verify checksums after download"
    )
    ap.add_argument(
        "--remove-zip",
        action="store_true",
        help="Delete zip after extraction (default: keep)",
    )
    args = ap.parse_args()

    lang_codes = None
    if args.lang:
        lang_codes = set(c.strip().lower() for c in args.lang.split(","))

    formats = None
    if args.format:
        formats = set(f.strip().lower() for f in args.format.split(","))

    print("Fetching bible4u.net/download ...", file=sys.stderr)
    try:
        data = scrape_download_page()
    except requests.RequestException as e:
        print(f"Error fetching page: {e}", file=sys.stderr)
        sys.exit(1)

    if not data:
        print("No data found. Site structure may have changed.", file=sys.stderr)
        sys.exit(1)

    if args.list or not (args.lang or args.format):
        display_languages(data)
        print("\nUse --lang <CODE> to download. See --help for details.")
        return

    filtered = data
    if lang_codes:
        filtered = [l for l in data if l["lang_code"].lower() in lang_codes]

    has_any = any(
        t["formats"]
        for l in filtered
        for t in l["translations"]
        if not formats or any(f["format"] in formats for f in t["formats"])
    )
    if not has_any:
        print("No matching Bibles found for given filters.", file=sys.stderr)
        display_languages(data)
        sys.exit(1)

    display_data(filtered)

    keep_zip = not args.remove_zip
    if args.dry_run or not sys.stdin.isatty():
        download_bibles(
            data,
            lang_codes,
            formats,
            args.output_dir,
            args.verify,
            args.dry_run,
            keep_zip,
        )
        print("\nDone.")
    else:
        confirm = input(f"\nDownload to '{args.output_dir}'? [Y/n] ").strip().lower()
        if confirm in ("", "y", "yes"):
            download_bibles(
                data,
                lang_codes,
                formats,
                args.output_dir,
                args.verify,
                args.dry_run,
                keep_zip,
            )
            print("\nDone.")
        else:
            print("Cancelled.")


if __name__ == "__main__":
    main()
