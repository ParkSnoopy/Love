import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'app_data_backup_parser.dart';

export 'app_data_backup_parser.dart' show AppDataBackupException;

class AppDataBackupService {
  const AppDataBackupService();

  static const formatVersion = AppDataBackupParser.formatVersion;
  static const fileExtension = 'lovebackup';
  static const _requiredDatabaseTables = {
    'bookmarks',
    'highlights',
    'notes',
    'history',
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
      await importedPreferences.writeAsBytes(backup.preferences, flush: true);

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

  void _validateDatabase(String path) {
    Database? database;
    try {
      database = sqlite3.open(path, mode: OpenMode.readOnly);
      final integrity = database.select('PRAGMA integrity_check;');
      if (integrity.length != 1 || integrity.first.values.first != 'ok') {
        throw const AppDataBackupException('Backup database is corrupted.');
      }
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

  Future<void> _deleteIfExists(File file) async {
    if (file.existsSync()) await file.delete();
  }
}
