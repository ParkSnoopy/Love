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
  ../assets/data/nocr/<id>.sqlite      (Bibles)
  ../assets/data/comment/<id>.sqlite   (commentaries)
"""

import argparse
import os
import sys

# Allow running from the tools/ directory
sys.path.insert(0, os.path.dirname(__file__))

from nocr_crawler import NocrBoardCrawler, SqlitePackager
from extractors import (
    ALL_BOOKS_META, BOOK_META_LIST, INTRO_BOOK_META,
    BibleExtractor, HochmaExtractor, MatthewHenryKorExtractor, BakYunsenExtractor,
)

# ─────────────────────────────────────────────────────────────────────────────
# Output path helper
# ─────────────────────────────────────────────────────────────────────────────

_TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
_ASSETS_DIR = os.path.join(_TOOLS_DIR, "..", "assets", "data")


def bible_path(filename: str) -> str:
    return os.path.join(_ASSETS_DIR, "nocr", filename)


def comment_path(filename: str) -> str:
    return os.path.join(_ASSETS_DIR, "comment", filename)


# ─────────────────────────────────────────────────────────────────────────────
# Board registry
# ─────────────────────────────────────────────────────────────────────────────
# Each entry: (target_id, board_id, out_path, slug, label, extractor, books_meta)

def _bible(target_id: str, board_id: str, out_file: str, slug: str, label: str):
    return {
        "id": target_id,
        "board_id": board_id,
        "out_path": bible_path(out_file),
        "slug": slug,
        "label": label,
        "extractor": BibleExtractor(),
        "books_meta": BOOK_META_LIST,
        "type": "bible",
    }


def _commentary(target_id: str, board_id: str, out_file: str, slug: str, label: str, extractor):
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
    _bible("korwrm",  "korwrm",  "ko_korwrm.sqlite",  "korwrm",  "우리말 성경"),
    _bible("korkrv",  "korkrv",  "ko_korkrv.sqlite",  "korkrv",  "KOREAN 개역개정판"),
    _bible("korkr4",  "korkr4",  "ko_korkr4.sqlite",  "korkr4",  "개역개정 4판"),
    _bible("korkrb",  "korkrb",  "ko_korkrb.sqlite",  "korkrb",  "KOREAN 바른성경"),
    _bible("korbbh",  "korbbh",  "ko_korbbh.sqlite",  "korbbh",  "바른성경 한문"),
    _bible("kornks",  "kornks",  "ko_kornks.sqlite",  "kornks",  "KOREAN 표준새번역"),
    _bible("kornrr",  "kornrr",  "ko_kornrr.sqlite",  "kornrr",  "새번역"),
    _bible("korkjv",  "korkjv",  "ko_korkjv.sqlite",  "korkjv",  "한글 KJV"),
    _bible("korhum",  "korhum",  "ko_korhum.sqlite",  "korhum",  "한글 흠정역"),
    _bible("korkcb",  "korkcb",  "ko_korkcb.sqlite",  "korkcb",  "공동번역"),
    _bible("korctr",  "korctr",  "ko_korctr.sqlite",  "korctr",  "KOREAN 공동번역 개정판"),
    _bible("korcat",  "korkcc",  "ko_korcat.sqlite",  "korcat",  "KOREAN 카톨릭 성경"),
    _bible("korkmb",  "korklb",  "ko_korkmb.sqlite",  "korkmb",  "KOREAN 현대인의 성경"),
    _bible("korkml",  "kortkv",  "ko_korkml.sqlite",  "korkml",  "KOREAN 현대어 성경"),
    _bible("korhrc",  "korhrv",  "ko_korhrc.sqlite",  "korhrc",  "KOREAN 개역성경 국한문혼용"),

    # ── Japanese Bibles ────────────────────────────────────────────────────
    # Board IDs discovered from nav: japkougo → need to verify actual board IDs
    # Update these if the actual board IDs differ from the manifest IDs.
    # The manifest uses: ja_japbungo, ja_japkougo, ja_japshia
    # Based on nocr.net URL structure (board = mid in XE), we try common patterns.
    _bible("ja_japbungo",  "japbungo",  "ja_japbungo.sqlite",  "japbungo",  "JAPANESE 文語訳聖書"),
    _bible("ja_japkougo",  "japkougo",  "ja_japkougo.sqlite",  "japkougo",  "JAPANESE 口語訳聖書 (1954/1955)"),
    _bible("ja_japshia",   "japshia",   "ja_japshia.sqlite",   "japshia",   "JAPANESE 新共同訳聖書"),

    # ── Chinese Bibles ─────────────────────────────────────────────────────
    _bible("zh_chnlzzs", "chnlzzs", "zh_chnlzzs.sqlite", "chnlzzs", "CHINESE 吕振中版本简体"),
    _bible("zh_chnlzzt", "chnlzzt", "zh_chnlzzt.sqlite", "chnlzzt", "CHINESE 吕振中版本繁体"),
    _bible("zh_chnncvs", "chnncvs", "zh_chnncvs.sqlite", "chnncvs", "CHINESE 新中文版 (简体)"),
    _bible("zh_chnncvt", "chnncvt", "zh_chnncvt.sqlite", "chnncvt", "CHINESE 新中文版 (繁体)"),
    _bible("zh_ckjvgs",  "ckjvgs",  "zh_ckjvgs.sqlite",  "ckjvgs",  "CHINESE 中文英皇钦定本神版简体"),
    _bible("zh_ckjvgt",  "ckjvgt",  "zh_ckjvgt.sqlite",  "ckjvgt",  "CHINESE 中文英皇钦定本神版繁體"),
    _bible("zh_ckjvsds", "ckjvsds", "zh_ckjvsds.sqlite", "ckjvsds", "CHINESE 中文英皇钦定本上帝版 简体"),
    _bible("zh_ckjvsdt", "ckjvsdt", "zh_ckjvsdt.sqlite", "ckjvsdt", "CHINESE 中文英皇钦定本上帝版 繁体"),
    _bible("zh_twnthr",  "twnthr",  "zh_twnthr.sqlite",  "twnthr",  "TAIWAN 台語漢字羅馬本"),

    # ── English Bibles ─────────────────────────────────────────────────────
    _bible("en_engniv", "engniv",  "en_engniv.sqlite",  "engniv",  "New International Version"),
    _bible("en_engrwb", "engrwbs", "en_engrwb.sqlite",  "engrwb",  "ENGLISH Revised Webter Version 1883"),

    # ── Korean Commentaries ────────────────────────────────────────────────
    _commentary("com_kor_hochma", "com_kor_hochma", "com_kor_hochma.sqlite",
                "hochma", "호크마 주석", HochmaExtractor()),
    _commentary("com_kor_mhw",    "com_kor_mhw",    "com_kor_mhw.sqlite",
                "mhw", "메튜 헨리 주석 전체", MatthewHenryKorExtractor()),
    _commentary("com_kor_pys",    "com_kor_pys",    "com_kor_pys.sqlite",
                "pys", "박윤선 주석", BakYunsenExtractor()),
]

# Build lookup by id
_REGISTRY_MAP = {e["id"]: e for e in REGISTRY}

# Tag groups
_BIBLES      = [e["id"] for e in REGISTRY if e["type"] == "bible"]
_COMMENTARIES = [e["id"] for e in REGISTRY if e["type"] == "commentary"]
_KO          = [e["id"] for e in REGISTRY if e["id"].startswith("kor") and e["type"] == "bible"]
_JA          = [e["id"] for e in REGISTRY if e["id"].startswith("ja_")]
_ZH          = [e["id"] for e in REGISTRY if e["id"].startswith("zh_")]
_EN          = [e["id"] for e in REGISTRY if e["id"].startswith("en_")]


def resolve_targets(raw: str) -> list[dict]:
    """Expand group aliases into a list of registry entries."""
    aliases = {
        "all":          [e["id"] for e in REGISTRY],
        "bibles":       _BIBLES,
        "commentaries": _COMMENTARIES,
        "ko":           _KO,
        "ja":           _JA,
        "zh":           _ZH,
        "en":           _EN,
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

def crawl_target(entry: dict):
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
    )
    crawler.crawl()


def main():
    parser = argparse.ArgumentParser(description="nocr.net Bible / Commentary crawler")
    parser.add_argument("--target", "-t", default="all",
                        help="Target ID, group alias (all/bibles/commentaries/ko/ja/zh/en), or board ID")
    parser.add_argument("--list", "-l", action="store_true",
                        help="List all available targets and exit")
    args = parser.parse_args()

    if args.list:
        print("Available targets:")
        for e in REGISTRY:
            print(f"  {e['id']:<25} {e['label']}  [{e['type']}]  board={e['board_id']}")
        print("\nGroup aliases: all, bibles, commentaries, ko, ja, zh, en")
        return

    targets = resolve_targets(args.target)
    if not targets:
        print("No valid targets. Use --list to see available targets.")
        sys.exit(1)

    print(f"Running {len(targets)} target(s): {[t['id'] for t in targets]}")
    for entry in targets:
        print(f"\n{'='*60}")
        print(f"  Target: {entry['id']}  ({entry['label']})")
        print(f"  Board:  {entry['board_id']}")
        print(f"  Output: {entry['out_path']}")
        print(f"{'='*60}")
        try:
            crawl_target(entry)
        except Exception as exc:
            print(f"[ERROR] {entry['id']}: {exc}")
            import traceback
            traceback.print_exc()


if __name__ == "__main__":
    main()
