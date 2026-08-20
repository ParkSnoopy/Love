import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:Love/features/study/data/user_data_repository.dart';

void main() {
  group('UserDataRepository Highlight Overlaps Tests', () {
    int dbCounter = 0;
    late String dbPath;
    final List<File> createdFiles = [];
    const repo = UserDataRepository();

    setUp(() {
      final file = File('test/temp_user_data_test_${dbCounter++}.sqlite');
      if (file.existsSync()) {
        file.deleteSync();
      }
      createdFiles.add(file);
      dbPath = file.path;
      repo.init(dbPath);
    });

    tearDown(() {
      for (final file in createdFiles) {
        if (file.existsSync()) {
          file.deleteSync();
        }
      }
      createdFiles.clear();
    });

    test('addHighlight inserts highlight when there is no overlap', () {
      repo.addHighlight(
        dbPath: dbPath,
        bookId: 1,
        chapter: 1,
        verseStart: 1,
        verseEnd: 2,
        color: 'yellow',
        createdAt: 100,
      );

      final highlights = repo.loadHighlights(dbPath: dbPath);
      expect(highlights, hasLength(1));
      expect(highlights[0].verseStart, equals(1));
      expect(highlights[0].verseEnd, equals(2));
      expect(highlights[0].color, equals('yellow'));
    });

    test('addHighlight joins adjacent highlights with the same color', () {
      repo.addHighlight(
        dbPath: dbPath,
        bookId: 1,
        chapter: 1,
        verseStart: 1,
        verseEnd: 2,
        color: 'yellow',
        createdAt: 100,
      );
      repo.addHighlight(
        dbPath: dbPath,
        bookId: 1,
        chapter: 1,
        verseStart: 3,
        verseEnd: 4,
        color: 'yellow',
        createdAt: 200,
      );

      final highlights = repo.loadHighlights(dbPath: dbPath);
      expect(highlights, hasLength(1));
      expect(highlights.single.verseStart, equals(1));
      expect(highlights.single.verseEnd, equals(4));
      expect(highlights.single.color, equals('yellow'));
    });

    test('addHighlight splits overlapping highlights properly', () {
      // 1. Add a wide highlight from verse 3 to 10
      repo.addHighlight(
        dbPath: dbPath,
        bookId: 1,
        chapter: 1,
        verseStart: 3,
        verseEnd: 10,
        color: 'green',
        createdAt: 100,
      );

      // 2. Add an overlapping highlight from verse 5 to 7 (new highlight)
      repo.addHighlight(
        dbPath: dbPath,
        bookId: 1,
        chapter: 1,
        verseStart: 5,
        verseEnd: 7,
        color: 'red',
        createdAt: 200,
      );

      final highlights = repo.loadHighlights(dbPath: dbPath);
      // We expect 3 highlights now:
      // - Left leftover: 3 to 4 (green)
      // - Right leftover: 8 to 10 (green)
      // - New highlight: 5 to 7 (red)
      expect(highlights, hasLength(3));

      // Order in loadHighlights is DESC by createdAt, then id.
      // So new highlight (createdAt 200) should be first.
      expect(highlights[0].verseStart, equals(5));
      expect(highlights[0].verseEnd, equals(7));
      expect(highlights[0].color, equals('red'));

      // The rest were inserted during split, so they have the original createdAt (100).
      final leftovers = highlights.skip(1).toList();
      leftovers.sort((a, b) => a.verseStart.compareTo(b.verseStart));

      expect(leftovers[0].verseStart, equals(3));
      expect(leftovers[0].verseEnd, equals(4));
      expect(leftovers[0].color, equals('green'));

      expect(leftovers[1].verseStart, equals(8));
      expect(leftovers[1].verseEnd, equals(10));
      expect(leftovers[1].color, equals('green'));
    });

    test('addHighlight completely removes fully covered highlights', () {
      // 1. Add two small highlights
      repo.addHighlight(
        dbPath: dbPath,
        bookId: 1,
        chapter: 1,
        verseStart: 2,
        verseEnd: 3,
        color: 'yellow',
        createdAt: 100,
      );
      repo.addHighlight(
        dbPath: dbPath,
        bookId: 1,
        chapter: 1,
        verseStart: 5,
        verseEnd: 6,
        color: 'green',
        createdAt: 110,
      );

      // 2. Add a wide highlight that covers both (1 to 7)
      repo.addHighlight(
        dbPath: dbPath,
        bookId: 1,
        chapter: 1,
        verseStart: 1,
        verseEnd: 7,
        color: 'red',
        createdAt: 200,
      );

      final highlights = repo.loadHighlights(dbPath: dbPath);
      // We expect only 1 highlight (the wide red one)
      expect(highlights, hasLength(1));
      expect(highlights[0].verseStart, equals(1));
      expect(highlights[0].verseEnd, equals(7));
      expect(highlights[0].color, equals('red'));
    });

    test('upsertNote keeps the selected verse range', () {
      repo.upsertNote(
        dbPath: dbPath,
        bookId: 1,
        chapter: 1,
        verseStart: 2,
        verse: 4,
        content: 'range memo',
        now: 100,
      );

      final note = repo.loadAllNotes(dbPath: dbPath).single;
      expect(note.verseStart, 2);
      expect(note.verse, 4);
    });
  });
}
