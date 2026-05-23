import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:Love/data/import/zip_extractor.dart';
import 'package:Love/features/reader/data/reader_repository.dart';

void main() {
  group('Commentary Database Tests (Korean Crawled Databases)', () {
    const repository = ReaderRepository();
    final tempExtractDir = Directory('test/temp_extracted');

    setUpAll(() async {
      if (tempExtractDir.existsSync()) {
        tempExtractDir.deleteSync(recursive: true);
      }
      tempExtractDir.createSync(recursive: true);

      const extractor = ZipExtractor();
      await extractor.extractFile(
        targetZipPath: 'comment/com_kor_hochma.sqlite',
        destinationPath: p.join(tempExtractDir.path, 'com_kor_hochma.sqlite'),
        zipFilePath: 'assets/data.zip',
      );
      await extractor.extractFile(
        targetZipPath: 'comment/com_kor_mhw.sqlite',
        destinationPath: p.join(tempExtractDir.path, 'com_kor_mhw.sqlite'),
        zipFilePath: 'assets/data.zip',
      );
      await extractor.extractFile(
        targetZipPath: 'comment/com_kor_pys.sqlite',
        destinationPath: p.join(tempExtractDir.path, 'com_kor_pys.sqlite'),
        zipFilePath: 'assets/data.zip',
      );
    });

    tearDownAll(() {
      if (tempExtractDir.existsSync()) {
        tempExtractDir.deleteSync(recursive: true);
      }
    });

    test(
      'Loads Genesis 1 commentary from Korean Hochma commentary (uses verse fallback)',
      () {
        final dbFile = File(
          p.join(tempExtractDir.path, 'com_kor_hochma.sqlite'),
        );
        expect(dbFile.existsSync(), isTrue);

        final article = repository.loadCommentaryArticle(
          dbPath: dbFile.path,
          bookId: 1, // Genesis
          chapter: 1,
        );

        expect(article, isNotNull);
        expect(article!.title, contains('창세기'));
        expect(article.title, contains('1'));
        expect(article.text, isNotEmpty);
        expect(article.text, contains('태초에'));
      },
    );

    test('Loads Genesis 8 commentary from Matthew Henry commentary', () {
      final dbFile = File(p.join(tempExtractDir.path, 'com_kor_mhw.sqlite'));
      expect(dbFile.existsSync(), isTrue);

      final article = repository.loadCommentaryArticle(
        dbPath: dbFile.path,
        bookId: 1, // Genesis
        chapter: 8,
      );

      expect(article, isNotNull);
      expect(article!.title, contains('창세기'));
      expect(article.title, contains('8'));
      expect(article.text, isNotEmpty);
    });

    test('Loads Genesis 1 commentary from Korean Park Yun Sun commentary', () {
      final dbFile = File(p.join(tempExtractDir.path, 'com_kor_pys.sqlite'));
      expect(dbFile.existsSync(), isTrue);

      final article = repository.loadCommentaryArticle(
        dbPath: dbFile.path,
        bookId: 1, // Genesis
        chapter: 1,
      );

      expect(article, isNotNull);
      expect(article!.title, contains('창세기'));
      expect(article.title, contains('1'));
      expect(article.text, isNotEmpty);
      expect(article.text, contains('태초에'));
    });

    test('Returns null for invalid/out-of-bounds chapter', () {
      final dbFile = File(p.join(tempExtractDir.path, 'com_kor_hochma.sqlite'));
      final article = repository.loadCommentaryArticle(
        dbPath: dbFile.path,
        bookId: 1,
        chapter: 999, // Non-existent chapter
      );
      expect(article, isNull);
    });

    test('Loads commentary verses (used in UI CommentaryPane)', () {
      final dbFile = File(p.join(tempExtractDir.path, 'com_kor_mhw.sqlite'));
      final verses = repository.loadCommentaryVerses(
        dbPath: dbFile.path,
        bookId: 1,
        chapter: 8,
      );
      expect(verses, isNotEmpty);
      // Matthew Henry Gen 8:1 has text
      expect(verses.any((v) => v.verse == 1 && v.text.contains('노아')), isTrue);
    });

    test('Detects exact chapter commentary without fallback', () {
      final dbFile = File(p.join(tempExtractDir.path, 'exact_chapter.sqlite'));
      final db = sqlite3.open(dbFile.path);
      try {
        db.execute(
          'CREATE TABLE verses (book_id INTEGER, chapter INTEGER, verse INTEGER, text TEXT)',
        );
        db.execute(
          'INSERT INTO verses (book_id, chapter, verse, text) VALUES (1, 1, 1, ?)',
          ['present'],
        );
        db.execute(
          'INSERT INTO verses (book_id, chapter, verse, text) VALUES (1, 2, 1, ?)',
          ['없음'],
        );
      } finally {
        db.close();
      }

      expect(
        repository.hasCommentaryForChapter(
          dbPath: dbFile.path,
          bookId: 1,
          chapter: 1,
        ),
        isTrue,
      );
      expect(
        repository.hasCommentaryForChapter(
          dbPath: dbFile.path,
          bookId: 1,
          chapter: 2,
        ),
        isFalse,
      );
      expect(
        repository.hasCommentaryForChapter(
          dbPath: dbFile.path,
          bookId: 1,
          chapter: 3,
        ),
        isFalse,
      );
      expect(
        repository.loadCommentaryVerses(
          dbPath: dbFile.path,
          bookId: 1,
          chapter: 3,
        ),
        isNotEmpty,
      );
    });

    test('Introductions are empty for crawled Korean databases', () {
      final dbFile = File(p.join(tempExtractDir.path, 'com_kor_hochma.sqlite'));
      final intros = repository.loadCommentaryIntroductions(
        dbPath: dbFile.path,
      );
      expect(intros, isEmpty);
    });
  });
}
