#!/usr/bin/env python3
"""getbible_crawl.py - Download Bibles from getBible API V2

Output filenames use 3-letter ISO 639-3 lang prefix (e.g. eng_kjv.json)
to match helloao convention.

Usage:
    python getbible_crawl.py --list              # List all translations
    python getbible_crawl.py --list --lang en    # List English only
    python getbible_crawl.py --lang en           # Download all English translations
    python getbible_crawl.py kjv                 # Download KJV only → eng_kjv.json
    python getbible_crawl.py kjv,web,ylt         # Multiple by abbreviation
    python getbible_crawl.py kjv --books         # Download per-book files instead of full
    python getbible_crawl.py kjv --verify        # Verify SHA checksum

Deps: requests (pip install requests)
"""

import argparse
import hashlib
import json
import os
import sys
from urllib.parse import urljoin

import requests

API_BASE = "https://api.getbible.net/v2"

# ISO 639-1 (2-letter) → ISO 639-3 (3-letter)
ISO_639_1_TO_3 = {
    "aa": "aar", "ab": "abk", "ae": "ave", "af": "afr", "ak": "aka",
    "am": "amh", "an": "arg", "ar": "ara", "as": "asm", "av": "ava",
    "ay": "aym", "az": "aze", "ba": "bak", "be": "bel", "bg": "bul",
    "bh": "bih", "bi": "bis", "bm": "bam", "bn": "ben", "bo": "bod",
    "br": "bre", "bs": "bos", "ca": "cat", "ce": "che", "ch": "cha",
    "co": "cos", "cr": "cre", "cs": "ces", "cu": "chu", "cv": "chv",
    "cy": "cym", "da": "dan", "de": "deu", "dv": "div", "dz": "dzo",
    "ee": "ewe", "el": "ell", "en": "eng", "eo": "epo", "es": "spa",
    "et": "est", "eu": "eus", "fa": "fas", "ff": "ful", "fi": "fin",
    "fj": "fij", "fo": "fao", "fr": "fra", "fy": "fry", "ga": "gle",
    "gd": "gla", "gl": "glg", "gn": "grn", "gu": "guj", "gv": "glv",
    "ha": "hau", "he": "heb", "hi": "hin", "ho": "hmo", "hr": "hrv",
    "ht": "hat", "hu": "hun", "hy": "hye", "hz": "her", "ia": "ina",
    "id": "ind", "ie": "ile", "ig": "ibo", "ii": "iii", "ik": "ipk",
    "io": "ido", "is": "isl", "it": "ita", "iu": "iku", "ja": "jpn",
    "jv": "jav", "ka": "kat", "kg": "kon", "ki": "kik", "kj": "kua",
    "kk": "kaz", "kl": "kal", "km": "khm", "kn": "kan", "ko": "kor",
    "kr": "kau", "ks": "kas", "ku": "kur", "kv": "kom", "kw": "cor",
    "ky": "kir", "la": "lat", "lb": "ltz", "lg": "lug", "li": "lim",
    "ln": "lin", "lo": "lao", "lt": "lit", "lu": "lub", "lv": "lav",
    "mg": "mlg", "mh": "mah", "mi": "mri", "mk": "mkd", "ml": "mal",
    "mn": "mon", "mr": "mar", "ms": "msa", "mt": "mlt", "my": "mya",
    "na": "nau", "nb": "nob", "nd": "nde", "ne": "nep", "ng": "ndo",
    "nl": "nld", "nn": "nno", "no": "nor", "nr": "nbl", "nv": "nav",
    "ny": "nya", "oc": "oci", "oj": "oji", "om": "orm", "or": "ori",
    "os": "oss", "pa": "pan", "pi": "pli", "pl": "pol", "ps": "pus",
    "pt": "por", "qu": "que", "rm": "roh", "rn": "run", "ro": "ron",
    "ru": "rus", "rw": "kin", "sa": "san", "sc": "srd", "sd": "snd",
    "se": "sme", "sg": "sag", "si": "sin", "sk": "slk", "sl": "slv",
    "sm": "smo", "sn": "sna", "so": "som", "sq": "sqi", "sr": "srp",
    "ss": "ssw", "st": "sot", "su": "sun", "sv": "swe", "sw": "swa",
    "ta": "tam", "te": "tel", "tg": "tgk", "th": "tha", "ti": "tir",
    "tk": "tuk", "tl": "tgl", "tn": "tsn", "to": "ton", "tr": "tur",
    "ts": "tso", "tt": "tat", "tw": "twi", "ty": "tah", "ug": "uig",
    "uk": "ukr", "ur": "urd", "uz": "uzb", "ve": "ven", "vi": "vie",
    "vo": "vol", "wa": "wln", "wo": "wol", "xh": "xho", "yi": "yid",
    "yo": "yor", "za": "zha", "zh": "zho", "zu": "zul",
}


