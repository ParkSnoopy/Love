import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../app/app_configuration.dart';
import '../../app/app_configuration_parser.dart';
import 'app_data_backup_parser.dart';

export 'app_data_backup_parser.dart' show AppDataBackupException;

class AppDataBackupService {
  const AppDataBackupService();

  static const _configurationParser = AppConfigurationParser();
  static const formatVersion = AppDataBackupParser.formatVersion;
  static const _requiredDatabaseTables = {
    'bookmarks',
    'highlights',
    'notes',
    'history',
  };
  static const _tableDefinitions = <String, String>{
    'bookmarks': '''
CREATE TABLE bookmarks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL,
  chapter INTEGER NOT NULL,
  verse INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  UNIQUE(book_id, chapter, verse)
)
''',
    'highlights': '''
CREATE TABLE highlights (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL,
  chapter INTEGER NOT NULL,
  verse_start INTEGER NOT NULL,
  verse_end INTEGER NOT NULL,
  color TEXT NOT NULL,
  created_at INTEGER NOT NULL
)
''',
    'notes': '''
CREATE TABLE notes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL,
  chapter INTEGER NOT NULL,
  verse_start INTEGER NOT NULL DEFAULT 0,
  verse INTEGER NOT NULL,
  content TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  UNIQUE(book_id, chapter, verse)
)
''',
    'history': '''
CREATE TABLE history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL,
  chapter INTEGER NOT NULL,
  verse INTEGER NOT NULL,
  visited_at INTEGER NOT NULL
)
''',
  };
  static const _columnDefinitions = <String, Map<String, String>>{
    'bookmarks': {
      'book_id': 'INTEGER NOT NULL DEFAULT 0',
      'chapter': 'INTEGER NOT NULL DEFAULT 0',
      'verse': 'INTEGER NOT NULL DEFAULT 0',
      'created_at': 'INTEGER NOT NULL DEFAULT 0',
    },
    'highlights': {
      'book_id': 'INTEGER NOT NULL DEFAULT 0',
      'chapter': 'INTEGER NOT NULL DEFAULT 0',
      'verse_start': 'INTEGER NOT NULL DEFAULT 0',
      'verse_end': 'INTEGER NOT NULL DEFAULT 0',
      'color': "TEXT NOT NULL DEFAULT 'yellow'",
      'created_at': 'INTEGER NOT NULL DEFAULT 0',
    },
    'notes': {
      'book_id': 'INTEGER NOT NULL DEFAULT 0',
      'chapter': 'INTEGER NOT NULL DEFAULT 0',
      'verse_start': 'INTEGER NOT NULL DEFAULT 0',
      'verse': 'INTEGER NOT NULL DEFAULT 0',
      'content': "TEXT NOT NULL DEFAULT ''",
      'created_at': 'INTEGER NOT NULL DEFAULT 0',
      'updated_at': 'INTEGER NOT NULL DEFAULT 0',
    },
    'history': {
      'book_id': 'INTEGER NOT NULL DEFAULT 0',
      'chapter': 'INTEGER NOT NULL DEFAULT 0',
      'verse': 'INTEGER NOT NULL DEFAULT 0',
      'visited_at': 'INTEGER NOT NULL DEFAULT 0',
    },
  };

  Future<Uint8List> createBackup({required String appDataPath}) async {
    final appDataDirectory = Directory(appDataPath);
    await appDataDirectory.create(recursive: true);

    final userDataFile = File(p.join(appDataPath, 'user_data.db'));
    if (!userDataFile.existsSync()) {
      throw const AppDataBackupException('User data is not initialized.');
    }

    final snapshotFile = File(p.join(appDataPath, '.user_data.backup.db'));
    try {
      await _copyDatabase(userDataFile.path, snapshotFile.path);
      final preferencesFile = File(p.join(appDataPath, 'preferences.json'));
      final preferences = preferencesFile.existsSync()
          ? await preferencesFile.readAsBytes()
          : utf8.encode('{}');

      final archive = Archive()
        ..add(
          ArchiveFile.string(
            'metadata.json',
            jsonEncode({
              'format': 'love-app-data',
              'version': formatVersion,
              'createdAt': DateTime.now().toUtc().toIso8601String(),
            }),
          ),
        )
        ..add(ArchiveFile.bytes('preferences.json', preferences))
        ..add(
          ArchiveFile.bytes('user_data.db', await snapshotFile.readAsBytes()),
        );
      return ZipEncoder().encodeBytes(archive);
    } finally {
      if (snapshotFile.existsSync()) await snapshotFile.delete();
    }
  }

