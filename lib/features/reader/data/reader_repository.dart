import 'package:sqlite3/sqlite3.dart';

class VerseLine {
  const VerseLine({required this.bookId, required this.chapter, required this.verse, required this.text});

  final int bookId;
  final int chapter;
  final int verse;
  final String text;
}

class ReaderRepository {
  const ReaderRepository();

  String loadBookName({required String dbPath, required int bookId}) {
    final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
    try {
      final rows = db.select(
        'SELECT name_en FROM books WHERE book_id = ? LIMIT 1',
        [bookId],
      );
      if (rows.isEmpty) return 'Book$bookId';
      return (rows.first['name_en'] as String?)?.trim().isNotEmpty == true
          ? (rows.first['name_en'] as String)
          : 'Book$bookId';
    } finally {
      db.dispose();
    }
  }

  List<VerseLine> loadChapter({
    required String dbPath,
    required int bookId,
    required int chapter,
  }) {
    final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
    try {
      final rows = db.select(
        'SELECT book_id, chapter, verse, text FROM verses WHERE book_id = ? AND chapter = ? ORDER BY verse ASC',
        [bookId, chapter],
      );
      return rows
          .map(
            (r) => VerseLine(
              bookId: (r['book_id'] as int?) ?? 0,
              chapter: (r['chapter'] as int?) ?? 0,
              verse: (r['verse'] as int?) ?? 0,
              text: (r['text'] as String?) ?? '',
            ),
          )
          .toList(growable: false);
    } finally {
      db.dispose();
    }
  }
}