# ---------------------------------------------------------------------------
# API
# ---------------------------------------------------------------------------


def fetch_json(url):
    resp = requests.get(url, timeout=60)
    resp.raise_for_status()
    return resp.json()


def get_translations():
    return fetch_json(f"{API_BASE}/translations.json")


def get_checksums():
    return fetch_json(f"{API_BASE}/checksum.json")


def get_books(abbr):
    return fetch_json(f"{API_BASE}/{abbr}/books.json")


def get_translation_url(abbr):
    return f"{API_BASE}/{abbr}.json"


def get_book_url(abbr, book_num):
    return f"{API_BASE}/{abbr}/{book_num}.json"


def get_chapter_url(abbr, book_num, chapter):
    return f"{API_BASE}/{abbr}/{book_num}/{chapter}.json"


# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------


def display_translations(translations, lang_filter=None):
    by_lang = {}
    for abbr, t in translations.items():
        lang = t.get("lang", "??")
        if lang_filter:
            # Case-insensitive comparison (API uses e.g. zh-Hans, filter may be zh-hans)
            if not any(lang.lower() == f.lower() for f in lang_filter):
                continue
        by_lang.setdefault(lang, []).append((abbr, t))

    for lang in sorted(by_lang.keys()):
        items = by_lang[lang]
        lang_name = items[0][1].get("language", lang)
        print(f"\n  [{lang}] {lang_name}")
        for abbr, t in sorted(items, key=lambda x: x[0]):
            ver = t.get("distribution_version", "")
            print(f"    {abbr:<20} {t['translation']}  (v{ver})")


# ---------------------------------------------------------------------------
# Download
# ---------------------------------------------------------------------------


def verify_sha(filepath, expected_sha):
    h = hashlib.sha1()
    with open(filepath, "rb") as f:
        while True:
            chunk = f.read(65536)
            if not chunk:
                break
            h.update(chunk)
    actual = h.hexdigest()
    if actual.lower() != expected_sha.lower():
        print(f"    SHA1 FAIL: {filepath}")
        print(f"      expected: {expected_sha}")
        print(f"      actual:   {actual}")
        return False
    print(f"    SHA1 OK")
    return True


def download_file(url, filepath, expected_sha=None, verify=False):
    if os.path.exists(filepath):
        print(f"  EXISTS: {os.path.basename(filepath)}")
        if verify and expected_sha:
            verify_sha(filepath, expected_sha)
        return True

    print(f"  DOWNLOAD: {os.path.basename(filepath)}")
    try:
        resp = requests.get(url, timeout=300, stream=True)
        resp.raise_for_status()
        with open(filepath, "wb") as f:
            for chunk in resp.iter_content(chunk_size=65536):
                f.write(chunk)
        print(f"    OK -> {filepath}")
        if expected_sha:
            verify_sha(filepath, expected_sha)
        return True
    except Exception as e:
        print(f"    FAIL: {e}", file=sys.stderr)
        # Remove partial download
        if os.path.exists(filepath):
            os.remove(filepath)
        return False


