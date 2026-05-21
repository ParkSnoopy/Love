import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:Love/features/reader/data/reader_repository.dart';

void main() {
  group('Commentary Database Tests (via ZIP Extraction)', () {
    const repository = ReaderRepository();
    final tempExtractDir = Directory('test/temp_extracted');

    setUpAll(() async {
      if (tempExtractDir.existsSync()) {
        tempExtractDir.deleteSync(recursive: true);
      }
      tempExtractDir.createSync(recursive: true);

      // Copy the converted/migrated sqlite files from assets/data/comment/ directly
      final genevaSrc = File('assets/data/comment/com_geneva.sqlite');
      if (genevaSrc.existsSync()) {
        genevaSrc.copySync(p.join(tempExtractDir.path, 'com_geneva.sqlite'));
      }

      final barneSrc = File('assets/data/comment/com_barne.sqlite');
      if (barneSrc.existsSync()) {
        barneSrc.copySync(p.join(tempExtractDir.path, 'com_barne.sqlite'));
      }

      final hochmaSrc = File('assets/data/comment/com_kor_hochma.sqlite');
      if (hochmaSrc.existsSync()) {
        hochmaSrc.copySync(p.join(tempExtractDir.path, 'com_kor_hochma.sqlite'));
      }
    });

    tearDownAll(() {
      if (tempExtractDir.existsSync()) {
        tempExtractDir.deleteSync(recursive: true);
      }
    });

    test('Loads Genesis 1 commentary from Geneva Bible commentary', () {
      final dbFile = File(p.join(tempExtractDir.path, 'com_geneva.sqlite'));
      expect(dbFile.existsSync(), isTrue);

      final article = repository.loadCommentaryArticle(
        dbPath: dbFile.path,
        bookId: 1, // Genesis
        chapter: 1,
      );

      expect(article, isNotNull);
      expect(article!.title, contains('Genesis'));
      expect(article.title, contains('1'));
      expect(article.text, isNotEmpty);
    });

    test('Loads Matthew 5 commentary from Barnes commentary', () {
      final dbFile = File(p.join(tempExtractDir.path, 'com_barne.sqlite'));
      expect(dbFile.existsSync(), isTrue);

      final article = repository.loadCommentaryArticle(
        dbPath: dbFile.path,
        bookId: 40, // Matthew
        chapter: 5,
      );

      expect(article, isNotNull);
      expect(article!.title, contains('Matthew'));
      expect(article.title, contains('5'));
      expect(article.text, isNotEmpty);
    });

    test('Loads Genesis 1 commentary from Korean Hochma commentary', () {
      final dbFile = File(p.join(tempExtractDir.path, 'com_kor_hochma.sqlite'));
      expect(dbFile.existsSync(), isTrue);

      final article = repository.loadCommentaryArticle(
        dbPath: dbFile.path,
        bookId: 1, // Genesis / 창세기
        chapter: 1,
      );

      expect(article, isNotNull);
      expect(article!.title, contains('창세기'));
      expect(article.title, contains('1'));
      expect(article.text, isNotEmpty);
    });

    test('Returns null for invalid/out-of-bounds chapter', () {
      final dbFile = File(p.join(tempExtractDir.path, 'com_geneva.sqlite'));
      final article = repository.loadCommentaryArticle(
        dbPath: dbFile.path,
        bookId: 1,
        chapter: 999, // Non-existent chapter
      );
      expect(article, isNull);
    });

    test('Loads commentary introductions and prefaces', () {
      final dbFile = File(p.join(tempExtractDir.path, 'com_geneva.sqlite'));
      expect(dbFile.existsSync(), isTrue);

      final intros = repository.loadCommentaryIntroductions(dbPath: dbFile.path);
      expect(intros, isEmpty);
    });

    test('Loads Korean commentary introductions (prefaces) correctly', () {
      final dbFile = File(p.join(tempExtractDir.path, 'com_kor_hochma.sqlite'));
      expect(dbFile.existsSync(), isTrue);

      final intros = repository.loadCommentaryIntroductions(dbPath: dbFile.path);
      expect(intros, isNotEmpty);
      expect(intros.first.bookId, equals(0));
      expect(intros.first.title, isNotEmpty);
      expect(intros.first.text, isNotEmpty);
    });

    test('Loads Barnes commentary book introductions', () {
      final dbFile = File(p.join(tempExtractDir.path, 'com_barne.sqlite'));
      expect(dbFile.existsSync(), isTrue);

      final intros = repository.loadCommentaryIntroductions(dbPath: dbFile.path);
      expect(intros, isNotEmpty);

      final bookIntros = intros.where((i) => i.bookId > 0).toList();
      expect(bookIntros, isNotEmpty);
      expect(bookIntros.first.title, isNotEmpty);
      expect(bookIntros.first.text, isNotEmpty);
    });
  });
}
