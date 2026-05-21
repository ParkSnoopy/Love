r"""
extractors.py — Format-specific text extractors for each nocr.net board.

Each extractor receives (srl: int, title: str, content_html: str) and returns
a list of row-dicts: {book_id, chapter, verse, text}.

=== Board format summary (from empirical observation) ===

BIBLE boards (korwrm, korkrv, korkrb, ...):
  Single div containing:
    "1:1 text<br /><br />1:2 text<br /><br />..."
  Split on `^(\d+):(\d+)\s+` pattern after stripping HTML.

HOCHMA commentary (com_kor_hochma):
  Each verse block: <p>N:M<br />\ncommentary text<br />...</p>
  Verse zero: text before the first N:M marker (chapter intro).
  Book intro: title contains "서론" or chapter == 0.

MATTHEW HENRY commentary (com_kor_mhw):
  Each verse block: <div class="dent"><a id="VN"></a><font color="red">N:M</font>
    followed by paragraphs until next <div class="dent">.
  Section headers are <p><font color="green">...</font></p>.

BAK YUNSEN commentary (com_kor_pys):
  Verse marker: <p class="0"><span ...>창 1:1</span></p>  (책명 장:절)
  Text follows in subsequent <p class="0"> tags.
  Book name prefix ("창 ", "출 ", etc.) maps to canonical book_id.
"""

import re
from html import unescape

# ─────────────────────────────────────────────────────────────────────────────
# Canonical book metadata
# ─────────────────────────────────────────────────────────────────────────────