def download_translations(abbrs, output_dir, lang_map, books=False, verify=False, dry_run=False):
    os.makedirs(output_dir, exist_ok=True)
    checksums = get_checksums()

    for abbr in abbrs:
        abbr = abbr.lower()
        expected_sha = checksums.get(abbr)
        lang3 = lang_map.get(abbr, "unk")  # ISO 639-3

        if books:
            # Download per-book JSON files
            books_data = get_books(abbr)
            book_dir = os.path.join(output_dir, abbr)
            os.makedirs(book_dir, exist_ok=True)

            for book_num_str, book_info in books_data.items():
                bname = book_info.get("name", f"book_{book_num_str}")
                filename = f"{book_num_str}.json"
                filepath = os.path.join(book_dir, filename)
                url = get_book_url(abbr, book_num_str)

                if dry_run:
                    print(f"  [DRY-RUN] {abbr}/{bname} -> {filename}")
                    continue

                download_file(url, filepath)
        else:
            # Download full translation JSON — use 3-letter ISO prefix
            filename = f"{lang3}_{abbr}.json"
            filepath = os.path.join(output_dir, filename)
            url = get_translation_url(abbr)

            if dry_run:
                print(f"  [DRY-RUN] {abbr} -> {filename}")
                continue

            ok = download_file(url, filepath, expected_sha, verify)
            if not ok:
                print(f"  SKIP chapters for {abbr} (download failed)", file=sys.stderr)
                continue

            if verify:
                # Also download books checksum for deeper verify
                try:
                    books_checksum = fetch_json(f"{API_BASE}/{abbr}/checksum.json")
                    # Validate each book's checksum
                    for book_num, book_sha in books_checksum.items():
                        bfilepath = os.path.join(output_dir, abbr, f"{book_num}.json")
                        if os.path.exists(bfilepath):
                            verify_sha(bfilepath, book_sha)
                except requests.RequestException:
                    if verify:
                        print(
                            f"    Book checksums not available for {abbr}",
                            file=sys.stderr,
                        )


def resolve_abbreviations(translations, lang_filter=None):
    """Return list of abbreviation strings matching filters."""
    abbrs = sorted(translations.keys())
    if lang_filter:
        abbrs = [
            a for a in abbrs if translations[a].get("lang", "").lower() in lang_filter
        ]
    return abbrs


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main():
    ap = argparse.ArgumentParser(
        description="Download Bibles from getBible API V2",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    ap.add_argument(
        "abbrs",
        nargs="*",
        help="Translation abbreviation(s) to download (e.g. kjv web ylt)",
    )
    ap.add_argument("--list", action="store_true", help="List available translations")
    ap.add_argument(
        "--lang",
        help="Filter by language code(s) comma-separated (e.g. 'en' or 'en,ko')",
    )
    ap.add_argument(
        "--books",
        action="store_true",
        help="Download per-book files instead of full JSON",
    )
    ap.add_argument(
        "--output-dir",
        default="./getbible",
        help="Download directory (default: ./getbible)",
    )
    ap.add_argument(
        "--verify", action="store_true", help="Verify SHA checksums after download"
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

    if not args.abbrs:
        if args.lang:
            abbrs = resolve_abbreviations(translations, lang_filter)
        else:
            display_translations(translations, lang_filter)
            print("\nUse --lang or pass abbreviation(s) to download. See --help.")
            return
    else:
        abbrs = [a.lower() for a in args.abbrs]

    if not abbrs:
        print("No matching translations found.", file=sys.stderr)
        sys.exit(1)

    if args.full_only:
        print("\nChecking book counts for --full-only filter ...", flush=True)
        filtered = []
        for abbr in abbrs:
            try:
                books_data = get_books(abbr)
                count = len(books_data)
                if count >= 66:
                    filtered.append(abbr)
                    print(f"  {abbr}: {count} books - OK", flush=True)
                else:
                    print(f"  {abbr}: {count} books - SKIP (partial)", flush=True)
            except requests.RequestException:
                print(f"  {abbr}: SKIP (books fetch failed)", flush=True)
        abbrs = filtered

    if not abbrs:
        print("No full-Bible translations match filters.", flush=True)
        sys.exit(0)

    # Build 3-letter lang code map for output filenames
    lang_map = {}
    for abbr in abbrs:
        t = translations.get(abbr, {})
        lang2 = t.get("lang", "??").split("-")[0].lower()  # strip region (e.g. zh-Hans → zh)
        lang_map[abbr] = ISO_639_1_TO_3.get(lang2, lang2)

    print(f"\nDownloading {len(abbrs)} translation(s):")
    for abbr in abbrs:
        t = translations.get(abbr)
        if t:
            print(f"  {abbr}: {t['translation']} [{t.get('lang', '??')}]")

    download_translations(abbrs, args.output_dir, lang_map, args.books, args.verify, args.dry_run)
    print("\nDone.")


if __name__ == "__main__":
    main()
