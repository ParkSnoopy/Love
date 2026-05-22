import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

class HistoryEntry {
  const HistoryEntry({
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.visitedAt,
  });

  final int bookId;
  final int chapter;
  final int verse;
  final int visitedAt;
}

class BookmarkEntry {
  const BookmarkEntry({
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.createdAt,
  });

  final int bookId;
  final int chapter;
  final int verse;
  final int createdAt;
}

class NoteEntry {
  const NoteEntry({
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.content,
    required this.updatedAt,
  });

  final int bookId;
  final int chapter;
  final int verse;
  final String content;
  final int updatedAt;
}

class HighlightEntry {
  const HighlightEntry({
    required this.id,
    required this.bookId,
    required this.chapter,
    required this.verseStart,
    required this.verseEnd,
    required this.color,
    required this.createdAt,
  });

  final int id;
  final int bookId;
  final int chapter;
  final int verseStart;
  final int verseEnd;
  final String color;
  final int createdAt;
}

class UserDataRepository {
  const UserDataRepository();

  static final Set<String> _initializedPaths = <String>{};

  void init(String dbPath) {
    if (_initializedPaths.contains(dbPath)) return;
    final dbFile = File(dbPath);
    final parent = dbFile.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
    final db = sqlite3.open(dbPath);
    try {
      db.execute('PRAGMA busy_timeout = 3000;');
      db.execute('''
CREATE TABLE IF NOT EXISTS bookmarks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL,
  chapter INTEGER NOT NULL,
  verse INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  UNIQUE(book_id, chapter, verse)
);
''');
      db.execute('''
CREATE TABLE IF NOT EXISTS highlights (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL,
  chapter INTEGER NOT NULL,
  verse_start INTEGER NOT NULL,
  verse_end INTEGER NOT NULL,
  color TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
''');
      db.execute('''
CREATE TABLE IF NOT EXISTS notes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL,
  chapter INTEGER NOT NULL,
  verse INTEGER NOT NULL,
  content TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  UNIQUE(book_id, chapter, verse)
);
''');
      db.execute('''
CREATE TABLE IF NOT EXISTS history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL,
  chapter INTEGER NOT NULL,
  verse INTEGER NOT NULL,
  visited_at INTEGER NOT NULL
);
''');
      _initializedPaths.add(dbPath);
    } on SqliteException catch (e) {
      if (!e.toString().contains('database is locked')) rethrow;
    } finally {
      db.close();
    }
  }

  void addHistory({
    required String dbPath,
    required int bookId,
    required int chapter,
    required int verse,
    required int visitedAt,
  }) {
    final db = sqlite3.open(dbPath);
    try {
      db.execute(
        'INSERT INTO history (book_id, chapter, verse, visited_at) VALUES (?, ?, ?, ?)',
        [bookId, chapter, verse, visitedAt],
      );
      db.execute('''
DELETE FROM history
WHERE id IN (
  SELECT id FROM history
  ORDER BY visited_at DESC, id DESC
  LIMIT -1 OFFSET 50
)
''');
    } finally {
      db.close();
    }
  }

  void addBookmark({
    required String dbPath,
    required int bookId,
    required int chapter,
    required int verse,
    required int createdAt,
  }) {
    final db = sqlite3.open(dbPath);
    try {
      db.execute(
        'INSERT OR REPLACE INTO bookmarks (book_id, chapter, verse, created_at) VALUES (?, ?, ?, ?)',
        [bookId, chapter, verse, createdAt],
      );
    } finally {
      db.close();
    }
  }

  List<BookmarkEntry> loadBookmarks({required String dbPath}) {
    final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
    try {
      final rows = db.select(
        'SELECT book_id, chapter, verse, created_at FROM bookmarks ORDER BY created_at DESC, id DESC',
      );
      return rows
          .map(
            (r) => BookmarkEntry(
              bookId: (r['book_id'] as int?) ?? 0,
              chapter: (r['chapter'] as int?) ?? 0,
              verse: (r['verse'] as int?) ?? 0,
              createdAt: (r['created_at'] as int?) ?? 0,
            ),
          )
          .toList(growable: false);
    } finally {
      db.close();
    }
  }

