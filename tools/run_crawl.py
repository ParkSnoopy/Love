"""
run_crawl.py — Entry-point for crawling nocr.net Bibles and commentaries.

Usage:
  python run_crawl.py --target all
  python run_crawl.py --target korwrm
  python run_crawl.py --target com_kor_hochma
  python run_crawl.py --target bibles          # all Bible boards
  python run_crawl.py --target commentaries    # all commentary boards
  python run_crawl.py --target ko              # all Korean Bible boards
  python run_crawl.py --list                   # list available targets

Output SQLite files are written to:
  ./data/nocr/<id>.sqlite      (Bibles)
  ./data/comment/<id>.sqlite   (commentaries)
"""

import argparse
import os
import sys

# Allow running from the tools/ directory
sys.path.insert(0, os.path.dirname(__file__))

from nocr_crawler import NocrBoardCrawler, SqlitePackager
from extractors import (
    ALL_BOOKS_META,
    BOOK_META_LIST,
    INTRO_BOOK_META,
    BibleExtractor,
    HochmaExtractor,
    MatthewHenryKorExtractor,
    BakYunsenExtractor,
)
from book_names_localization import get_localized_book_names

# ─────────────────────────────────────────────────────────────────────────────
# Output path helper
# ─────────────────────────────────────────────────────────────────────────────

_TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
_DATA_DIR = os.path.join(_TOOLS_DIR, "data")


def bible_path(filename: str) -> str:
    return os.path.join(_DATA_DIR, "nocr", filename)


def comment_path(filename: str) -> str:
    return os.path.join(_DATA_DIR, "comment", filename)


# ─────────────────────────────────────────────────────────────────────────────
# Board registry
# ─────────────────────────────────────────────────────────────────────────────
# Each entry: (target_id, board_id, out_path, slug, label, extractor, books_meta)


def _localized_books_meta(target_id: str) -> list[dict]:
    """Return book metadata with localized display names.

    Korean boards use Korean names. Non-Korean boards use language-localized book names.
    """
    if target_id.startswith("kor"):
        return BOOK_META_LIST

    mapping = get_localized_book_names(target_id)
    if mapping is None:
        # Default/English
        return [{**book, "name": book["eng_name"]} for book in BOOK_META_LIST]

    return [
        {**book, "name": mapping.get(book["book_id"], book["eng_name"])}
        for book in BOOK_META_LIST
    ]


def _bible(target_id: str, board_id: str, out_file: str, slug: str, label: str):
    return {
        "id": target_id,
        "board_id": board_id,
        "out_path": bible_path(out_file),
        "slug": slug,
        "label": label,
        "extractor": BibleExtractor(),
        "books_meta": _localized_books_meta(target_id),
        "type": "bible",
    }


def _commentary(
    target_id: str, board_id: str, out_file: str, slug: str, label: str, extractor
):
    return {
        "id": target_id,
        "board_id": board_id,
        "out_path": comment_path(out_file),
        "slug": slug,
        "label": label,
        "extractor": extractor,
        "books_meta": ALL_BOOKS_META,
        "type": "commentary",
    }


