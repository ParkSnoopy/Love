import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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

      // Copy the crawled Korean commentary databases
      final hochmaSrc = File('assets/data/comment/com_kor_hochma.sqlite');
      if (hochmaSrc.existsSync()) {
        hochmaSrc.copySync(p.join(tempExtractDir.path, 'com_kor_hochma.sqlite'));
      }

      final mhwSrc = File('assets/data/comment/com_kor_mhw.sqlite');
      if (mhwSrc.existsSync()) {
        mhwSrc.copySync(p.join(tempExtractDir.path, 'com_kor_mhw.sqlite'));
      }

      final pysSrc = File('assets/data/comment/com_kor_pys.sqlite');
      if (pysSrc.existsSync()) {
        pysSrc.copySync(p.join(tempExtractDir.path, 'com_kor_pys.sqlite'));
      }
    });

    tearDownAll(() {
      if (tempExtractDir.existsSync()) {
        tempExtractDir.deleteSync(recursive: true);
      }
    });

    test('Loads Genesis 1 commentary from Korean Hochma commentary (uses verse fallback)', () {
      final dbFile = File(p.join(tempExtractDir.path, 'com_kor_hochma.sqlite'));
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

    test('Introductions are empty for crawled Korean databases', () {
      final dbFile = File(p.join(tempExtractDir.path, 'com_kor_hochma.sqlite'));
      final intros = repository.loadCommentaryIntroductions(dbPath: dbFile.path);
      expect(intros, isEmpty);
    });
  });
}
