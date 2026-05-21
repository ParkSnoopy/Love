import 'package:sqlite3/sqlite3.dart';

class VerseLine {
  const VerseLine({
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.text,
  });

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
        'SELECT name_native, name_en FROM books WHERE book_id = ? LIMIT 1',
        [bookId],
      );
      if (rows.isEmpty) return 'Book$bookId';
      final row = rows.first;
      final native = (row['name_native'] as String?)?.trim();
      if (native != null && native.isNotEmpty) return native;

      final en = (row['name_en'] as String?)?.trim();
      if (en != null && en.isNotEmpty) return en;

      return 'Book$bookId';
    } finally {
      db.close();
    }
  }

  int loadMaxChapter({required String dbPath, required int bookId}) {
    final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
    try {
      final rows = db.select(
        'SELECT chapter_count FROM books WHERE book_id = ? LIMIT 1',
        [bookId],
      );
      if (rows.isEmpty) return 0;
      return (rows.first['chapter_count'] as int?) ?? 0;
    } finally {
      db.close();
    }
  }

  int loadMaxBook({required String dbPath}) {
    final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
    try {
      final rows = db.select('SELECT MAX(book_id) as max_id FROM books');
      if (rows.isEmpty) return 66;
      return (rows.first['max_id'] as int?) ?? 66;
    } finally {
      db.close();
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
      db.close();
    }
  }
}