REGISTRY = [
    # ── Korean Bibles ──────────────────────────────────────────────────────
    _bible("korwrm", "korwrm", "kor_korwrm.sqlite", "korwrm", "우리말 성경"),
    _bible("korkrv", "korkrv", "kor_korkrv.sqlite", "korkrv", "개역개정판"),
    _bible("korkr4", "korkr4", "kor_korkr4.sqlite", "korkr4", "개역개정 4판"),
    _bible("korkrb", "korkrb", "kor_korkrb.sqlite", "korkrb", "바른성경"),
    _bible("korbbh", "korbbh", "kor_korbbh.sqlite", "korbbh", "바른성경 한문"),
    _bible("kornks", "kornks", "kor_kornks.sqlite", "kornks", "표준새번역"),
    _bible("kornrr", "kornrr", "kor_kornrr.sqlite", "kornrr", "새번역"),
    _bible("korkjv", "korkjv", "kor_korkjv.sqlite", "korkjv", "한글 KJV"),
    _bible("korhum", "korhum", "kor_korhum.sqlite", "korhum", "한글 흠정역"),
    _bible("korkcb", "korkcb", "kor_korkcb.sqlite", "korkcb", "공동번역"),
    _bible("korctr", "korctr", "kor_korctr.sqlite", "korctr", "공동번역 개정판"),
    _bible("korcat", "korkcc", "kor_korcat.sqlite", "korcat", "카톨릭 성경"),
    _bible("korkmb", "korklb", "kor_korkmb.sqlite", "korkmb", "현대인의 성경"),
    _bible("korkml", "kortkv", "kor_korkml.sqlite", "korkml", "현대어 성경"),
    _bible("korhrc", "korhrv", "kor_korhrc.sqlite", "korhrc", "개역성경 국한문혼용"),
    # ── English Bibles ─────────────────────────────────────────────────────
    _bible("eng_engniv", "engniv", "eng_engniv.sqlite", "engniv", "NIV 1984"),
    _bible(
        "eng_niv2011",
        "bible_engl_niv2011",
        "eng_niv2011.sqlite",
        "niv2011",
        "NIV 2011",
    ),
    _bible(
        "eng_nasb2020",
        "bible_eng_nasb2020",
        "eng_nasb2020.sqlite",
        "nasb2020",
        "NASB 2020",
    ),
    _bible(
        "eng_wbs_rwbs",
        "eng_wbs_rwbs",
        "eng_wbs_rwbs.sqlite",
        "wbs_rwbs",
        "Webster / Revised Webster",
    ),
    # ── Hebrew / Aramaic Bibles ─────────────────────────────────────────────
    _bible(
        "heb_bhs_del",
        "bible_heb_bhs_del",
        "heb_bhs_del.sqlite",
        "bhs_del",
        "BHS (OT) & Delitzsche (NT)",
    ),
    _bible(
        "heb_wlc_sge",
        "bible_heb_wlc_sge",
        "heb_wlc_sge.sqlite",
        "wlc_sge",
        "WLC (OT) & Salkinson (NT)",
    ),
    _bible(
        "heb_allepo_mht",
        "bible_heb_allepo_mht",
        "heb_allepo_mht.sqlite",
        "allepo_mht",
        "Allepo (OT) & Modern Hebrew (NT)",
    ),
    _bible(
        "heb_mapm",
        "bible_heb_mapm",
        "heb_mapm.sqlite",
        "mapm",
        "Miqra `al pi ha-Mesorah",
    ),
    _bible(
        "aram_targum",
        "bible_aram_targum",
        "aram_targum.sqlite",
        "aram_targum",
        "Targum (OT / NT)",
    ),
    _bible("aram_pes", "bible_pes", "aram_pes.sqlite", "pes", "Peshitta New Testament"),
    _bible(
        "aram_peh", "bible_peh", "aram_peh.sqlite", "peh", "Peshitta NT Hebrew Letters"
    ),
    _bible(
        "aram_phv",
        "bible_phv",
        "aram_phv.sqlite",
        "phv",
        "Peshitta NT Hebrew Letters with Vowels",
    ),
    # ── Greek Bibles ────────────────────────────────────────────────────────
    _bible(
        "grk_lxx_na28",
        "bible_grk_lxx_na28",
        "grk_lxx_na28.sqlite",
        "lxx_na28",
        "LXX (OT) & NA28 (NT)",
    ),
    _bible(
        "grk_na27",
        "bible_grk_na27",
        "grk_na27.sqlite",
        "na27",
        "Nestle-Aland 27th Edition",
    ),
    _bible("grk_ubs4", "bible_grk_ubs4", "grk_ubs4.sqlite", "ubs4", "UBS 4th Edition"),
    _bible("grk_ste", "bible_grk_ste", "grk_ste.sqlite", "ste", "Stephanus 1550 GNT"),
    _bible("grk_byz", "bible_grk_byz", "grk_byz.sqlite", "byz", "Byzantine Text Form"),
    _bible("grk_scr", "bible_grk_scr", "grk_scr.sqlite", "scr", "Scrivener's Edition"),
    _bible(
        "grk_wht", "bible_grk_wht", "grk_wht.sqlite", "wht", "Westcott / Hort Greek NT"
    ),
    _bible("grk_tis", "bible_grk_tis", "grk_tis.sqlite", "tis", "Tischendorf GNT"),
    _bible("grk_sbl", "bible_grk_sbl", "grk_sbl.sqlite", "sbl", "SBL Greek NT"),
    _bible(
        "grk_vamas",
        "bible_grk_vamas",
        "grk_vamas.sqlite",
        "vamas",
        "Νεόφυτου Βάμβα Greek Bible",
    ),
    # ── Latin Bibles ────────────────────────────────────────────────────────
    _bible(
        "lat_vulgata",
        "bible_latin_vulgata",
        "lat_vulgata.sqlite",
        "vulgata",
        "Latin Vulgata Version",
    ),
    _bible(
        "lat_vulglossa",
        "bible_lat_vulglossa",
        "lat_vulglossa.sqlite",
        "vulglossa",
        "Vulgata Glossa ordinara",
    ),
    # ── Korean Commentaries ────────────────────────────────────────────────
    _commentary(
        "com_kor_hochma",
        "com_kor_hochma",
        "com_kor_hochma.sqlite",
        "hochma",
        "호크마 주석",
        HochmaExtractor(),
    ),
    _commentary(
        "com_kor_mhw",
        "com_kor_mhw",
        "com_kor_mhw.sqlite",
        "mhw",
        "메튜 헨리 주석",
        MatthewHenryKorExtractor(),
    ),
    _commentary(
        "com_kor_pys",
        "com_kor_pys",
        "com_kor_pys.sqlite",
        "pys",
        "박윤선 주석",
        BakYunsenExtractor(),
    ),
]

