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

  CommentaryArticle? loadCommentaryArticle({
    required String dbPath,
    required int bookId,
    required int chapter,
  }) {
    final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
    try {
      final idxRows = db.select(
        'SELECT name_en, name_native, osis FROM indexing WHERE book_id = ? LIMIT 1',
        [bookId],
      );
      final Set<String> candidates = {};
      if (idxRows.isNotEmpty) {
        final r = idxRows.first;
        final en = r['name_en'] as String?;
        final native = r['name_native'] as String?;
        final osis = r['osis'] as String?;
        if (en != null && en.isNotEmpty) candidates.add(en.toLowerCase());
        if (native != null && native.isNotEmpty) candidates.add(native.toLowerCase());
        if (osis != null && osis.isNotEmpty) candidates.add(osis.toLowerCase());
      }

      final predefined = bibleBookNames[bookId];
      if (predefined != null) {
        for (final p in predefined) {
          candidates.add(p.toLowerCase());
        }
      }

      if (candidates.isEmpty) return null;

      final artRows = db.select('SELECT article_id, title FROM articles');
      final chStr = chapter.toString();
      final bookRegexPart = candidates.map((c) => RegExp.escape(c)).join('|');
      final regex = RegExp(
        '(?:^|[^a-zA-Z0-9])(?:$bookRegexPart)(?:[^a-zA-Z0-9].*?)?\\b0*$chStr\\b',
        caseSensitive: false,
      );

      int? matchedArticleId;
      for (final row in artRows) {
        final title = (row['title'] as String?) ?? '';
        if (regex.hasMatch(title)) {
          matchedArticleId = row['article_id'] as int?;
          break;
        }
      }

      if (matchedArticleId != null) {
        final detailRows = db.select(
          'SELECT title, text FROM articles WHERE article_id = ? LIMIT 1',
          [matchedArticleId],
        );
        if (detailRows.isNotEmpty) {
          final row = detailRows.first;
          return CommentaryArticle(
            title: (row['title'] as String?) ?? '',
            text: (row['text'] as String?) ?? '',
          );
        }
      }

      return null;
    } finally {
      db.close();
    }
  }
}

class CommentaryArticle {
  const CommentaryArticle({required this.title, required this.text});

  final String title;
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