# (book_id, osis, english_name, korean_name, testament, max_chapters)
BOOKS = [
    (1, "Gen", "Genesis", "창세기", "OT", 50),
    (2, "Exod", "Exodus", "출애굽기", "OT", 40),
    (3, "Lev", "Leviticus", "레위기", "OT", 27),
    (4, "Num", "Numbers", "민수기", "OT", 36),
    (5, "Deut", "Deuteronomy", "신명기", "OT", 34),
    (6, "Josh", "Joshua", "여호수아", "OT", 24),
    (7, "Judg", "Judges", "사사기", "OT", 21),
    (8, "Ruth", "Ruth", "룻기", "OT", 4),
    (9, "1Sam", "1 Samuel", "사무엘상", "OT", 31),
    (10, "2Sam", "2 Samuel", "사무엘하", "OT", 24),
    (11, "1Kgs", "1 Kings", "열왕기상", "OT", 22),
    (12, "2Kgs", "2 Kings", "열왕기하", "OT", 25),
    (13, "1Chr", "1 Chronicles", "역대상", "OT", 29),
    (14, "2Chr", "2 Chronicles", "역대하", "OT", 36),
    (15, "Ezra", "Ezra", "에스라", "OT", 10),
    (16, "Neh", "Nehemiah", "느헤미야", "OT", 13),
    (17, "Esth", "Esther", "에스더", "OT", 10),
    (18, "Job", "Job", "욥기", "OT", 42),
    (19, "Ps", "Psalms", "시편", "OT", 150),
    (20, "Prov", "Proverbs", "잠언", "OT", 31),
    (21, "Eccl", "Ecclesiastes", "전도서", "OT", 12),
    (22, "Song", "Song of Songs", "아가", "OT", 8),
    (23, "Isa", "Isaiah", "이사야", "OT", 66),
    (24, "Jer", "Jeremiah", "예레미야", "OT", 52),
    (25, "Lam", "Lamentations", "예레미야애가", "OT", 5),
    (26, "Ezek", "Ezekiel", "에스겔", "OT", 48),
    (27, "Dan", "Daniel", "다니엘", "OT", 12),
    (28, "Hos", "Hosea", "호세아", "OT", 14),
    (29, "Joel", "Joel", "요엘", "OT", 3),
    (30, "Amos", "Amos", "아모스", "OT", 9),
    (31, "Obad", "Obadiah", "오바댜", "OT", 1),
    (32, "Jonah", "Jonah", "요나", "OT", 4),
    (33, "Mic", "Micah", "미가", "OT", 7),
    (34, "Nah", "Nahum", "나훔", "OT", 3),
    (35, "Hab", "Habakkuk", "하박국", "OT", 3),
    (36, "Zeph", "Zephaniah", "스바냐", "OT", 3),
    (37, "Hag", "Haggai", "학개", "OT", 2),
    (38, "Zech", "Zechariah", "스가랴", "OT", 14),
    (39, "Mal", "Malachi", "말라기", "OT", 4),
    (40, "Matt", "Matthew", "마태복음", "NT", 28),
    (41, "Mark", "Mark", "마가복음", "NT", 16),
    (42, "Luke", "Luke", "누가복음", "NT", 24),
    (43, "John", "John", "요한복음", "NT", 21),
    (44, "Acts", "Acts", "사도행전", "NT", 28),
    (45, "Rom", "Romans", "로마서", "NT", 16),
    (46, "1Cor", "1 Corinthians", "고린도전서", "NT", 16),
    (47, "2Cor", "2 Corinthians", "고린도후서", "NT", 13),
    (48, "Gal", "Galatians", "갈라디아서", "NT", 6),
    (49, "Eph", "Ephesians", "에베소서", "NT", 6),
    (50, "Phil", "Philippians", "빌립보서", "NT", 4),
    (51, "Col", "Colossians", "골로새서", "NT", 4),
    (52, "1Thess", "1 Thessalonians", "데살로니가전서", "NT", 5),
    (53, "2Thess", "2 Thessalonians", "데살로니가후서", "NT", 3),
    (54, "1Tim", "1 Timothy", "디모데전서", "NT", 6),
    (55, "2Tim", "2 Timothy", "디모데후서", "NT", 4),
    (56, "Titus", "Titus", "디도서", "NT", 3),
    (57, "Phlm", "Philemon", "빌레몬서", "NT", 1),
    (58, "Heb", "Hebrews", "히브리서", "NT", 13),
    (59, "Jas", "James", "야고보서", "NT", 5),
    (60, "1Pet", "1 Peter", "베드로전서", "NT", 5),
    (61, "2Pet", "2 Peter", "베드로후서", "NT", 3),
    (62, "1John", "1 John", "요한1서", "NT", 5),
    (63, "2John", "2 John", "요한2서", "NT", 1),
    (64, "3John", "3 John", "요한3서", "NT", 1),
    (65, "Jude", "Jude", "유다서", "NT", 1),
    (66, "Rev", "Revelation", "요한계시록", "NT", 22),
]

# Build lookup structures
BOOK_BY_ID = {b[0]: b for b in BOOKS}
BOOK_META_LIST = [
    {
        "book_id": b[0],
        "osis": b[1],
        "eng_name": b[2],
        "name": b[3],
        "testament": b[4],
        "chapters": b[5],
    }
    for b in BOOKS
]

# INTRO pseudo-book (book_id=0) for general prefaces
INTRO_BOOK_META = {
    "book_id": 0,
    "osis": "INTRO",
    "eng_name": "General Intro",
    "name": "일반 서론/소개",
    "testament": "INTRO",
    "chapters": 0,
}

ALL_BOOKS_META = [INTRO_BOOK_META] + BOOK_META_LIST


# ─────────────────────────────────────────────────────────────────────────────
# Korean book name → book_id lookup (for PYS and other title-based boards)
# ─────────────────────────────────────────────────────────────────────────────

# Full-name → id
_KOR_BOOK_NAME_TO_ID: dict[str, int] = {b[3]: b[0] for b in BOOKS}
_KOR_BOOK_NAME_TO_ID.update(
    {
        "요한일서": 62,
        "요한이서": 63,
        "요한삼서": 64,
    }
)
_ENG_BOOK_NAME_TO_ID: dict[str, int] = {b[2].lower(): b[0] for b in BOOKS}
_ENG_BOOK_NAME_TO_ID.update(
    {
        "psalm": 19,
        "song of solomon": 22,
        "canticles": 22,
        "revelation of john": 66,
    }
)

