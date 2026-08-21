import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:Love/app/app_preferences.dart';
import 'package:Love/data/import/zip_extractor.dart';
import 'package:Love/data/storage/db_path_provider.dart';
import 'package:Love/features/library/providers/library_controller.dart';
import 'package:Love/features/reader/data/reader_repository.dart';
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

      bibleDbPath = p.join(tempExtractDir.path, 'eng_niv.sqlite');
      const extractor = ZipExtractor();
      await extractor.extractFile(
        targetZipPath: 'data/bible/eng_niv.sqlite',
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

    test(
      'removes stale Bible metadata and persists only a manifest ID',
      () async {
        AppPreferences.useMemoryStoreForTesting({
          'active_bible_id': 'kor_korkr4',
          'active_bible_file': 'kor_korkr4.sqlite',
          'active_bible_name': '개역개정',
        });
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final selection = await container.read(
          activeBibleSelectionProvider.future,
        );
        expect(selection!.id, isNot('kor_korkr4'));

        await container
            .read(activeBibleSelectionProvider.notifier)
            .select('eng_niv');
        final prefs = await AppPreferences.getInstance();
        expect(prefs.getString('active_bible_id'), 'eng_niv');
        expect(prefs.getString('active_bible_file'), isNull);
        expect(prefs.getString('active_bible_name'), isNull);
      },
    );

    test('generated translations include Judges chapter 16', () async {
      const files = [
        'eng_niv.sqlite',
        'eng_nlt.sqlite',
        'jpn_jcb.sqlite',
        'jpn_shinkyoudoyaku.sqlite',
        'kor_klb.sqlite',
        'kor_koerv.sqlite',
        'kor_krv.sqlite',
        'kor_rnksv.sqlite',
        'kor_wrm.sqlite',
        'zho_ccb.sqlite',
        'zho_rcuvss.sqlite',
      ];
      const extractor = ZipExtractor();
      const repository = ReaderRepository();

      for (final file in files) {
        final path = p.join(tempExtractDir.path, file);
        await extractor.extractFile(
          targetZipPath: 'data/bible/$file',
          destinationPath: path,
          zipFilePath: 'assets/data.zip',
        );
        expect(
          repository.loadChapter(dbPath: path, bookId: 7, chapter: 16),
          isNotEmpty,
          reason: '$file is missing Judges 16',
        );
      }
    });

    test(
      'merges segmented verses and keeps headings in reading order',
      () async {
        final path = p.join(tempExtractDir.path, 'kor_koerv_heading.sqlite');
        const extractor = ZipExtractor();
        await extractor.extractFile(
          targetZipPath: 'data/bible/kor_koerv.sqlite',
          destinationPath: path,
          zipFilePath: 'assets/data.zip',
        );

        const repository = ReaderRepository();
        final lines = repository.loadChapterLines(
          dbPath: path,
          bookId: 1,
          chapter: 29,
        );
        final verse14 = lines.whereType<VerseLine>().where(
          (line) => line.verse == 14,
        );
        expect(verse14, hasLength(1));
        expect(verse14.single.text, contains('라반이 그에게 말하였다'));
        expect(verse14.single.text, contains('야곱이 라반의 집에 머문 지 한 달'));

        final headingIndex = lines.indexWhere(
          (line) => line is ChapterHeading && line.text == '라반이 야곱을 속이다',
        );
        final verseIndex = lines.indexWhere(
          (line) => line is VerseLine && line.verse == 14,
        );
        expect(headingIndex, greaterThanOrEqualTo(0));
        expect(headingIndex, lessThan(verseIndex));
      },
    );
  });
}
