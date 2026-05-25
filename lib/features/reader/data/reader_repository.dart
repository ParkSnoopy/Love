import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import '../../../data/import/zip_extractor.dart';
import '../../../data/storage/app_storage.dart';
import '../../../data/storage/db_asset_paths.dart';

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

class CommentaryIntroduction {
  const CommentaryIntroduction({
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.title,
    required this.text,
  });

  final int bookId;
  final int chapter;
  final int verse;
  final String title;
  final String text;
}

class ReaderRepository {
  const ReaderRepository();

  String loadBookName({required String dbPath, required int bookId}) {
    final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
    try {
      final columns = db
          .select('PRAGMA table_info(books)')
          .map((row) => row['name'] as String)
          .toSet();

      final nameNativeCol = columns.contains('name_native')
          ? 'name_native'
          : 'name';
      final nameEnCol = columns.contains('name_en') ? 'name_en' : 'eng_name';

      final rows = db.select(
        'SELECT $nameNativeCol, $nameEnCol FROM books WHERE book_id = ? LIMIT 1',
        [bookId],
      );
      if (rows.isEmpty) return 'Book$bookId';
      final row = rows.first;
      final native = (row[nameNativeCol] as String?)?.trim();
      if (native != null && native.isNotEmpty) return native;

      final en = (row[nameEnCol] as String?)?.trim();
      if (en != null && en.isNotEmpty) return en;

      return 'Book$bookId';
    } finally {
      db.close();
    }
  }

