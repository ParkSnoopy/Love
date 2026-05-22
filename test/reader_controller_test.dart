import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:Love/app/app_preferences.dart';
import 'package:Love/data/import/zip_extractor.dart';
import 'package:Love/data/storage/db_path_provider.dart';
import 'package:Love/features/reader/providers/reader_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReaderRefController Tests', () {
    final tempExtractDir = Directory('test/temp_extracted_reader');
    late String bibleDbPath;

    setUpAll(() async {
      if (tempExtractDir.existsSync()) {
        tempExtractDir.deleteSync(recursive: true);
      }
      tempExtractDir.createSync(recursive: true);

      bibleDbPath = p.join(tempExtractDir.path, 'eng_engniv.sqlite');
      const extractor = ZipExtractor();
      await extractor.extractFile(
        targetZipPath: 'nocr/eng_engniv.sqlite',
        destinationPath: bibleDbPath,
        zipFilePath: 'assets/data.zip',
      );
    });

    tearDownAll(() {
      if (tempExtractDir.existsSync()) {
        tempExtractDir.deleteSync(recursive: true);
      }
    });

    setUp(() {
      AppPreferences.useMemoryStoreForTesting();
    });

    tearDown(() {
      AppPreferences.clearMemoryStoreForTesting();
    });

    test(
      'initializes with default values if no saved preferences exist',
      () async {
        final container = ProviderContainer(
          overrides: [
            activeDbPathProvider.overrideWith(
              (ref) => Future.value(bibleDbPath),
            ),
          ],
        );
        addTearDown(container.dispose);

        final state = await container.read(readerRefProvider.future);
        expect(state.bookId, equals(1));
        expect(state.chapter, equals(1));
      },
    );

    test('loads saved reader position from app preferences', () async {
      AppPreferences.useMemoryStoreForTesting({
        'reader_book_id': 40, // Matthew
        'reader_chapter': 5,
      });

      final container = ProviderContainer(
        overrides: [
          activeDbPathProvider.overrideWith((ref) => Future.value(bibleDbPath)),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(readerRefProvider.future);
      expect(state.bookId, equals(40));
      expect(state.chapter, equals(5));
    });

    test('saves reader position to app preferences on jumpTo', () async {
      final container = ProviderContainer(
        overrides: [
          activeDbPathProvider.overrideWith((ref) => Future.value(bibleDbPath)),
        ],
      );
      addTearDown(container.dispose);

      // Wait for initialization
      await container.read(readerRefProvider.future);

      final controller = container.read(readerRefProvider.notifier);
      await controller.jumpTo(bookId: 19, chapter: 23); // Psalms 23

      final state = container.read(readerRefProvider).value!;
      expect(state.bookId, equals(19));
      expect(state.chapter, equals(23));

      final prefs = await AppPreferences.getInstance();
      expect(prefs.getInt('reader_book_id'), equals(19));
      expect(prefs.getInt('reader_chapter'), equals(23));
    });

    test('clamps invalid out-of-bound book and chapter to limits', () async {
      // 99 is invalid book id for Bible (max is 66)
      AppPreferences.useMemoryStoreForTesting({
        'reader_book_id': 99,
        'reader_chapter': 1,
      });

      final container = ProviderContainer(
        overrides: [
          activeDbPathProvider.overrideWith((ref) => Future.value(bibleDbPath)),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(readerRefProvider.future);
      // Because book 99 > maxBook (66), it should reset to book 1, chapter 1
      expect(state.bookId, equals(1));
      expect(state.chapter, equals(1));
    });

    test(
      'clamps invalid out-of-bound chapter of valid book to max chapter',
      () async {
        // Genesis has 50 chapters. Let's save chapter 99.
        AppPreferences.useMemoryStoreForTesting({
          'reader_book_id': 1,
          'reader_chapter': 99,
        });

        final container = ProviderContainer(
          overrides: [
            activeDbPathProvider.overrideWith(
              (ref) => Future.value(bibleDbPath),
            ),
          ],
        );
        addTearDown(container.dispose);

        final state = await container.read(readerRefProvider.future);
        // It should clamp to Genesis max chapter (50)
        expect(state.bookId, equals(1));
        expect(state.chapter, equals(50));
      },
    );
  });
}
