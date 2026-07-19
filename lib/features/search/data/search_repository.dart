import 'package:sqlite3/sqlite3.dart';

class SearchHit {
  const SearchHit({
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.text,
    this.bibleName,
  });

  final int bookId;
  final int chapter;
  final int verse;
  final String text;
  final String? bibleName;
}

class SearchRepository {
  const SearchRepository();

  List<SearchHit> searchLike({
    required String dbPath,
    required String query,
    required int limit,
    required int offset,
    int? bookIdStart,
    int? bookIdEnd,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
    try {
      final chapterReference = _resolveChapterReference(db, trimmed);
      if (chapterReference != null) {
        final bookIds = chapterReference.bookIds
            .where(
              (bookId) =>
                  (bookIdStart == null || bookId >= bookIdStart) &&
                  (bookIdEnd == null || bookId <= bookIdEnd),
            )
            .toList(growable: false);
        if (bookIds.isEmpty) return const [];
        final placeholders = List.filled(bookIds.length, '?').join(', ');
        final rows = db.select(
          'SELECT book_id, chapter, verse, text FROM verses '
          'WHERE book_id IN ($placeholders) AND chapter = ? '
          'ORDER BY book_id, verse LIMIT ? OFFSET ?',
          [...bookIds, chapterReference.chapter, limit, offset],
        );
        return _mapHits(rows);
      }

      final minLen = _isCjk(trimmed) ? 1 : 2;
      if (trimmed.runes.length < minLen) return const [];
      final escaped = trimmed
          .replaceAll('\\', '\\\\')
          .replaceAll('%', '\\%')
          .replaceAll('_', '\\_');
      final pattern = '%$escaped%';
      var sql =
          "SELECT book_id, chapter, verse, text FROM verses WHERE text LIKE ? ESCAPE '\\'";
      final args = <Object>[pattern];

      if (bookIdStart != null) {
        sql += " AND book_id >= ?";
        args.add(bookIdStart);
      }
      if (bookIdEnd != null) {
        sql += " AND book_id <= ?";
        args.add(bookIdEnd);
      }

      sql += " ORDER BY book_id, chapter, verse LIMIT ? OFFSET ?";
      args.add(limit);
      args.add(offset);

      final rows = db.select(sql, args);
      return _mapHits(rows);
    } finally {
      db.close();
    }
  }

  _ChapterReference? _resolveChapterReference(Database db, String query) {
    final match = RegExp(
      r'^(.+?)[\s.]+(\d+)\s*(?:장|chapter)?$',
      caseSensitive: false,
    ).firstMatch(query);
    if (match == null) return null;

    final requestedBook = _normalizeBookName(match.group(1)!);
    final requestedChapter = int.parse(match.group(2)!);
    if (requestedBook.isEmpty || requestedChapter < 1) return null;

    final ambiguousBookIds = _ambiguousKoreanBookAliases[requestedBook];
    if (ambiguousBookIds != null) {
      return _ChapterReference(
        bookIds: ambiguousBookIds,
        chapter: requestedChapter,
      );
    }
    final aliasedBookId = _koreanBookAliases[requestedBook];
    if (aliasedBookId != null) {
      return _ChapterReference(
        bookIds: [aliasedBookId],
        chapter: requestedChapter,
      );
    }

    final columns = db
        .select('PRAGMA table_info(books)')
        .map((row) => row['name'] as String)
        .toSet();
    const supportedNameColumns = {
      'name',
      'name_native',
      'name_en',
      'eng_name',
      'osis',
      'abbrev',
    };
    final nameColumns = columns.intersection(supportedNameColumns).toList();
    if (nameColumns.isEmpty) return null;

    final rows = db.select(
      'SELECT book_id, ${nameColumns.join(', ')} FROM books ORDER BY book_id',
    );
    final exactMatches = <int>{};
    final prefixMatches = <int>{};
    for (final row in rows) {
      final bookId = row['book_id'] as int;
      for (final column in nameColumns) {
        final value = row[column] as String?;
        if (value == null) continue;
        final normalized = _normalizeBookName(value);
        if (normalized == requestedBook) {
          exactMatches.add(bookId);
        } else if (normalized.startsWith(requestedBook)) {
          prefixMatches.add(bookId);
        }
      }
    }

    final matches = exactMatches.isNotEmpty ? exactMatches : prefixMatches;
    if (matches.length != 1) return null;
    return _ChapterReference(
      bookIds: [matches.single],
      chapter: requestedChapter,
    );
  }

  String _normalizeBookName(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[\s._-]'), '');

  List<SearchHit> _mapHits(ResultSet rows) => rows
      .map(
        (row) => SearchHit(
          bookId: (row['book_id'] as int?) ?? 0,
          chapter: (row['chapter'] as int?) ?? 0,
          verse: (row['verse'] as int?) ?? 0,
          text: (row['text'] as String?) ?? '',
        ),
      )
      .toList(growable: false);

  bool _isCjk(String s) {
    for (final r in s.runes) {
      if ((r >= 0x4E00 && r <= 0x9FFF) ||
          (r >= 0x3040 && r <= 0x30FF) ||
          (r >= 0xAC00 && r <= 0xD7AF)) {
        return true;
      }
    }
    return false;
  }
}

class _ChapterReference {
  const _ChapterReference({required this.bookIds, required this.chapter});

  final List<int> bookIds;
  final int chapter;
}

const _ambiguousKoreanBookAliases = <String, List<int>>{
  '삼': [9, 10],
};

const _koreanBookAliases = <String, int>{
  '창': 1,
  '출': 2,
  '레': 3,
  '민': 4,
  '신': 5,
  '수': 6,
  '삿': 7,
  '룻': 8,
  '삼상': 9,
  '삼하': 10,
  '왕상': 11,
  '왕하': 12,
  '대상': 13,
  '대하': 14,
  '스': 15,
  '느': 16,
  '에': 17,
  '욥': 18,
  '시': 19,
  '잠': 20,
  '전': 21,
  '아': 22,
  '사': 23,
  '렘': 24,
  '애': 25,
  '겔': 26,
  '단': 27,
  '호': 28,
  '욜': 29,
  '암': 30,
  '옵': 31,
  '욘': 32,
  '미': 33,
  '나': 34,
  '합': 35,
  '습': 36,
  '학': 37,
  '슥': 38,
  '말': 39,
  '마': 40,
  '막': 41,
  '눅': 42,
  '요': 43,
  '행': 44,
  '롬': 45,
  '고전': 46,
  '고후': 47,
  '갈': 48,
  '엡': 49,
  '빌': 50,
  '골': 51,
  '살전': 52,
  '살후': 53,
  '딤전': 54,
  '딤후': 55,
  '딛': 56,
  '몬': 57,
  '히': 58,
  '약': 59,
  '벧전': 60,
  '벧후': 61,
  '요일': 62,
  '요이': 63,
  '요삼': 64,
  '유': 65,
  '계': 66,
};
