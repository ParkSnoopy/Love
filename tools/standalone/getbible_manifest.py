#!/usr/bin/env python3
"""getbible_manifest.py - Update or create manifest.json from getBible .sqlite files

Scans a directory of .sqlite files, reads metadata from the version table,
and builds/updates manifest.json entries.

Usage:
    python getbible_manifest.py db/                              # scan recursively, write ./manifest.json
    python getbible_manifest.py db/ -o manifest.json             # specify output path
    python getbible_manifest.py db/ --type commentary            # set type field (override auto-detect)
    python getbible_manifest.py db/ --source getbible            # source label (override auto-detect)
    python getbible_manifest.py db/ --rel-dir subdir             # file prefix override (not needed with dist/ layout)
    python getbible_manifest.py db/ --manifest existing.json     # merge with existing

Auto-detects type, source and file path from directory structure:
  dist/bible/<source>/*.sqlite   -> type=bible,  source=<source>
  dist/commentary/<source>/*.sqlite -> type=commentary, source=<source>
"""

import argparse
import json
import sqlite3
import sys
from pathlib import Path

LANG_NAMES = {
    # ISO 639-3 (3-letter)
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
    "nno": "Norwegian Nynorsk", "nob": "Norwegian Bokmal",
    "nor": "Norwegian", "nya": "Chichewa", "oci": "Occitan", "oji": "Ojibwa",
    "ori": "Oriya", "orm": "Oromo", "oss": "Ossetian", "pan": "Panjabi",
    "pli": "Pali", "pol": "Polish", "por": "Portuguese", "pus": "Pushto",
    "que": "Quechua", "roh": "Romansh", "ron": "Romanian", "run": "Rundi",
    "rus": "Russian", "sag": "Sango", "san": "Sanskrit", "sin": "Sinhala",
    "slk": "Slovak", "slv": "Slovenian", "sme": "Northern Sami",
    "smo": "Samoan", "sna": "Shona", "snd": "Sindhi", "som": "Somali",
    "sot": "Sotho", "spa": "Spanish", "srd": "Sardinian", "srp": "Serbian",
    "ssw": "Swati", "sun": "Sundanese", "swa": "Swahili", "swe": "Swedish",
    "tah": "Tahitian", "tam": "Tamil", "tat": "Tatar", "tel": "Telugu",
    "tgk": "Tajik", "tgl": "Tagalog", "tha": "Thai", "tir": "Tigrinya",
    "ton": "Tonga", "tsn": "Tswana", "tso": "Tsonga", "tuk": "Turkmen",
    "tur": "Turkish", "twi": "Twi", "uig": "Uighur", "ukr": "Ukrainian",
    "urd": "Urdu", "uzb": "Uzbek", "ven": "Venda", "vie": "Vietnamese",
    "vol": "Volapuk", "wln": "Walloon", "wol": "Wolof", "xho": "Xhosa",
    "yid": "Yiddish", "yor": "Yoruba", "zha": "Zhuang", "zul": "Zulu",
    "zxx": "Multiple",
    # ISO 639-1 (2-letter, used by getBible)
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
    "gl": "Galician", "ca": "Catalan", "eo": "Esperanto", "eo": "Esperanto",
}


def read_version_table(db_path: Path) -> dict | None:
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


def build_entry(db_path: Path, scan_dir: Path, rel_dir: str, entry_type: str, source: str) -> dict | None:
    meta = read_version_table(db_path)
    if not meta:
        return None

    stem = db_path.stem
    parts = stem.split("_", 1)
    lang_code = parts[0] if len(parts) > 1 else "unknown"
    lang_name = LANG_NAMES.get(lang_code, lang_code)
    entry_id = stem

    shortname = meta["label"]
    name = meta["label"]

    # Auto-detect from dir structure: bible/<source>/ or commentary/<source>/
    auto_file = None
    try:
        rel = db_path.relative_to(scan_dir)
        comps = rel.parts
        if len(comps) >= 3 and comps[0] in ("bible", "commentary"):
            entry_type = comps[0]
            source = comps[1]
            auto_file = f"{source}/{stem}.sqlite"
    except ValueError:
        pass

    if auto_file:
        file_path = auto_file
    elif rel_dir:
        file_path = f"{rel_dir}/{stem}.sqlite"
    else:
        file_path = f"{stem}.sqlite"

    return {
        "id": entry_id,
        "shortname": shortname,
        "name": name,
        "language": lang_name,
        "type": entry_type,
        "file": file_path,
        "source": source,
    }


def main():
    ap = argparse.ArgumentParser(
        description="Update or create manifest.json from getBible .sqlite files.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    ap.add_argument("dir", help="Directory to scan recursively for .sqlite files")
    ap.add_argument("-o", "--output", default="./manifest.json", help="Output manifest path (default: ./manifest.json)")
    ap.add_argument("--type", default="bible", choices=["bible", "commentary"], help="Entry type (default: bible)")
    ap.add_argument("--source", default="getbible", help="Source label (default: getbible)")
    ap.add_argument("--rel-dir", default="", help="Relative directory prefix in file paths (fallback when auto-detect fails)")
    ap.add_argument("--manifest", help="Existing manifest.json to merge with (otherwise reads from --output if exists)")
    args = ap.parse_args()

    scan_dir = Path(args.dir)
    if not scan_dir.is_dir():
        print(f"Error: not a directory: {args.dir}", file=sys.stderr)
        sys.exit(1)

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

    sqlite_files = sorted(scan_dir.rglob("*.sqlite"))
    if not sqlite_files:
        print(f"No .sqlite files found in {args.dir}", file=sys.stderr)
        sys.exit(1)

    print(f"Scanning {len(sqlite_files)} .sqlite file(s) in {args.dir} ...", flush=True)

    added = 0
    updated = 0
    skipped = 0

    for sf in sqlite_files:
        entry = build_entry(sf, scan_dir, args.rel_dir, args.type, args.source)
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

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    merged = sorted(existing.values(), key=lambda e: e["id"])
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(merged, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"\nDone: {added} added, {updated} updated, {skipped} skipped -> {out_path}", flush=True)


if __name__ == "__main__":
    main()