# Short abbreviations used in PYS ("창", "출", ...) → id
_KOR_ABBREV_TO_ID: dict[str, int] = {
    "창": 1,
    "출": 2,
    "레": 3,
    "민": 4,
    "신": 5,
    "수": 6,
    "삿": 7,
    "룻": 8,
    "삼상": 9,
    "삼하": 10,
    "왕상": 11,
    "왕하": 12,
    "대상": 13,
    "대하": 14,
    "스": 15,
    "느": 16,
    "에": 17,
    "욥": 18,
    "시": 19,
    "잠": 20,
    "전": 21,
    "아": 22,
    "사": 23,
    "렘": 24,
    "애": 25,
    "겔": 26,
    "단": 27,
    "호": 28,
    "욜": 29,
    "암": 30,
    "옵": 31,
    "욘": 32,
    "미": 33,
    "나": 34,
    "합": 35,
    "습": 36,
    "학": 37,
    "슥": 38,
    "말": 39,
    "마": 40,
    "막": 41,
    "눅": 42,
    "요": 43,
    "행": 44,
    "롬": 45,
    "고전": 46,
    "고후": 47,
    "갈": 48,
    "엡": 49,
    "빌": 50,
    "골": 51,
    "살전": 52,
    "살후": 53,
    "딤전": 54,
    "딤후": 55,
    "딛": 56,
    "몬": 57,
    "히": 58,
    "약": 59,
    "벧전": 60,
    "벧후": 61,
    "요일": 62,
    "요이": 63,
    "요삼": 64,
    "유": 65,
    "계": 66,
}

# English abbreviation → id (for English commentaries)
_ENG_ABBREV_TO_ID: dict[str, int] = {
    "gen": 1,
    "exod": 2,
    "ex": 2,
    "lev": 3,
    "num": 4,
    "deut": 5,
    "dt": 5,
    "josh": 6,
    "judg": 7,
    "jdg": 7,
    "ruth": 8,
    "rut": 8,
    "1sam": 9,
    "2sam": 10,
    "1kgs": 11,
    "1ki": 11,
    "2kgs": 12,
    "2ki": 12,
    "1chr": 13,
    "1ch": 13,
    "2chr": 14,
    "2ch": 14,
    "ezra": 15,
    "neh": 16,
    "esth": 17,
    "est": 17,
    "job": 18,
    "ps": 19,
    "psa": 19,
    "prov": 20,
    "pr": 20,
    "eccl": 21,
    "ec": 21,
    "song": 22,
    "isa": 23,
    "is": 23,
    "jer": 24,
    "lam": 25,
    "ezek": 26,
    "eze": 26,
    "dan": 27,
    "hos": 28,
    "joel": 29,
    "jl": 29,
    "amos": 30,
    "am": 30,
    "obad": 31,
    "ob": 31,
    "jonah": 32,
    "jon": 32,
    "mic": 33,
    "nah": 34,
    "hab": 35,
    "zeph": 36,
    "zep": 36,
    "hag": 37,
    "zech": 38,
    "zec": 38,
    "mal": 39,
    "matt": 40,
    "mt": 40,
    "mark": 41,
    "mk": 41,
    "luke": 42,
    "lk": 42,
    "john": 43,
    "jn": 43,
    "acts": 44,
    "ac": 44,
    "rom": 45,
    "1cor": 46,
    "2cor": 47,
    "gal": 48,
    "eph": 49,
    "phil": 50,
    "php": 50,
    "col": 51,
    "1thess": 52,
    "1th": 52,
    "2thess": 53,
    "2th": 53,
    "1tim": 54,
    "1ti": 54,
    "2tim": 55,
    "2ti": 55,
    "titus": 56,
    "tit": 56,
    "phlm": 57,
    "phm": 57,
    "heb": 58,
    "jas": 59,
    "jms": 59,
    "1pet": 60,
    "1pe": 60,
    "2pet": 61,
    "2pe": 61,
    "1john": 62,
    "1jn": 62,
    "2john": 63,
    "2jn": 63,
    "3john": 64,
    "3jn": 64,
    "jude": 65,
    "jud": 65,
    "rev": 66,
}


