#!/usr/bin/env python3
"""manifest_aio.py - Generate full manifest.json from all dist/ SQLite files in one pass.

Scans a directory tree for .sqlite files, auto-detects type (bible/commentary)
and source (helloao/getbible/nocr) from the directory structure, extracts language
from filename convention (<lang>_<stem>.sqlite for bibles), reads labels from
each SQLite version table, and writes a single merged manifest.

Usage:
    python manifest_aio.py dist/                              # scan recursively, write ./manifest.json
    python manifest_aio.py dist/ -o dist/manifest.json        # write to specific path
    python manifest_aio.py dist/ --manifest old.json          # merge with existing
    python manifest_aio.py dist/ --lang English               # default language for commentaries (no lang in filename)

Auto-detects from directory structure:
  dist/bible/<source>/*.sqlite        -> type=bible,   source=<source>
  dist/commentary/<source>/*.sqlite   -> type=commentary, source=<source>

Language is extracted from filename for bibles (<lang>_<stem>.sqlite).
Commentaries use the --lang default since their filenames have no lang prefix.
"""

import argparse
import json
import sqlite3
import sys
from pathlib import Path

# ISO 639-3 -> English name
LANG_NAMES_3 = {
    "aar": "Afar", "afr": "Afrikaans", "aka": "Akan", "amh": "Amharic",
    "ara": "Arabic", "arb": "Arabic", "asm": "Assamese", "ava": "Avar",
    "aym": "Aymara", "aze": "Azerbaijani", "bak": "Bashkir", "bel": "Belarusian",
    "ben": "Bengali", "bis": "Bislama", "bod": "Tibetan", "bos": "Bosnian",
    "bre": "Breton", "bul": "Bulgarian", "cat": "Catalan", "ceb": "Cebuano",
    "ces": "Czech", "cha": "Chamorro", "chu": "Church Slavic", "chv": "Chuvash",
    "cor": "Cornish", "cos": "Corsican", "cre": "Cree", "cym": "Welsh",
    "dan": "Danish", "deu": "German", "div": "Divehi", "dsb": "Lower Sorbian",
    "dzo": "Dzongkha", "ell": "Greek", "eng": "English", "epo": "Esperanto",
    "est": "Estonian", "eus": "Basque", "ewe": "Ewe", "fao": "Faroese",
    "fas": "Persian", "fij": "Fijian", "fin": "Finnish", "fra": "French",
    "fry": "Western Frisian", "ful": "Fulah", "gla": "Scottish Gaelic",
    "gle": "Irish", "glg": "Galician", "glv": "Manx", "grn": "Guarani",
    "guj": "Gujarati", "hat": "Haitian Creole", "hau": "Hausa", "haw": "Hawaiian",
    "hbs": "Serbo-Croatian", "heb": "Hebrew", "her": "Herero", "hin": "Hindi",
    "hmo": "Hiri Motu", "hrv": "Croatian", "hun": "Hungarian", "hye": "Armenian",
    "ibo": "Igbo", "ido": "Ido", "iii": "Sichuan Yi", "iku": "Inuktitut",
    "ile": "Interlingue", "ina": "Interlingua", "ind": "Indonesian",
    "ipk": "Inupiaq", "isl": "Icelandic", "ita": "Italian", "jav": "Javanese",
    "jpn": "Japanese", "kal": "Greenlandic", "kan": "Kannada", "kas": "Kashmiri",
    "kat": "Georgian", "kau": "Kanuri", "kaz": "Kazakh", "khm": "Khmer",
    "kik": "Kikuyu", "kin": "Kinyarwanda", "kir": "Kirghiz", "kom": "Komi",
    "kon": "Kongo", "kor": "Korean", "kua": "Kwanyama", "kur": "Kurdish",
    "lao": "Lao", "lat": "Latin", "lav": "Latvian", "lim": "Limburgan",
    "lin": "Lingala", "lit": "Lithuanian", "ltz": "Luxembourgish",
    "lub": "Luba-Katanga", "lug": "Ganda", "mah": "Marshallese",
    "mal": "Malayalam", "mar": "Marathi", "mkd": "Macedonian", "mlg": "Malagasy",
    "mlt": "Maltese", "mon": "Mongolian", "mri": "Maori", "msa": "Malay",
    "mya": "Burmese", "nau": "Nauru", "nav": "Navajo", "nbl": "South Ndebele",
    "nde": "North Ndebele", "ndo": "Ndonga", "nep": "Nepali", "nld": "Dutch",
    "nno": "Norwegian Nynorsk", "nob": "Norwegian Bokmal", "nor": "Norwegian",
    "nya": "Chichewa", "oci": "Occitan", "oji": "Ojibwa", "ori": "Oriya",
    "orm": "Oromo", "oss": "Ossetian", "pan": "Panjabi", "pli": "Pali",
    "pol": "Polish", "por": "Portuguese", "pus": "Pushto", "que": "Quechua",
    "roh": "Romansh", "ron": "Romanian", "run": "Rundi", "rus": "Russian",
    "sag": "Sango", "san": "Sanskrit", "sin": "Sinhala", "slk": "Slovak",
    "slv": "Slovenian", "sme": "Northern Sami", "smo": "Samoan", "sna": "Shona",
    "snd": "Sindhi", "som": "Somali", "sot": "Sotho", "spa": "Spanish",
    "srd": "Sardinian", "srp": "Serbian", "ssw": "Swati", "sun": "Sundanese",
    "swa": "Swahili", "swe": "Swedish", "tah": "Tahitian", "tam": "Tamil",
    "tat": "Tatar", "tel": "Telugu", "tgk": "Tajik", "tgl": "Tagalog",
    "tha": "Thai", "tir": "Tigrinya", "ton": "Tonga", "tsn": "Tswana",
    "tso": "Tsonga", "tuk": "Turkmen", "tur": "Turkish", "twi": "Twi",
    "uig": "Uighur", "ukr": "Ukrainian", "urd": "Urdu", "uzb": "Uzbek",
    "ven": "Venda", "vie": "Vietnamese", "vol": "Volapuk", "wln": "Walloon",
    "wol": "Wolof", "xho": "Xhosa", "yid": "Yiddish", "yor": "Yoruba",
    "zha": "Zhuang", "zul": "Zulu", "zxx": "Multiple",
}

