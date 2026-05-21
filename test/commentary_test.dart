import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:Love/features/reader/data/reader_repository.dart';
import 'package:Love/data/import/zip_extractor.dart';

void main() {
  group('Commentary Database Tests (via ZIP Extraction)', () {
    const repository = ReaderRepository();
    const extractor = ZipExtractor();
    final tempExtractDir = Directory('test/temp_extracted');

    setUpAll(() async {
      if (tempExtractDir.existsSync()) {
        tempExtractDir.deleteSync(recursive: true);
      }
      tempExtractDir.createSync(recursive: true);

      // Extract required dbs for the tests
      await extractor.extractFile(
        targetZipPath: 'comment/com_geneva.sqlite',
        destinationPath: p.join(tempExtractDir.path, 'com_geneva.sqlite'),
        zipFilePath: 'assets/data.zip',
      );

      await extractor.extractFile(
        targetZipPath: 'comment/com_barne.sqlite',
        destinationPath: p.join(tempExtractDir.path, 'com_barne.sqlite'),
        zipFilePath: 'assets/data.zip',
      );

      await extractor.extractFile(
        targetZipPath: 'comment/com_kor_hochma.sqlite',
        destinationPath: p.join(tempExtractDir.path, 'com_kor_hochma.sqlite'),
        zipFilePath: 'assets/data.zip',
      );
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
  });
}