  Future<void> importBackup({
    required String appDataPath,
    required Uint8List backupBytes,
  }) async {
    final backup = const AppDataBackupParser().parse(backupBytes);

    final appDataDirectory = Directory(appDataPath);
    await appDataDirectory.create(recursive: true);
    final importedDatabase = File(p.join(appDataPath, '.user_data.import.db'));
    final importedPreferences = File(
      p.join(appDataPath, '.preferences.import.json'),
    );
    final targetDatabase = File(p.join(appDataPath, 'user_data.db'));
    final targetPreferences = File(p.join(appDataPath, 'preferences.json'));
    final oldDatabase = File(p.join(appDataPath, '.user_data.previous.db'));
    final oldPreferences = File(
      p.join(appDataPath, '.preferences.previous.json'),
    );

    try {
      await importedDatabase.writeAsBytes(backup.userData, flush: true);
      _validateDatabase(importedDatabase.path);
      final preferences = await _updatedPreferences(
        targetPreferences,
        backup.preferences,
      );
      await importedPreferences.writeAsBytes(preferences, flush: true);

      await _deleteIfExists(oldDatabase);
      await _deleteIfExists(oldPreferences);
      if (targetDatabase.existsSync())
        await targetDatabase.rename(oldDatabase.path);
      if (targetPreferences.existsSync()) {
        await targetPreferences.rename(oldPreferences.path);
      }

      try {
        await importedDatabase.rename(targetDatabase.path);
        await importedPreferences.rename(targetPreferences.path);
      } catch (_) {
        await _deleteIfExists(targetDatabase);
        await _deleteIfExists(targetPreferences);
        if (oldDatabase.existsSync())
          await oldDatabase.rename(targetDatabase.path);
        if (oldPreferences.existsSync()) {
          await oldPreferences.rename(targetPreferences.path);
        }
        rethrow;
      }

      await _deleteIfExists(oldDatabase);
      await _deleteIfExists(oldPreferences);
    } on AppDataBackupException {
      rethrow;
    } catch (error) {
      throw AppDataBackupException('Could not import backup: $error');
    } finally {
      await _deleteIfExists(importedDatabase);
      await _deleteIfExists(importedPreferences);
    }
  }

  Future<void> _copyDatabase(String sourcePath, String destinationPath) async {
    await _deleteIfExists(File(destinationPath));
    final source = sqlite3.open(sourcePath, mode: OpenMode.readOnly);
    final destination = sqlite3.open(destinationPath);
    try {
      await source.backup(destination).drain<void>();
    } finally {
      destination.close();
      source.close();
    }
  }

  Future<Uint8List> _updatedPreferences(
    File currentPreferences,
    Map<String, Object?> importedPreferences,
  ) async {
    var current = <String, Object?>{};
    if (currentPreferences.existsSync()) {
      try {
        current = _configurationParser.parseBytes(
          await currentPreferences.readAsBytes(),
        );
      } on AppConfigurationParseException catch (_) {}
    }
    final updated = _configurationParser.merge(
      defaults: AppConfiguration.defaults,
      overrides: [current, importedPreferences],
    );
    updated.removeWhere((key, _) => AppConfiguration.removedKeys.contains(key));
    return _configurationParser.encode(updated);
  }

  void _validateDatabase(String path) {
    Database? database;
    try {
      database = sqlite3.open(path);
      final integrity = database.select('PRAGMA integrity_check;');
      if (integrity.length != 1 || integrity.first.values.first != 'ok') {
        throw const AppDataBackupException('Backup database is corrupted.');
      }
      _repairDatabase(database);
      final rows = database.select(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final tables = rows.map((row) => row['name'] as String).toSet();
      if (!tables.containsAll(_requiredDatabaseTables)) {
        throw const AppDataBackupException(
          'Backup database does not contain Love app data.',
        );
      }
    } on AppDataBackupException {
      rethrow;
    } catch (_) {
      throw const AppDataBackupException('Backup database is invalid.');
    } finally {
      database?.close();
    }
  }

  void _repairDatabase(Database database) {
    for (final table in _requiredDatabaseTables) {
      final existing = database.select(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        [table],
      );
      if (existing.isEmpty) {
        database.execute(_tableDefinitions[table]!);
        continue;
      }

      final columns = _columnsFor(database, table);
      if (!columns.contains('id')) {
        _rebuildTable(database, table, columns);
        continue;
      }

      for (final entry in _columnDefinitions[table]!.entries) {
        if (!columns.contains(entry.key)) {
          database.execute(
            'ALTER TABLE $table ADD COLUMN ${entry.key} ${entry.value}',
          );
        }
      }
    }
  }

  Set<String> _columnsFor(Database database, String table) {
    return database
        .select('PRAGMA table_info($table)')
        .map((row) => row['name'] as String)
        .toSet();
  }

  void _rebuildTable(
    Database database,
    String table,
    Set<String> legacyColumns,
  ) {
    final legacyTable = '${table}_legacy';
    database.execute('DROP TABLE IF EXISTS $legacyTable');
    database.execute('ALTER TABLE $table RENAME TO $legacyTable');
    database.execute(_tableDefinitions[table]!);

    final columns = _columnDefinitions[table]!.keys.toList(growable: false);
    final values = columns
        .map(
          (column) => legacyColumns.contains(column)
              ? column
              : _columnDefinitions[table]![column]!.split(' DEFAULT ').last,
        )
        .join(', ');
    database.execute(
      'INSERT OR REPLACE INTO $table (${columns.join(', ')}) '
      'SELECT $values FROM $legacyTable',
    );
    database.execute('DROP TABLE $legacyTable');
  }

  Future<void> _deleteIfExists(File file) async {
    if (file.existsSync()) await file.delete();
  }
}
