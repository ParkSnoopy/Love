import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Love/data/backup/app_data_backup_service.dart';
import 'package:Love/features/study/data/user_data_repository.dart';

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
    expect(preferences['reader_book_id'], 1);
    expect(preferences['reader_chapter'], 2);
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
}