# Build lookup by id
_REGISTRY_MAP = {e["id"]: e for e in REGISTRY}

# Tag groups
_BIBLES = [e["id"] for e in REGISTRY if e["type"] == "bible"]
_COMMENTARIES = [e["id"] for e in REGISTRY if e["type"] == "commentary"]
_KO = [e["id"] for e in REGISTRY if e["id"].startswith("kor") and e["type"] == "bible"]
_EN = [e["id"] for e in REGISTRY if e["id"].startswith("eng_")]
_HEB = [e["id"] for e in REGISTRY if e["id"].startswith("heb_")]
_ARAM = [e["id"] for e in REGISTRY if e["id"].startswith("aram_")]
_GRK = [e["id"] for e in REGISTRY if e["id"].startswith("grk_")]
_LAT = [e["id"] for e in REGISTRY if e["id"].startswith("lat_")]


def resolve_targets(raw: str) -> list[dict]:
    """Expand group aliases into a list of registry entries."""
    aliases = {
        "all": [e["id"] for e in REGISTRY],
        "bibles": _BIBLES,
        "commentaries": _COMMENTARIES,
        "kor": _KO,
        "eng": _EN,
        "heb": _HEB,
        "hebrew": _HEB,
        "aram": _ARAM,
        "aramaic": _ARAM,
        "grk": _GRK,
        "greek": _GRK,
        "lat": _LAT,
        "latin": _LAT,
    }
    ids = aliases.get(raw, [raw])
    result = []
    for tid in ids:
        if tid in _REGISTRY_MAP:
            result.append(_REGISTRY_MAP[tid])
        else:
            print(f"[WARN] Unknown target '{tid}', skipping.")
    return result


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────


def crawl_target(entry: dict, retries: int):
    if os.path.exists(entry["out_path"]):
        print(f"  [SKIP] Existing SQLite file found: {entry['out_path']}")
        return

    packager = SqlitePackager(
        out_path=entry["out_path"],
        slug=entry["slug"],
        label=entry["label"],
        books_meta=entry["books_meta"],
    )
    crawler = NocrBoardCrawler(
        board_id=entry["board_id"],
        extractor=entry["extractor"],
        packager=packager,
        retries=retries,
    )
    crawler.crawl()


def main():
    parser = argparse.ArgumentParser(description="nocr.net Bible / Commentary crawler")
    parser.add_argument(
        "--target",
        "-t",
        default="all",
        help="Target ID, group alias (all/bibles/commentaries/ko/en/hebrew/aramaic/greek/latin), or board ID",
    )
    parser.add_argument(
        "--list", "-l", action="store_true", help="List all available targets and exit"
    )
    parser.add_argument(
        "--retries",
        type=int,
        default=5,
        help="Retry count for failed HTTP requests (default: 3)",
    )
    args = parser.parse_args()

    if args.list:
        print("Available targets:")
        for e in REGISTRY:
            print(f"  {e['id']:<25} {e['label']}  [{e['type']}]  board={e['board_id']}")
        print(
            "\nGroup aliases: all, bibles, commentaries, ko, en, hebrew, aramaic, greek, latin"
        )
        return

    targets = resolve_targets(args.target)
    if not targets:
        print("No valid targets. Use --list to see available targets.")
        sys.exit(1)

    print(f"Running {len(targets)} target(s): {[t['id'] for t in targets]}")
    for entry in targets:
        print(f"\n{'=' * 60}")
        print(f"  Target: {entry['id']}  ({entry['label']})")
        print(f"  Board:  {entry['board_id']}")
        print(f"  Output: {entry['out_path']}")
        print(f"{'=' * 60}")
        try:
            crawl_target(entry, retries=args.retries)
        except Exception as exc:
            print(f"[ERROR] {entry['id']}: {exc}")
            import traceback

            traceback.print_exc()


if __name__ == "__main__":
    main()