  void addHighlight({
    required String dbPath,
    required int bookId,
    required int chapter,
    required int verseStart,
    required int verseEnd,
    required String color,
    required int createdAt,
  }) {
    final db = sqlite3.open(dbPath);
    try {
      // Find overlapping highlights
      final rows = db.select(
        'SELECT id, verse_start, verse_end, color, created_at FROM highlights '
        'WHERE book_id = ? AND chapter = ? AND verse_start <= ? AND ? <= verse_end',
        [bookId, chapter, verseEnd, verseStart],
      );

      final toInsert = <Map<String, dynamic>>[];

      for (final r in rows) {
        final oldId = r['id'] as int;
        final oldStart = r['verse_start'] as int;
        final oldEnd = r['verse_end'] as int;
        final oldColor = r['color'] as String;
        final oldCreatedAt = r['created_at'] as int;

        // Delete the old highlight
        db.execute('DELETE FROM highlights WHERE id = ?', [oldId]);

        // Keep left leftover
        if (oldStart < verseStart) {
          toInsert.add({
            'start': oldStart,
            'end': verseStart - 1,
            'color': oldColor,
            'createdAt': oldCreatedAt,
          });
        }

        // Keep right leftover
        if (oldEnd > verseEnd) {
          toInsert.add({
            'start': verseEnd + 1,
            'end': oldEnd,
            'color': oldColor,
            'createdAt': oldCreatedAt,
          });
        }
      }

      // Insert leftovers
      for (final item in toInsert) {
        db.execute(
          'INSERT INTO highlights (book_id, chapter, verse_start, verse_end, color, created_at) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          [
            bookId,
            chapter,
            item['start'],
            item['end'],
            item['color'],
            item['createdAt'],
          ],
        );
      }

      // Insert new highlight
      db.execute(
        'INSERT INTO highlights (book_id, chapter, verse_start, verse_end, color, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        [bookId, chapter, verseStart, verseEnd, color, createdAt],
      );
    } finally {
      db.close();
    }
  }

  void removeHighlightRange({
    required String dbPath,
    required int bookId,
    required int chapter,
    required int verseStart,
    required int verseEnd,
  }) {
    final db = sqlite3.open(dbPath);
    try {
      // Find overlapping highlights
      final rows = db.select(
        'SELECT id, verse_start, verse_end, color, created_at FROM highlights '
        'WHERE book_id = ? AND chapter = ? AND verse_start <= ? AND ? <= verse_end',
        [bookId, chapter, verseEnd, verseStart],
      );

      final toInsert = <Map<String, dynamic>>[];

      for (final r in rows) {
        final oldId = r['id'] as int;
        final oldStart = r['verse_start'] as int;
        final oldEnd = r['verse_end'] as int;
        final oldColor = r['color'] as String;
        final oldCreatedAt = r['created_at'] as int;

        // Delete the old highlight
        db.execute('DELETE FROM highlights WHERE id = ?', [oldId]);

        // Keep left leftover
        if (oldStart < verseStart) {
          toInsert.add({
            'start': oldStart,
            'end': verseStart - 1,
            'color': oldColor,
            'createdAt': oldCreatedAt,
          });
        }

        // Keep right leftover
        if (oldEnd > verseEnd) {
          toInsert.add({
            'start': verseEnd + 1,
            'end': oldEnd,
            'color': oldColor,
            'createdAt': oldCreatedAt,
          });
        }
      }

      // Insert leftovers
      for (final item in toInsert) {
        db.execute(
          'INSERT INTO highlights (book_id, chapter, verse_start, verse_end, color, created_at) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          [
            bookId,
            chapter,
            item['start'],
            item['end'],
            item['color'],
            item['createdAt'],
          ],
        );
      }
    } finally {
      db.close();
    }
  }

  void upsertNote({
    required String dbPath,
    required int bookId,
    required int chapter,
    required int verse,
    required String content,
    required int now,
  }) {
    final db = sqlite3.open(dbPath);
    try {
      db.execute(
        'INSERT INTO notes (book_id, chapter, verse, content, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?) '
        'ON CONFLICT(book_id, chapter, verse) DO UPDATE SET content = excluded.content, updated_at = excluded.updated_at',
        [bookId, chapter, verse, content, now, now],
      );
    } finally {
      db.close();
    }
  }

  void deleteNote({
    required String dbPath,
    required int bookId,
    required int chapter,
    required int verse,
  }) {
    final db = sqlite3.open(dbPath);
    try {
      db.execute(
        'DELETE FROM notes WHERE book_id = ? AND chapter = ? AND verse = ?',
        [bookId, chapter, verse],
      );
    } finally {
      db.close();
    }
  }

  NoteEntry? loadNote({
    required String dbPath,
    required int bookId,
    required int chapter,
    required int verse,
  }) {
    final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
    try {
      final rows = db.select(
        'SELECT book_id, chapter, verse, content, updated_at FROM notes WHERE book_id=? AND chapter=? AND verse=? LIMIT 1',
        [bookId, chapter, verse],
      );
      if (rows.isEmpty) return null;
      final r = rows.first;
      return NoteEntry(
        bookId: (r['book_id'] as int?) ?? 0,
        chapter: (r['chapter'] as int?) ?? 0,
        verse: (r['verse'] as int?) ?? 0,
        content: (r['content'] as String?) ?? '',
        updatedAt: (r['updated_at'] as int?) ?? 0,
      );
    } finally {
      db.close();
    }
  }

  List<HistoryEntry> loadRecentHistory({
    required String dbPath,
    int limit = 50,
  }) {
    final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
    try {
      final rows = db.select(
        'SELECT book_id, chapter, verse, visited_at FROM history ORDER BY visited_at DESC, id DESC LIMIT ?',
        [limit],
      );
      return rows
          .map(
            (r) => HistoryEntry(
              bookId: (r['book_id'] as int?) ?? 0,
              chapter: (r['chapter'] as int?) ?? 0,
              verse: (r['verse'] as int?) ?? 0,
              visitedAt: (r['visited_at'] as int?) ?? 0,
            ),
          )
          .toList(growable: false);
    } finally {
      db.close();
    }
  }

  List<HighlightEntry> loadHighlights({required String dbPath}) {
    final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
    try {
      final rows = db.select(
        'SELECT id, book_id, chapter, verse_start, verse_end, color, created_at FROM highlights ORDER BY created_at DESC, id DESC',
      );
      return rows
          .map(
            (r) => HighlightEntry(
              id: (r['id'] as int?) ?? 0,
              bookId: (r['book_id'] as int?) ?? 0,
              chapter: (r['chapter'] as int?) ?? 0,
              verseStart: (r['verse_start'] as int?) ?? 0,
              verseEnd: (r['verse_end'] as int?) ?? 0,
              color: (r['color'] as String?) ?? 'yellow',
              createdAt: (r['created_at'] as int?) ?? 0,
            ),
          )
          .toList(growable: false);
    } finally {
      db.close();
    }
  }

  void deleteHighlight({required String dbPath, required int id}) {
    final db = sqlite3.open(dbPath);
    try {
      db.execute('DELETE FROM highlights WHERE id = ?', [id]);
    } finally {
      db.close();
    }
  }

  List<NoteEntry> loadAllNotes({required String dbPath}) {
    final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
    try {
      final rows = db.select(
        'SELECT book_id, chapter, verse, content, updated_at FROM notes ORDER BY updated_at DESC, id DESC',
      );
      return rows
          .map(
            (r) => NoteEntry(
              bookId: (r['book_id'] as int?) ?? 0,
              chapter: (r['chapter'] as int?) ?? 0,
              verse: (r['verse'] as int?) ?? 0,
              content: (r['content'] as String?) ?? '',
              updatedAt: (r['updated_at'] as int?) ?? 0,
            ),
          )
          .toList(growable: false);
    } finally {
      db.close();
    }
  }

  void deleteBookmark({
    required String dbPath,
    required int bookId,
    required int chapter,
    required int verse,
  }) {
    final db = sqlite3.open(dbPath);
    try {
      db.execute(
        'DELETE FROM bookmarks WHERE book_id = ? AND chapter = ? AND verse = ?',
        [bookId, chapter, verse],
      );
    } finally {
      db.close();
    }
  }
}
