"""
nocr_crawler.py — Core crawling engine for nocr.net (Rhymix/XE board system).

Strategy:
  1. Fetch board list pages (/board_id/page/N?listStyle=viewer) to collect (title, srl) pairs.
  2. Fetch each article (/board_id/{srl}?listStyle=viewer) and extract the
     `div.rhymix_content.xe_content` inner HTML.
  3. Pass (title, html) to a board-specific Extractor subclass (see extractors.py).
  4. Store results via SqlitePackager.

All HTTP requests use concurrent.futures for max throughput (no sleep).
"""

import re
import sqlite3
import os
import threading
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor, as_completed
from html.parser import HTMLParser

BASE_URL = "https://nocr.net"
HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (compatible; Googlebot/2.1; "
        "+http://www.google.com/bot.html)"
    ),
    "Accept-Language": "ko,en;q=0.9",
}
MAX_WORKERS = 12
MAX_TIMEOUT = 120


# ─────────────────────────────────────────────────────────────────────────────
# Low-level HTTP helper
# ─────────────────────────────────────────────────────────────────────────────


def fetch(url: str, retries: int = 0, label: str | None = None) -> str:
    """Fetch a URL and return text (UTF-8). Retries transient failures immediately (no sleep)."""
    last_exc = None
    for attempt in range(retries + 1):
        try:
            req = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(req, timeout=MAX_TIMEOUT) as resp:
                raw = resp.read()
                # Try UTF-8 first; fall back to detected charset.
                for enc in ("utf-8", "euc-kr", "cp949"):
                    try:
                        return raw.decode(enc)
                    except UnicodeDecodeError:
                        continue
                return raw.decode("utf-8", errors="replace")
        except (TimeoutError, urllib.error.URLError, ConnectionError) as exc:
            last_exc = exc
            if attempt < retries:
                where = label or url
                print(
                    f"  [WARN] {where}: retry {attempt + 1}/{retries} after error: {exc} "
                    f"(url={url})",
                    flush=True,
                )
                continue
            raise
    if last_exc is not None:
        raise last_exc
    raise RuntimeError(f"fetch retry loop failed without exception: {label or url}")


# ─────────────────────────────────────────────────────────────────────────────
# HTML parsing helpers
# ─────────────────────────────────────────────────────────────────────────────

_CONTENT_DIV_RE = re.compile(
    r'<div[^>]+class="[^"]*rhymix_content xe_content[^"]*"[^>]*>(.*?)</div>'
    r"\s*<!--AfterDocument",
    re.DOTALL | re.IGNORECASE,
)

_ARTICLE_LINK_RE = re.compile(r'href="(/[^"]+/(\d+)\?listStyle=viewer)"')

_TITLE_RE = re.compile(
    r'<span class="tl">(.*?)</span>',
    re.DOTALL | re.IGNORECASE,
)

_VIEWER_LIST_LINK_RE = re.compile(
    r'<a[^>]+href="(/([^/"]+)/(\d+)\?listStyle=viewer[^"]*?)"[^>]*>\s*<span class="tl">(.*?)</span>',
    re.DOTALL | re.IGNORECASE,
)

_PAGE_COUNT_RE = re.compile(r"/page/(\d+)\?listStyle=viewer")


def extract_content_html(page_html: str) -> str | None:
    """Extract inner HTML of the main rhymix_content div."""
    m = _CONTENT_DIV_RE.search(page_html)
    if m:
        return m.group(1)
    return None


def extract_articles_from_list_page(html: str, board_id: str) -> list[tuple[int, str]]:
    """
    Returns list of (srl, title) pairs visible in the viewer sidebar list.
    The sidebar list (`#viewer_lst`) shows all articles for the board on one scroll.
    """
    results = []
    seen = set()
    for m in _VIEWER_LIST_LINK_RE.finditer(html):
        # group(1)=full href, group(2)=board_mid, group(3)=srl, group(4)=title
        mid, srl_str, title = m.group(2), m.group(3), m.group(4)
        if mid != board_id:
            continue
        srl = int(srl_str)
        if srl in seen:
            continue
        seen.add(srl)
        title = re.sub(r"<[^>]+>", "", title).strip()
        results.append((srl, title))
    return results


def max_page_number(html: str) -> int:
    """Find the largest page= value in pagination links."""
    nums = [int(x) for x in _PAGE_COUNT_RE.findall(html)]
    return max(nums) if nums else 1


# ─────────────────────────────────────────────────────────────────────────────
# Core crawler
# ─────────────────────────────────────────────────────────────────────────────