# ISO 639-1 -> English name (used by getBible)
LANG_NAMES_1 = {
    "en": "English", "ko": "Korean", "ja": "Japanese", "zh": "Chinese",
    "es": "Spanish", "fr": "French", "de": "German", "pt": "Portuguese",
    "ru": "Russian", "it": "Italian", "nl": "Dutch", "pl": "Polish",
    "sv": "Swedish", "da": "Danish", "fi": "Finnish", "no": "Norwegian",
    "hu": "Hungarian", "cs": "Czech", "sk": "Slovak", "ro": "Romanian",
    "bg": "Bulgarian", "sr": "Serbian", "hr": "Croatian", "el": "Greek",
    "he": "Hebrew", "ar": "Arabic", "tr": "Turkish", "th": "Thai",
    "vi": "Vietnamese", "id": "Indonesian", "ms": "Malay", "tl": "Tagalog",
    "mn": "Mongolian", "ne": "Nepali", "my": "Burmese", "km": "Khmer",
    "lo": "Lao", "am": "Amharic", "sw": "Swahili", "af": "Afrikaans",
    "la": "Latin", "ga": "Irish", "cy": "Welsh", "gd": "Scottish Gaelic",
    "mt": "Maltese", "is": "Icelandic", "lb": "Luxembourgish",
    "bs": "Bosnian", "sq": "Albanian", "mk": "Macedonian", "hy": "Armenian",
    "ka": "Georgian", "fa": "Persian", "ur": "Urdu", "hi": "Hindi",
    "bn": "Bengali", "ta": "Tamil", "te": "Telugu", "mr": "Marathi",
    "gu": "Gujarati", "kn": "Kannada", "ml": "Malayalam", "si": "Sinhala",
    "lt": "Lithuanian", "lv": "Latvian", "et": "Estonian", "eu": "Basque",
    "gl": "Galician", "ca": "Catalan", "eo": "Esperanto",
}


def get_lang_name(code: str) -> str:
    """Resolve language code (639-3 or 639-1) to English name."""
    if code in LANG_NAMES_3:
        return LANG_NAMES_3[code]
    if code in LANG_NAMES_1:
        return LANG_NAMES_1[code]
    return code


def read_version(db_path: Path) -> dict | None:
    try:
        conn = sqlite3.connect(str(db_path))
        cur = conn.execute("SELECT slug, label FROM version LIMIT 1")
        row = cur.fetchone()
        conn.close()
        if row:
            return {"slug": row[0], "label": row[1]}
        return None
    except (sqlite3.Error, OSError) as e:
        print(f"  [SKIP] Can't read version table: {db_path}: {e}", flush=True)
        return None