def kor_abbrev_to_book_id(abbrev: str) -> int | None:
    abbrev = abbrev.strip()
    return _KOR_ABBREV_TO_ID.get(abbrev) or _KOR_BOOK_NAME_TO_ID.get(abbrev)


def eng_abbrev_to_book_id(abbrev: str) -> int | None:
    return _ENG_ABBREV_TO_ID.get(abbrev.lower().strip())


# ─────────────────────────────────────────────────────────────────────────────
# HTML stripping utilities
# ─────────────────────────────────────────────────────────────────────────────

_STRIP_TAGS_RE = re.compile(r"<[^>]+>")
_MULTI_NEWLINE_RE = re.compile(r"\n{3,}")
_TRAILING_CRUFT_RE = re.compile(
    r"(?:\s*Next\s*|\s*이전\s*|\s*목록\s*|\s*다음\s*|"
    r"\s*List\s*|\s*Prev\s*|\s*\d{4}\.\d{2}\.\d{2}.*)+$",
    re.IGNORECASE,
)
_NBSP_RE = re.compile(r"&nbsp;|&#160;|\u00a0")
_HTML_BR_RE = re.compile(r"<br\s*/?>", re.IGNORECASE)


def strip_html(html: str) -> str:
    """Convert HTML to plain text, collapsing whitespace."""
    text = _HTML_BR_RE.sub("\n", html)
    text = _STRIP_TAGS_RE.sub("", text)
    text = unescape(text)
    text = _NBSP_RE.sub(" ", text)
    return text


def clean_text(text: str) -> str:
    """Remove trailing navigation artifacts and excessive whitespace."""
    text = _TRAILING_CRUFT_RE.sub("", text)
    text = _MULTI_NEWLINE_RE.sub("\n\n", text)
    return text.strip()


# ─────────────────────────────────────────────────────────────────────────────
# Title → (book_id, chapter) parser  (used by Bible boards)
# ─────────────────────────────────────────────────────────────────────────────

# Title format: "{Board prefix} {KorBookName} {NN}장"
# e.g. "우리말성경 창세기 01장"  →  book_id=1, chapter=1
_TITLE_BOOK_CHAPTER_RE = re.compile(r"([가-힣\s]+?)\s+(\d+)장$")
_ENG_TITLE_BOOK_CHAPTER_RE = re.compile(
    r"(?:^|,)\s*([1-3]?\s*[A-Za-z][A-Za-z\s]+?)\s*,?\s*Chapter\s+(\d+)$",
    re.IGNORECASE,
)


def title_to_book_chapter(title: str) -> tuple[int, int] | None:
    """Parse title like '우리말성경 창세기 01장' → (1, 1)."""
    title = title.strip()
    m = _TITLE_BOOK_CHAPTER_RE.search(title)
    if m:
        book_phrase, chap_str = m.group(1).strip(), m.group(2)
        # The book phrase may include the board prefix (e.g. "우리말성경 창세기")
        # Try the last token first, then progressively longer suffixes.
        tokens = book_phrase.split()
        for start in range(len(tokens) - 1, -1, -1):
            candidate = "".join(tokens[start:])
            bid = kor_abbrev_to_book_id(candidate)
            if bid:
                return (bid, int(chap_str))

    m = _ENG_TITLE_BOOK_CHAPTER_RE.search(title)
    if m:
        book_name = re.sub(r"\s+", " ", m.group(1)).strip().lower()
        bid = _ENG_BOOK_NAME_TO_ID.get(book_name)
        if bid:
            return (bid, int(m.group(2)))

    return None


# ─────────────────────────────────────────────────────────────────────────────
# BASE EXTRACTOR
# ─────────────────────────────────────────────────────────────────────────────


