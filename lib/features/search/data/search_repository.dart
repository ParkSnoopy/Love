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
    final minLen = _isCjk(trimmed) ? 1 : 2;
    if (trimmed.runes.length < minLen) return const [];

    final escaped = trimmed
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
    final pattern = '%$escaped%';

    final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
    try {
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
      return rows
          .map(
            (r) => SearchHit(
              bookId: (r['book_id'] as int?) ?? 0,
              chapter: (r['chapter'] as int?) ?? 0,
              verse: (r['verse'] as int?) ?? 0,
              text: (r['text'] as String?) ?? '',
            ),
          )
          .toList(growable: false);
    } finally {
      db.close();
    }
  }

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
