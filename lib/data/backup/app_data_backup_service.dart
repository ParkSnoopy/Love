import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

class AppDataBackupException implements Exception {
  const AppDataBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AppDataBackupService {
  const AppDataBackupService();

  static const formatVersion = 1;
  static const fileExtension = 'lovebackup';
  static const _maxBackupBytes = 64 * 1024 * 1024;
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
    if (backupBytes.isEmpty || backupBytes.length > _maxBackupBytes) {
      throw const AppDataBackupException('Invalid backup file size.');
    }

    final archive = _decodeArchive(backupBytes);
    final metadataBytes = _requiredFile(archive, 'metadata.json');
    final preferencesBytes = _requiredFile(archive, 'preferences.json');
    final userDataBytes = _requiredFile(archive, 'user_data.db');
    _validateMetadata(metadataBytes);
    _validatePreferences(preferencesBytes);

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
      await importedDatabase.writeAsBytes(userDataBytes, flush: true);
      _validateDatabase(importedDatabase.path);
      await importedPreferences.writeAsBytes(preferencesBytes, flush: true);

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

  Archive _decodeArchive(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      if (archive.length != 3 || archive.any((entry) => !entry.isFile)) {
        throw const AppDataBackupException('Backup has unexpected contents.');
      }
      return archive;
    } on AppDataBackupException {
      rethrow;
    } catch (_) {
      throw const AppDataBackupException('Backup is not a valid archive.');
    }
  }

  Uint8List _requiredFile(Archive archive, String name) {
    final entry = archive.find(name);
    final bytes = entry?.readBytes();
    if (entry == null || !entry.isFile || bytes == null) {
      throw AppDataBackupException('Backup is missing $name.');
    }
    return bytes;
  }

  void _validateMetadata(Uint8List bytes) {
    try {
      final metadata = jsonDecode(utf8.decode(bytes));
      if (metadata is! Map<String, dynamic> ||
          metadata['format'] != 'love-app-data' ||
          metadata['version'] != formatVersion) {
        throw const AppDataBackupException(
          'Backup format is not supported by this app version.',
        );
      }
    } on AppDataBackupException {
      rethrow;
    } catch (_) {
      throw const AppDataBackupException('Backup metadata is invalid.');
    }
  }

  void _validatePreferences(Uint8List bytes) {
    try {
      final preferences = jsonDecode(utf8.decode(bytes));
      if (preferences is! Map<String, dynamic>) {
        throw const AppDataBackupException('Backup settings are invalid.');
      }
      for (final value in preferences.values) {
        if (value != null &&
            value is! num &&
            value is! bool &&
            value is! String) {
          throw const AppDataBackupException('Backup settings are invalid.');
        }
      }
    } on AppDataBackupException {
      rethrow;
    } catch (_) {
      throw const AppDataBackupException('Backup settings are invalid.');
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