  int loadMaxChapter({required String dbPath, required int bookId}) {
    final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
    try {
      final columns = db
          .select('PRAGMA table_info(books)')
          .map((row) => row['name'] as String)
          .toSet();

      final chapterCol = columns.contains('chapter_count')
          ? 'chapter_count'
          : 'chapters';

      final rows = db.select(
        'SELECT $chapterCol FROM books WHERE book_id = ? LIMIT 1',
        [bookId],
      );
      if (rows.isEmpty) return 0;
      return (rows.first[chapterCol] as int?) ?? 0;
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

  CommentaryArticle? loadCommentaryArticle({
    required String dbPath,
    required int bookId,
    required int chapter,
  }) {
    final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
    try {
      var rows = db.select(
        'SELECT text FROM verses WHERE book_id = ? AND chapter = ? AND verse = 0 LIMIT 1',
        [bookId, chapter],
      );
      if (rows.isEmpty) {
        rows = db.select(
          'SELECT text FROM verses WHERE book_id = ? AND chapter = ? ORDER BY verse ASC LIMIT 1',
          [bookId, chapter],
        );
      }
      if (rows.isEmpty) return null;
      final text = (rows.first['text'] as String?) ?? '';

      var bookName = loadBookName(dbPath: dbPath, bookId: bookId);
      if (dbPath.contains('com_kor_') &&
          RegExp(r'^[a-zA-Z\s]+$').hasMatch(bookName)) {
        final names = bibleBookNames[bookId];
        if (names != null && names.isNotEmpty) {
          bookName = names.last;
        }
      }
      final title = '$bookName $chapter장';

      return CommentaryArticle(title: title, text: text);
    } finally {
      db.close();
    }
  }

  bool hasCommentaryForChapter({
    required String dbPath,
    required int bookId,
    required int chapter,
  }) {
    final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
    try {
      final rows = db.select(
        'SELECT text FROM verses WHERE book_id = ? AND chapter = ?',
        [bookId, chapter],
      );
      return rows.any(
        (row) => _hasCommentaryText((row['text'] as String?) ?? ''),
      );
    } finally {
      db.close();
    }
  }

  bool _hasCommentaryText(String text) {
    final trimmed = text.trim();
    return trimmed.isNotEmpty && trimmed != '없음' && trimmed != '없음.';
  }

  List<CommentaryVerse> loadCommentaryVerses({
    required String dbPath,
    required int bookId,
    required int chapter,
  }) {
    final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
    try {
      int checkChapter = chapter;
      while (checkChapter >= 1) {
        final rows = db.select(
          'SELECT verse, text FROM verses WHERE book_id = ? AND chapter = ? ORDER BY verse ASC',
          [bookId, checkChapter],
        );
        final list = rows
            .map(
              (r) => CommentaryVerse(
                verse: (r['verse'] as int?) ?? 0,
                text: (r['text'] as String?) ?? '',
              ),
            )
            .toList();

        final filtered = list
            .where((v) => _hasCommentaryText(v.text))
            .toList(growable: false);

        if (filtered.isNotEmpty) {
          return filtered;
        }
        checkChapter--;
      }
      return const <CommentaryVerse>[];
    } finally {
      db.close();
    }
  }

  String loadVerseText({
    required String dbPath,
    required int bookId,
    required int chapter,
    required int verse,
  }) {
    final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
    try {
      final rows = db.select(
        'SELECT text FROM verses WHERE book_id = ? AND chapter = ? AND verse = ? LIMIT 1',
        [bookId, chapter, verse],
      );
      if (rows.isEmpty) return '';
      return (rows.first['text'] as String?) ?? '';
    } finally {
      db.close();
    }
  }

  String loadVersesTextRange({
    required String dbPath,
    required int bookId,
    required int chapter,
    required int verseStart,
    required int verseEnd,
  }) {
    final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
    try {
      final rows = db.select(
        'SELECT text FROM verses WHERE book_id = ? AND chapter = ? AND verse >= ? AND verse <= ? ORDER BY verse ASC',
        [bookId, chapter, verseStart, verseEnd],
      );
      return rows.map((r) => (r['text'] as String?) ?? '').join(' ');
    } finally {
      db.close();
    }
  }

  String _extractTitle(String text, String defaultTitle) {
    if (text.startsWith('#')) {
      final firstLine = text.split('\n').first;
      return firstLine.replaceAll(RegExp(r'^#+\s*'), '').trim();
    }
    return defaultTitle;
  }

  List<CommentaryIntroduction> loadCommentaryIntroductions({
    required String dbPath,
  }) {
    final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
    try {
      // 1. General prefaces (book_id = 0, chapter = 0, verse > 0)
      final generalRows = db.select(
        'SELECT book_id, chapter, verse, text FROM verses WHERE book_id = 0 AND chapter = 0 AND verse > 0 ORDER BY verse ASC',
      );

      // 2. Book introductions (book_id > 0, chapter = 0, verse = 0)
      final bookRows = db.select(
        'SELECT book_id, chapter, verse, text FROM verses WHERE book_id > 0 AND chapter = 0 AND verse = 0 ORDER BY book_id ASC',
      );

      final result = <CommentaryIntroduction>[];

      for (final r in generalRows) {
        final bId = (r['book_id'] as int?) ?? 0;
        final ch = (r['chapter'] as int?) ?? 0;
        final v = (r['verse'] as int?) ?? 0;
        final text = (r['text'] as String?) ?? '';
        final defaultTitle = '일반 서론 $v';
        result.add(
          CommentaryIntroduction(
            bookId: bId,
            chapter: ch,
            verse: v,
            title: _extractTitle(text, defaultTitle),
            text: text,
          ),
        );
      }

      for (final r in bookRows) {
        final bId = (r['book_id'] as int?) ?? 0;
        final ch = (r['chapter'] as int?) ?? 0;
        final v = (r['verse'] as int?) ?? 0;
        final text = (r['text'] as String?) ?? '';
        var bookName = loadBookName(dbPath: dbPath, bookId: bId);
        if (dbPath.contains('com_kor_') &&
            RegExp(r'^[a-zA-Z\s]+$').hasMatch(bookName)) {
          final names = bibleBookNames[bId];
          if (names != null && names.isNotEmpty) {
            bookName = names.last;
          }
        }
        final defaultTitle = '$bookName 소개';
        result.add(
          CommentaryIntroduction(
            bookId: bId,
            chapter: ch,
            verse: v,
            title: _extractTitle(text, defaultTitle),
            text: text,
          ),
        );
      }

      return result;
    } finally {
      db.close();
    }
  }

  bool _isDatabaseValid(String path) {
    try {
      final db = sqlite3.open(path, mode: OpenMode.readOnly);
      try {
        final rows = db.select(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='verses'",
        );
        return rows.isNotEmpty;
      } finally {
        db.close();
      }
    } catch (_) {
      return false;
    }
  }

  Future<String?> resolveDbPath(
    String manifestFile, {
    String type = 'bible',
  }) async {
    // 1. Try local file (for development/desktop)
    final localCandidates = localDbCandidates(
      manifestFile: manifestFile,
      type: type,
    );
    for (final path in localCandidates) {
      if (File(path).existsSync()) return path;
    }

    // 2. Try app data directory
    try {
      final appDataDir = await getAppDataDirectory();
      final targetPath = appDbPath(
        appDataPath: appDataDir.path,
        manifestFile: manifestFile,
        type: type,
      );
      final targetFile = File(targetPath);

      if (targetFile.existsSync()) {
        if (_isDatabaseValid(targetPath)) {
          return targetPath;
        } else {
          try {
            targetFile.deleteSync();
          } catch (_) {}
        }
      }

      // 3. Extract from assets/data.zip to app data directory
      const extractor = ZipExtractor();
      await extractor.extractFile(
        targetZipPath: dbZipPath(manifestFile: manifestFile, type: type),
        destinationPath: targetPath,
      );
      return targetPath;
    } catch (_) {
      return null;
    }
  }
}

class CommentaryArticle {
  const CommentaryArticle({required this.title, required this.text});

  final String title;
  final String text;
}

class CommentaryVerse {
  const CommentaryVerse({required this.verse, required this.text});

  final int verse;
  final String text;
}

const bibleBookNames = {
  1: ['Genesis', 'Gen', '창세기'],
  2: ['Exodus', 'Exod', '출애굽기'],
  3: ['Leviticus', 'Lev', '레위기'],
  4: ['Numbers', 'Num', '민수기'],
  5: ['Deuteronomy', 'Deut', '신명기'],
  6: ['Joshua', 'Josh', '여호수아'],
  7: ['Judges', 'Judg', '사사기'],
  8: ['Ruth', '룻기'],
  9: ['1 Samuel', '1Sam', '사무엘상'],
  10: ['2 Samuel', '2Sam', '사무엘하'],
  11: ['1 Kings', '1Kgs', '열왕기상'],
  12: ['2 Kings', '2Kgs', '열왕기하'],
  13: ['1 Chronicles', '1Chr', '역대기상'],
  14: ['2 Chronicles', '2Chr', '역대기하'],
  15: ['Ezra', '에스라'],
  16: ['Nehemiah', 'Neh', '느헤미야'],
  17: ['Esther', 'Esth', '에스더'],
  18: ['Job', '욥기'],
  19: ['Psalms', 'Ps', '시편'],
  20: ['Proverbs', 'Prov', '잠언'],
  21: ['Ecclesiastes', 'Eccl', '전도서'],
  22: ['Song of Solomon', 'Song', '아가'],
  23: ['Isaiah', 'Isa', '이사야'],
  24: ['Jeremiah', 'Jer', '예레미야'],
  25: ['Lamentations', 'Lam', '예레미야애가'],
  26: ['Ezekiel', 'Ezek', '에스겔'],
  27: ['Daniel', 'Dan', '다니엘'],
  28: ['Hosea', 'Hos', '호세아'],
  29: ['Joel', '요엘'],
  30: ['Amos', '아모스'],
  31: ['Obadiah', 'Obad', '오바댜'],
  32: ['Jonah', '요나'],
  33: ['Micah', 'Mic', '미가'],
  34: ['Nahum', 'Nah', '나훔'],
  35: ['Habakkuk', 'Hab', '하박국'],
  36: ['Zephaniah', 'Zeph', '스바냐'],
  37: ['Haggai', '학개'],
  38: ['Zechariah', 'Zech', '스가랴'],
  39: ['Malachi', 'Mal', '말라기'],
  40: ['Matthew', 'Matt', '마태복음'],
  41: ['Mark', '마가복음'],
  42: ['Luke', '누가복음'],
  43: ['John', '요한복음'],
  44: ['Acts', '사도행전'],
  45: ['Romans', 'Rom', '로마서'],
  46: ['1 Corinthians', '1Cor', '고린도전서'],
  47: ['2 Corinthians', '2Cor', '고린도후서'],
  48: ['Galatians', 'Gal', '갈라디아서'],
  49: ['Ephesians', 'Eph', '에베소서'],
  50: ['Philippians', 'Phil', '빌립보서'],
  51: ['Colossians', 'Col', '골로새서'],
  52: ['1 Thessalonians', '1Thess', '데살로니가전서'],
  53: ['2 Thessalonians', '2Thess', '데살로니가후서'],
  54: ['1 Timothy', '1Tim', '디모데전서'],
  55: ['2 Timothy', '2Tim', '디모데후서'],
  56: ['Titus', '디도서'],
  57: ['Philemon', 'Philem', '빌레몬서'],
  58: ['Hebrews', 'Heb', '히브리서'],
  59: ['James', 'Jas', '야고보서'],
  60: ['1 Peter', '1Pet', '베드로전서'],
  61: ['2 Peter', '2Pet', '베드로후서'],
  62: ['1 John', '1John', '요한일서'],
  63: ['2 John', '2John', '요한이서'],
  64: ['3 John', '3John', '요한삼서'],
  65: ['Jude', '유다서'],
  66: ['Revelation', 'Rev', '요한계시록'],
};