class BaseExtractor:
    """
    Abstract extractor. Subclasses implement `extract(srl, title, content_html)`.
    Returns a list of row-dicts: {book_id, chapter, verse, text}.
    """

    def extract(self, srl: int, title: str, content_html: str) -> list[dict]:
        raise NotImplementedError


# ─────────────────────────────────────────────────────────────────────────────
# BIBLE EXTRACTOR  (all Korean / Japanese / Chinese / English Bible boards)
# ─────────────────────────────────────────────────────────────────────────────

# "1:1 text  <br /><br />1:2 text …"
_BIBLE_VERSE_SPLIT_RE = re.compile(r"(?<!\d)(\d+):(\d+)\s+")


class BibleExtractor(BaseExtractor):
    """
    Extracts verse-by-verse rows from Bible board articles.

    The content_html structure (after inner HTML of rhymix_content div) is:
      "1:1 텍스트  <br /><br />1:2 텍스트  <br /><br />..."

    Steps:
      1. Strip HTML tags → plain text with newlines at <br />.
      2. Split on `N:M ` pattern.
      3. Derive book_id and chapter from article title.
    """

    def extract(self, srl: int, title: str, content_html: str) -> list[dict]:
        parsed = title_to_book_chapter(title)
        if parsed is None:
            print(f"  [WARN] Cannot parse title '{title}' (srl={srl})")
            return []
        book_id, chapter = parsed

        plain = strip_html(content_html)
        plain = clean_text(plain)

        # Split into verse chunks: find all "N:M " markers
        parts = _BIBLE_VERSE_SPLIT_RE.split(plain)
        # parts = [pre_text, ch1, v1, text1, ch2, v2, text2, ...]
        rows = []
        i = 1
        while i + 2 <= len(parts):
            ch_str, v_str, text = parts[i], parts[i + 1], parts[i + 2]
            i += 3
            ch, v = int(ch_str), int(v_str)
            if ch != chapter:
                # Some articles contain a trailing verse from next/prev chapter
                continue
            text = clean_text(text)
            if text:
                rows.append(
                    {"book_id": book_id, "chapter": ch, "verse": v, "text": text}
                )

        return rows


# ─────────────────────────────────────────────────────────────────────────────
# HOCHMA COMMENTARY EXTRACTOR
# ─────────────────────────────────────────────────────────────────────────────

_HOCHMA_VERSE_HEADER_RE = re.compile(
    r"<p[^>]*>\s*(\d+):(\d+)\s*<br\s*/?>\s*\r?\n?",
    re.IGNORECASE,
)


class HochmaExtractor(BaseExtractor):
    """
    Extracts commentary rows from the Hochma board (com_kor_hochma).

    Format:
      <p>1:1<br />
      commentary text for verse 1:1
      <br />...</p>
      <p>1:2<br />
      ...

    Verse 0 (chapter intro): text before the first verse header.
    Book intro (chapter=0, verse=0): detected by title containing "서론".
    General preface: book_id=0, chapter=0, verse=N.
    """

    def extract(self, srl: int, title: str, content_html: str) -> list[dict]:
        # Determine context from title
        parsed = title_to_book_chapter(title)

        # Check if this is a book-level intro ("서론", "개론", etc.)
        is_book_intro = any(w in title for w in ("서론", "개론", "서문", "소개"))
        # Check if it's the general preface (no book reference in title)
        is_general_intro = parsed is None and not is_book_intro

        if is_general_intro or (is_book_intro and parsed is None):
            # General preface: store under book_id=0
            text = strip_html(content_html)
            text = clean_text(text)
            if text:
                return [
                    {"book_id": 0, "chapter": 0, "verse": srl % 10000, "text": text}
                ]
            return []

        if parsed is None:
            print(f"  [WARN] Hochma: cannot parse title '{title}' (srl={srl})")
            return []

        book_id, chapter = parsed

        if is_book_intro:
            text = strip_html(content_html)
            text = clean_text(text)
            if text:
                return [{"book_id": book_id, "chapter": 0, "verse": 0, "text": text}]
            return []

        # Split by verse headers
        parts = _HOCHMA_VERSE_HEADER_RE.split(content_html)
        # parts[0] = text before first header (chapter intro candidate)
        # then triplets: ch_str, v_str, text_html

        rows = []

        # Chapter intro (verse=0) — text before first verse marker
        if parts[0]:
            intro_text = strip_html(parts[0])
            intro_text = clean_text(intro_text)
            if intro_text:
                rows.append(
                    {
                        "book_id": book_id,
                        "chapter": chapter,
                        "verse": 0,
                        "text": intro_text,
                    }
                )

        i = 1
        while i + 2 <= len(parts):
            ch_str, v_str, text_html = parts[i], parts[i + 1], parts[i + 2]
            i += 3
            ch, v = int(ch_str), int(v_str)
            text = strip_html(text_html)
            text = clean_text(text)
            if text:
                rows.append(
                    {"book_id": book_id, "chapter": ch, "verse": v, "text": text}
                )

        return rows


