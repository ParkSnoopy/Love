import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Love/app/app_configuration.dart';
import 'package:Love/data/backup/app_data_backup_service.dart';
import 'package:Love/features/study/data/user_data_repository.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  const service = AppDataBackupService();
  const repository = UserDataRepository();
  var counter = 0;
  final createdDirectories = <Directory>[];

  Directory createDirectory(String purpose) {
    final directory = Directory('test/app_data_backup_${purpose}_${counter++}')
      ..createSync(recursive: true);
    createdDirectories.add(directory);
    return directory;
  }

  tearDown(() {
    for (final directory in createdDirectories.reversed) {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    }
    createdDirectories.clear();
  });

  test('backup round trip restores settings and saved study data', () async {
    final source = createDirectory('source');
    final sourceDatabase = '${source.path}/user_data.db';
    repository.init(sourceDatabase);
    repository.addBookmark(
      dbPath: sourceDatabase,
      bookId: 1,
      chapter: 2,
      verse: 3,
      createdAt: 100,
    );
    repository.upsertNote(
      dbPath: sourceDatabase,
      bookId: 1,
      chapter: 2,
      verseStart: 2,
      verse: 3,
      content: 'remember this',
      now: 200,
    );
    await File(
      '${source.path}/preferences.json',
    ).writeAsString(jsonEncode({'reader_book_id': 1, 'reader_chapter': 2}));

    final backup = await service.createBackup(appDataPath: source.path);
    final destination = createDirectory('destination');
    final destinationDatabase = '${destination.path}/user_data.db';
    repository.init(destinationDatabase);
    repository.addBookmark(
      dbPath: destinationDatabase,
      bookId: 9,
      chapter: 9,
      verse: 9,
      createdAt: 999,
    );

    await service.importBackup(
      appDataPath: destination.path,
      backupBytes: backup,
    );

    final bookmarks = repository.loadBookmarks(dbPath: destinationDatabase);
    final notes = repository.loadAllNotes(dbPath: destinationDatabase);
    final preferences =
        jsonDecode(
              await File('${destination.path}/preferences.json').readAsString(),
            )
            as Map<String, dynamic>;
    expect(bookmarks, hasLength(1));
    expect(bookmarks.single.bookId, 1);
    expect(bookmarks.single.chapter, 2);
    expect(bookmarks.single.verse, 3);
    expect(notes.single.content, 'remember this');
    expect(notes.single.verseStart, 2);
    expect(preferences['reader_book_id'], 1);
    expect(preferences['reader_chapter'], 2);
  });

  test('partial backup preferences update the current configuration', () async {
    final source = createDirectory('partial_source');
    repository.init('${source.path}/user_data.db');
    await File(
      '${source.path}/preferences.json',
    ).writeAsString(jsonEncode({'reader_chapter': 7}));
    final backup = await service.createBackup(appDataPath: source.path);

    final destination = createDirectory('partial_destination');
    repository.init('${destination.path}/user_data.db');
    await File(
      '${destination.path}/preferences.json',
    ).writeAsString(jsonEncode({'theme_mode': 'dark', 'reader_chapter': 2}));

    await service.importBackup(
      appDataPath: destination.path,
      backupBytes: backup,
    );

    final preferences =
        jsonDecode(
              await File('${destination.path}/preferences.json').readAsString(),
            )
            as Map<String, dynamic>;
    expect(preferences, containsPair('theme_mode', 'dark'));
    expect(preferences, containsPair('reader_chapter', 7));
    expect(preferences.keys, containsAll(AppConfiguration.defaults.keys));
  });

  test('invalid backup leaves existing app data unchanged', () async {
    final destination = createDirectory('unchanged');
    final databasePath = '${destination.path}/user_data.db';
    repository.init(databasePath);
    repository.addBookmark(
      dbPath: databasePath,
      bookId: 4,
      chapter: 5,
      verse: 6,
      createdAt: 100,
    );
    await File(
      '${destination.path}/preferences.json',
    ).writeAsString(jsonEncode({'reader_book_id': 4}));

    await expectLater(
      service.importBackup(
        appDataPath: destination.path,
        backupBytes: Uint8List.fromList([1, 2, 3]),
      ),
      throwsA(isA<AppDataBackupException>()),
    );

    final bookmarks = repository.loadBookmarks(dbPath: databasePath);
    expect(bookmarks.single.bookId, 4);
    expect(
      jsonDecode(
        await File('${destination.path}/preferences.json').readAsString(),
      ),
      {'reader_book_id': 4},
    );
  });

  test('backup with wrong database schema is rejected', () async {
    final destination = createDirectory('schema');
    final archive = Archive()
      ..add(
        ArchiveFile.string(
          'metadata.json',
          jsonEncode({'format': 'love-app-data', 'version': 1}),
        ),
      )
      ..add(ArchiveFile.string('preferences.json', '{}'))
      ..add(ArchiveFile.bytes('user_data.db', utf8.encode('not sqlite')));

    await expectLater(
      service.importBackup(
        appDataPath: destination.path,
        backupBytes: ZipEncoder().encodeBytes(archive),
      ),
      throwsA(isA<AppDataBackupException>()),
    );
  });

  test('backup missing supported fields is completed with defaults', () async {
    final source = createDirectory('legacy_source');
    final sourceDatabase = File('${source.path}/user_data.db');
    final database = sqlite.sqlite3.open(sourceDatabase.path);
    database.execute(
      'CREATE TABLE bookmarks (book_id INTEGER, chapter INTEGER, verse INTEGER)',
    );
    database.execute(
      'INSERT INTO bookmarks (book_id, chapter, verse) VALUES (1, 2, 3)',
    );
    database.close();

    final archive = Archive()
      ..add(ArchiveFile.string('metadata.json', '{}'))
      ..add(ArchiveFile.string('preferences.json', '{}'))
      ..add(
        ArchiveFile.bytes('user_data.db', await sourceDatabase.readAsBytes()),
      );
    final destination = createDirectory('legacy_destination');

    await service.importBackup(
      appDataPath: destination.path,
      backupBytes: ZipEncoder().encodeBytes(archive),
    );

    final databasePath = '${destination.path}/user_data.db';
    final bookmarks = repository.loadBookmarks(dbPath: databasePath);
    expect(bookmarks, hasLength(1));
    expect(bookmarks.single.createdAt, 0);
    expect(repository.loadHighlights(dbPath: databasePath), isEmpty);
    expect(repository.loadAllNotes(dbPath: databasePath), isEmpty);
    expect(repository.loadRecentHistory(dbPath: databasePath), isEmpty);
  });

  test('every file under backup imports successfully', () async {
    final backupFiles =
        Directory('backup')
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .toList()
          ..sort((left, right) => left.path.compareTo(right.path));
    expect(backupFiles, isNotEmpty);

    for (final backupFile in backupFiles) {
      final destination = createDirectory('fixture_$counter');
      await expectLater(
        service.importBackup(
          appDataPath: destination.path,
          backupBytes: await backupFile.readAsBytes(),
        ),
        completes,
        reason: 'Failed to import ${backupFile.path}',
      );

      final databasePath = '${destination.path}/user_data.db';
      repository.loadBookmarks(dbPath: databasePath);
      repository.loadHighlights(dbPath: databasePath);
      repository.loadAllNotes(dbPath: databasePath);
      repository.loadRecentHistory(dbPath: databasePath);
      expect(
        jsonDecode(
          await File('${destination.path}/preferences.json').readAsString(),
        ),
        isA<Map<String, dynamic>>(),
      );
    }
  });
}