class NocrBoardCrawler:
    """
    Crawls a single nocr.net board and calls extractor.extract(srl, title, html)
    for every article, then hands results to packager.
    """

    def __init__(self, board_id: str, extractor, packager, retries: int = 5):
        self.board_id = board_id
        self.extractor = extractor
        self.packager = packager
        self.retries = retries

    # ── Step 1: collect all (srl, title) pairs ───────────────────────────────

    def _fetch_article_list_page(self, page: int) -> list[tuple[int, str]]:
        """Fetch one board list page and return (srl, title) pairs."""
        url = f"{BASE_URL}/{self.board_id}/page/{page}?listStyle=viewer"
        try:
            html = fetch(url, retries=self.retries, label=f"list page {page}")
            return extract_articles_from_list_page(html, self.board_id)
        except Exception as exc:
            print(f"  [WARN] list page {page} failed: {exc}")
            return []

    def collect_article_list(self) -> list[tuple[int, str]]:
        """
        Fetch page/1 to find total pages, then fetch all list pages in parallel
        to build the complete (srl, title) list.

        Note: nocr.net shows a sliding window of 15 page links at a time,
        so page 1 may only show links up to page 15 even if there are 19 pages.
        We probe beyond the initial max until we find the true last page.
        """
        print(f"[{self.board_id}] Fetching page 1 to find article count…")
        url1 = f"{BASE_URL}/{self.board_id}/page/1?listStyle=viewer"
        try:
            html1 = fetch(url1, retries=self.retries, label="list page 1")
        except Exception as exc:
            raise RuntimeError(f"Cannot fetch board index: {exc}")

        articles = extract_articles_from_list_page(html1, self.board_id)
        seen_srls = {s for s, _ in articles}

        # Discover true last page by walking the sliding pagination window.
        # Some boards (e.g. korkrv) expose only a few future links per page:
        # page 1 -> 10, page 10 -> 14, ... until final page 60.
        initial_max = max_page_number(html1)
        true_max = initial_max
        while true_max > 1:
            boundary_html = fetch(
                f"{BASE_URL}/{self.board_id}/page/{true_max}?listStyle=viewer",
                retries=self.retries,
                label=f"list page {true_max}",
            )
            next_max = max(max_page_number(boundary_html), true_max)
            if next_max == true_max:
                break
            print(
                f"[{self.board_id}] Pagination window extends: {true_max} -> {next_max}",
                flush=True,
            )
            true_max = next_max

        print(
            f"[{self.board_id}] {true_max} list pages, {len(articles)} articles on p.1"
        )

        if true_max > 1:
            total_extra_pages = true_max - 1
            fetched_pages = 0
            print(
                f"[{self.board_id}] Fetching {total_extra_pages} more list pages "
                f"with {MAX_WORKERS} workers…",
                flush=True,
            )
            with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
                futs = {
                    pool.submit(self._fetch_article_list_page, p): p
                    for p in range(2, true_max + 1)
                }
                for fut in as_completed(futs):
                    page_articles = fut.result()
                    fetched_pages += 1
                    before = len(seen_srls)
                    for srl, title in page_articles:
                        if srl not in seen_srls:
                            seen_srls.add(srl)
                            articles.append((srl, title))
                    if fetched_pages % 5 == 0 or fetched_pages == total_extra_pages:
                        print(
                            f"[{self.board_id}] List pages {fetched_pages}/{total_extra_pages}; "
                            f"articles discovered={len(articles)}",
                            flush=True,
                        )

        # Sort by SRL (ascending = canonical order)
        articles.sort(key=lambda x: x[0])

        print(f"[{self.board_id}] Total articles discovered: {len(articles)}")
        return articles

    # ── Step 2: fetch + extract each article ─────────────────────────────────

    def _fetch_article(self, srl: int, title: str):
        """Fetch one article and return parsed rows, or None on failure."""
        url = f"{BASE_URL}/{self.board_id}/{srl}?listStyle=viewer"
        try:
            html = fetch(url, retries=self.retries, label=f"article {srl}")
            content_html = extract_content_html(html)
            if content_html is None:
                print(f"  [WARN] No content div in {url}")
                return None
            return self.extractor.extract(srl, title, content_html)
        except Exception as exc:
            print(f"  [WARN] article {srl} failed after {self.retries} retries: {exc}")
            return None

    # ── Main entry ────────────────────────────────────────────────────────────

    def crawl(self):
        """
        Full pipeline:
          1. collect article list
          2. fetch + extract all articles (parallel)
          3. write to DB via packager
        """
        articles = self.collect_article_list()
        if not articles:
            print(f"[{self.board_id}] No articles found, aborting.")
            return

        total = len(articles)
        done = [0]
        lock = threading.Lock()

        def on_done():
            with lock:
                done[0] += 1
                every = max(10, min(50, total // 20 or 1))
                if done[0] % every == 0 or done[0] == total:
                    pct = (done[0] / total) * 100
                    print(
                        f"[{self.board_id}] Articles {done[0]}/{total} ({pct:.1f}%); "
                        f"rows extracted={len(results)}",
                        flush=True,
                    )

        print(
            f"[{self.board_id}] Fetching {total} articles with {MAX_WORKERS} workers…"
        )
        results = []
        with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
            futs = {
                pool.submit(self._fetch_article, srl, title): (srl, title)
                for srl, title in articles
            }
            for fut in as_completed(futs):
                rows = fut.result()
                if rows:
                    results.extend(rows)
                on_done()

        print(f"[{self.board_id}] Extracted {len(results)} rows. Writing to DB…")
        self.packager.write(results)
        print(f"[{self.board_id}] Done.")


# ─────────────────────────────────────────────────────────────────────────────
# SQLite packager
# ─────────────────────────────────────────────────────────────────────────────


class SqlitePackager:
    """
    Writes crawled data into a SQLite file using the standard app schema:
      version, books, verses tables + indexing view + idx_v_bc index.

    `rows` passed to write() is a list of dicts:
      {
        "book_id": int,   # 0 = INTRO, 1-66 = canonical book
        "chapter": int,   # 0 = intro/book-level
        "verse": int,     # 0 = chapter-level / non-verse
        "text": str,
      }

    Metadata (version slug / label / books list) is supplied at construction.
    """

    SCHEMA_SQL = """
    CREATE TABLE IF NOT EXISTS version (
        slug  TEXT NOT NULL,
        label TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS books (
        book_id    INTEGER PRIMARY KEY,
        osis       TEXT    NOT NULL,
        eng_name   TEXT    NOT NULL,
        name       TEXT    NOT NULL,
        testament  TEXT    NOT NULL,
        chapters   INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE IF NOT EXISTS verses (
        book_id INTEGER NOT NULL,
        chapter INTEGER NOT NULL,
        verse   INTEGER NOT NULL,
        text    TEXT    NOT NULL,
        PRIMARY KEY (book_id, chapter, verse)
    );
    CREATE INDEX IF NOT EXISTS idx_v_bc ON verses(book_id, chapter);
    CREATE VIEW IF NOT EXISTS indexing AS
        SELECT b.book_id, b.osis, b.eng_name, b.name, b.testament, b.chapters,
               v.slug, v.label
        FROM books b, version v;
    """

    def __init__(
        self,
        out_path: str,
        slug: str,
        label: str,
        books_meta: list[
            dict
        ],  # list of {book_id, osis, eng_name, name, testament, chapters}
    ):
        self.out_path = out_path
        self.slug = slug
        self.label = label
        self.books_meta = books_meta
        os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)

    def write(self, rows: list[dict]):
        if os.path.exists(self.out_path):
            os.remove(self.out_path)

        con = sqlite3.connect(self.out_path)
        cur = con.cursor()
        cur.executescript(self.SCHEMA_SQL)

        cur.execute(
            "INSERT INTO version (slug, label) VALUES (?, ?)", (self.slug, self.label)
        )

        for bm in self.books_meta:
            cur.execute(
                "INSERT OR REPLACE INTO books "
                "(book_id, osis, eng_name, name, testament, chapters) "
                "VALUES (?, ?, ?, ?, ?, ?)",
                (
                    bm["book_id"],
                    bm["osis"],
                    bm["eng_name"],
                    bm["name"],
                    bm["testament"],
                    bm["chapters"],
                ),
            )

        # Update chapters count from actual data
        chapter_max: dict[int, int] = {}
        for r in rows:
            bid, ch = r["book_id"], r["chapter"]
            if bid > 0 and ch > 0:
                chapter_max[bid] = max(chapter_max.get(bid, 0), ch)
        for bid, ch in chapter_max.items():
            cur.execute("UPDATE books SET chapters=? WHERE book_id=?", (ch, bid))

        cur.executemany(
            "INSERT OR REPLACE INTO verses (book_id, chapter, verse, text) VALUES (?, ?, ?, ?)",
            [(r["book_id"], r["chapter"], r["verse"], r["text"]) for r in rows],
        )

        con.commit()
        cur.execute("VACUUM")
        con.close()
        print(f"  Wrote {len(rows)} rows → {self.out_path}")