# ─────────────────────────────────────────────────────────────────────────────
# MATTHEW HENRY COMMENTARY EXTRACTOR (Korean — com_kor_mhw)
# ─────────────────────────────────────────────────────────────────────────────

# <div class="dent"><a id="V1"></a><font color="red">1:1</font>
_MHW_VERSE_DIV_RE = re.compile(
    r'<div[^>]+class="dent"[^>]*>\s*<a[^>]+id="V(\d+)"[^>]*></a>\s*'
    r"<font[^>]*>(\d+):(\d+)</font>",
    re.IGNORECASE | re.DOTALL,
)


class MatthewHenryKorExtractor(BaseExtractor):
    """
    Korean Matthew Henry commentary (com_kor_mhw).

    Format:
      <div class="dent"><a id="VN"></a><font color="red">ch:v</font>
        (followed by HTML content until next dent div)

    Verse 0 (chapter intro): content before the first dent div.
    """

    def extract(self, srl: int, title: str, content_html: str) -> list[dict]:
        parsed = title_to_book_chapter(title)

        is_book_intro = any(w in title for w in ("서론", "개론", "서문", "소개"))
        is_general = parsed is None and not is_book_intro

        if is_general:
            text = strip_html(content_html)
            text = clean_text(text)
            if text:
                return [
                    {"book_id": 0, "chapter": 0, "verse": srl % 10000, "text": text}
                ]
            return []

        if parsed is None:
            print(f"  [WARN] MHW: cannot parse title '{title}' (srl={srl})")
            return []

        book_id, chapter = parsed

        if is_book_intro:
            text = strip_html(content_html)
            text = clean_text(text)
            if text:
                return [{"book_id": book_id, "chapter": 0, "verse": 0, "text": text}]
            return []

        # Find all verse-div positions
        markers = list(_MHW_VERSE_DIV_RE.finditer(content_html))

        rows = []

        # Chapter intro: everything before first marker
        if markers:
            intro_html = content_html[: markers[0].start()]
            intro_text = strip_html(intro_html)
            intro_text = clean_text(intro_text)
            if intro_text:
                rows.append(
                    {
                        "book_id": book_id,
                        "chapter": chapter,
                        "verse": 0,
                        "text": intro_text,
                    }
                )
        else:
            # No verse markers found; store whole text as chapter-level
            text = strip_html(content_html)
            text = clean_text(text)
            if text:
                rows.append(
                    {"book_id": book_id, "chapter": chapter, "verse": 0, "text": text}
                )
            return rows

        # Verse segments
        for idx, m in enumerate(markers):
            ch, v = int(m.group(2)), int(m.group(3))
            start = m.end()
            end = (
                markers[idx + 1].start()
                if idx + 1 < len(markers)
                else len(content_html)
            )
            seg_html = content_html[start:end]
            text = strip_html(seg_html)
            text = clean_text(text)
            if text:
                rows.append(
                    {"book_id": book_id, "chapter": ch, "verse": v, "text": text}
                )

        return rows


