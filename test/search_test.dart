import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:Love/data/import/zip_extractor.dart';
import 'package:Love/features/search/data/search_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SearchRepository Range Tests', () {
    final tempExtractDir = Directory('test/temp_extracted_search');
    late String bibleDbPath;
    const repo = SearchRepository();

    setUpAll(() async {
      if (tempExtractDir.existsSync()) {
        tempExtractDir.deleteSync(recursive: true);
      }
      tempExtractDir.createSync(recursive: true);

      bibleDbPath = p.join(tempExtractDir.path, 'eng_engniv.sqlite');
      const extractor = ZipExtractor();
      await extractor.extractFile(
        targetZipPath: 'data/bible/nocr/eng_engniv.sqlite',
        destinationPath: bibleDbPath,
        zipFilePath: 'assets/data.zip',
      );
    });

    tearDownAll(() {
      if (tempExtractDir.existsSync()) {
        tempExtractDir.deleteSync(recursive: true);
      }
    });

    test('search returns all hits when no range is specified', () {
      final hits = repo.searchLike(
        dbPath: bibleDbPath,
        query: 'beginning',
        limit: 50,
        offset: 0,
      );

      expect(hits.isNotEmpty, isTrue);
      // 'beginning' is found in OT (Genesis 1:1) and NT (John 1:1, etc.)
      final hasOt = hits.any((h) => h.bookId <= 39);
      final hasNt = hits.any((h) => h.bookId >= 40);
      expect(hasOt, isTrue);
      expect(hasNt, isTrue);
    });

    test('search filters only OT hits when book range is set for OT', () {
      final hits = repo.searchLike(
        dbPath: bibleDbPath,
        query: 'beginning',
        limit: 50,
        offset: 0,
        bookIdStart: 1,
        bookIdEnd: 39,
      );

      expect(hits.isNotEmpty, isTrue);
      final allOt = hits.every((h) => h.bookId >= 1 && h.bookId <= 39);
      expect(allOt, isTrue);
    });

    test('search filters only NT hits when book range is set for NT', () {
      final hits = repo.searchLike(
        dbPath: bibleDbPath,
        query: 'beginning',
        limit: 50,
        offset: 0,
        bookIdStart: 40,
        bookIdEnd: 66,
      );

      expect(hits.isNotEmpty, isTrue);
      final allNt = hits.every((h) => h.bookId >= 40 && h.bookId <= 66);
      expect(allNt, isTrue);
    });

    test('SearchHit supports bibleName parameter and constructor', () {
      const hit = SearchHit(
        bookId: 1,
        chapter: 1,
        verse: 1,
        text: 'In the beginning',
        bibleName: 'NIV 1984',
      );

      expect(hit.bookId, equals(1));
      expect(hit.chapter, equals(1));
      expect(hit.verse, equals(1));
      expect(hit.text, equals('In the beginning'));
      expect(hit.bibleName, equals('NIV 1984'));
    });
  });
}
