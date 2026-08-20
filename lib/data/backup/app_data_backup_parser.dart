import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

class AppDataBackupException implements Exception {
  const AppDataBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ParsedAppDataBackup {
  const ParsedAppDataBackup({
    required this.preferences,
    required this.userData,
  });

  final Uint8List preferences;
  final Uint8List userData;
}

class AppDataBackupParser {
  const AppDataBackupParser();

  static const formatVersion = 1;
  static const _maxBackupBytes = 64 * 1024 * 1024;

  ParsedAppDataBackup parse(Uint8List backupBytes) {
    if (backupBytes.isEmpty || backupBytes.length > _maxBackupBytes) {
      throw const AppDataBackupException('Invalid backup file size.');
    }

    final archive = _decodeArchive(backupBytes);
    final metadata = _requiredFile(archive, 'metadata.json');
    final preferences = _requiredFile(archive, 'preferences.json');
    final userData = _requiredFile(archive, 'user_data.db');
    _validateMetadata(metadata);
    _validatePreferences(preferences);
    return ParsedAppDataBackup(preferences: preferences, userData: userData);
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
}