def extract_language(stem: str, entry_type: str) -> tuple[str, str]:
    """Extract language from filename and return (remaining_stem, lang_name).

    Bible filenames: <lang>_<slug>.sqlite (e.g. eng_engniv, cmn_cbs)
    NOCR commentary: com_<lang>_<slug>.sqlite (e.g. com_kor_hochma)
    HelloAO commentary: <slug>.sqlite (e.g. matthew-henry) -> no lang in filename
    """
    parts = stem.split("_")
    if entry_type == "commentary" and len(parts) >= 3 and parts[0] == "com":
        return get_lang_name(parts[1])
    if entry_type != "commentary" and len(parts) >= 2:
        return get_lang_name(parts[0])
    return ""


def build_entry(
    db_path: Path,
    scan_dir: Path,
    type_default: str,
    source_default: str,
    fallback_lang: str,
) -> dict | None:
    meta = read_version(db_path)
    if not meta:
        return None

    stem = db_path.stem
    entry_type = type_default
    source = source_default
    lang_from_file = ""

    # Auto-detect type, source, and file from dist directory structure
    auto_file = None
    try:
        rel = db_path.relative_to(scan_dir)
        comps = rel.parts
        if len(comps) >= 3 and comps[0] in ("bible", "commentary"):
            entry_type = comps[0]
            source = comps[1]
            auto_file = f"{source}/{stem}.sqlite"
            lang_from_file = extract_language(stem, entry_type)
    except ValueError:
        lang_from_file = extract_language(stem, entry_type)

    if auto_file:
        file_path = auto_file
    else:
        file_path = f"{stem}.sqlite"

    lang = lang_from_file if lang_from_file else fallback_lang

    return {
        "id": stem,
        "shortname": meta["label"],
        "name": meta["label"],
        "language": lang,
        "type": entry_type,
        "file": file_path,
        "source": source,
    }


def main():
    ap = argparse.ArgumentParser(
        description="Generate full manifest.json from dist/ SQLite files in one pass.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    ap.add_argument("dir", help="Directory to scan recursively for .sqlite files")
    ap.add_argument("-o", "--output", default="./manifest.json",
                    help="Output manifest path (default: ./manifest.json)")
    ap.add_argument("--manifest",
                    help="Existing manifest.json to merge with (otherwise reads from --output if exists)")
    ap.add_argument("--lang", default="English",
                    help="Default language for entries without language prefix in filename (e.g. commentaries) (default: English)")
    ap.add_argument("--type", default=None,
                    help="Force type for all entries (bible|commentary). Auto-detected from dir structure by default.")
    ap.add_argument("--source", default=None,
                    help="Force source for all entries. Auto-detected from dir structure by default.")
    ap.add_argument("--rel-dir", default="",
                    help="Relative directory prefix in file paths (fallback when auto-detect fails)")
    args = ap.parse_args()

    scan_dir = Path(args.dir)
    if not scan_dir.is_dir():
        print(f"Error: not a directory: {args.dir}", file=sys.stderr)
        sys.exit(1)

    # Load existing manifest
    existing = {}
    manifest_path = Path(args.manifest) if args.manifest else Path(args.output)
    if manifest_path.exists():
        try:
            with open(manifest_path, "r", encoding="utf-8") as f:
                entries = json.load(f)
            existing = {e["id"]: e for e in entries}
            print(f"Loaded {len(existing)} existing entries from {manifest_path}", flush=True)
        except (json.JSONDecodeError, OSError) as e:
            print(f"  WARN: can't read existing manifest: {e}", flush=True)

    # Scan .sqlite files
    sqlite_files = sorted(scan_dir.rglob("*.sqlite"))
    if not sqlite_files:
        print(f"No .sqlite files found in {args.dir}", file=sys.stderr)
        sys.exit(1)

    print(f"Scanning {len(sqlite_files)} .sqlite file(s) in {args.dir} ...", flush=True)

    type_default = args.type or "bible"
    source_default = args.source or "unknown"

    added = 0
    updated = 0
    skipped = 0

    for sf in sqlite_files:
        entry = build_entry(sf, scan_dir, type_default, source_default, args.lang)
        if not entry:
            skipped += 1
            continue

        eid = entry["id"]
        if eid in existing:
            old = existing[eid]
            changed = False
            for key in ("shortname", "name", "language", "type", "file", "source"):
                if old.get(key) != entry[key]:
                    old[key] = entry[key]
                    changed = True
            if changed:
                updated += 1
        else:
            existing[eid] = entry
            added += 1

    # Write merged manifest
    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    merged = sorted(existing.values(), key=lambda e: e["id"])
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(merged, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"\nDone: {added} added, {updated} updated, {skipped} skipped -> {out_path}", flush=True)


if __name__ == "__main__":
    main()