# ─────────────────────────────────────────────────────────────────────────────
# BAK YUNSEN COMMENTARY EXTRACTOR (com_kor_pys)
# ─────────────────────────────────────────────────────────────────────────────

# Marker: <p class="0"><span ...>창 1:1</span></p>
# The book abbrev + chapter:verse are in the span text.
_PYS_VERSE_MARKER_RE = re.compile(
    r'<p[^>]+class="0"[^>]*>\s*<span[^>]*>\s*'
    r"([가-힣]+)\s+(\d+):(\d+)"  # group 1=abbrev, 2=ch, 3=v
    r"[^<]*</span>\s*</p>",
    re.IGNORECASE | re.DOTALL,
)

# Paragraph content: <p class="0"><span ...>text</span></p>
_PYS_PARA_RE = re.compile(
    r'<p[^>]+class="0"[^>]*>(.*?)</p>',
    re.IGNORECASE | re.DOTALL,
)


class BakYunsenExtractor(BaseExtractor):
    """
    Bak Yunsen commentary (com_kor_pys).

    Format:
      <p class="0"><span ...>창 1:1</span></p>     ← verse marker
      <p class="0"><span ...>본문text</span></p>
      <p class="0"><span ...>commentary...</span></p>
      <p class="0"><span ...>창 1:2</span></p>     ← next verse marker
      ...

    The article title specifies the book + chapter (same as other boards).
    We use the in-text "창 1:1" markers to split verses precisely.
    """

    def extract(self, srl: int, title: str, content_html: str) -> list[dict]:
        parsed = title_to_book_chapter(title)

        is_book_intro = any(w in title for w in ("서론", "개론", "서문", "소개"))
        is_general = parsed is None and not is_book_intro

        if is_general:
            text = strip_html(content_html)
            text = clean_text(text)
            if text:
                return [
                    {"book_id": 0, "chapter": 0, "verse": srl % 10000, "text": text}
                ]
            return []

        if parsed is None:
            print(f"  [WARN] PYS: cannot parse title '{title}' (srl={srl})")
            return []

        book_id, chapter = parsed

        if is_book_intro:
            text = strip_html(content_html)
            text = clean_text(text)
            if text:
                return [{"book_id": book_id, "chapter": 0, "verse": 0, "text": text}]
            return []

        # Tokenise the content into (type, data) sequence:
        #   type "verse" → (abbrev, ch, v, pos)
        #   type "para"  → (text, pos)
        markers = []
        for m in _PYS_VERSE_MARKER_RE.finditer(content_html):
            abbrev, ch_s, v_s = m.group(1), m.group(2), m.group(3)
            bid = kor_abbrev_to_book_id(abbrev)
            if bid is None:
                continue
            markers.append((m.start(), m.end(), bid, int(ch_s), int(v_s)))

        if not markers:
            # No verse markers — store as chapter-level commentary
            text = strip_html(content_html)
            text = clean_text(text)
            if text:
                return [
                    {"book_id": book_id, "chapter": chapter, "verse": 0, "text": text}
                ]
            return []

        rows = []

        # Text before the first verse marker → chapter intro (verse=0)
        pre_text = strip_html(content_html[: markers[0][0]])
        pre_text = clean_text(pre_text)
        if pre_text:
            rows.append(
                {"book_id": book_id, "chapter": chapter, "verse": 0, "text": pre_text}
            )

        # Collect text between each pair of markers
        for idx, (mstart, mend, bid, ch, v) in enumerate(markers):
            seg_end = (
                markers[idx + 1][0] if idx + 1 < len(markers) else len(content_html)
            )
            seg_html = content_html[mend:seg_end]
            text = strip_html(seg_html)
            text = clean_text(text)
            if text:
                rows.append({"book_id": bid, "chapter": ch, "verse": v, "text": text})

        return rows
