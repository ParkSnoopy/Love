import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../app/app_configuration_parser.dart';

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

  final Map<String, Object?> preferences;
  final Uint8List userData;
}

class AppDataBackupParser {
  const AppDataBackupParser();

  static const _configurationParser = AppConfigurationParser();
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
    return ParsedAppDataBackup(
      preferences: _parsePreferences(preferences),
      userData: userData,
    );
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
      if (metadata is! Map<String, dynamic>) {
        throw const AppDataBackupException('Backup metadata is invalid.');
      }
      final format = metadata['format'] ?? 'love-app-data';
      final version = metadata['version'] ?? formatVersion;
      if (format != 'love-app-data' || version != formatVersion) {
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

  Map<String, Object?> _parsePreferences(Uint8List bytes) {
    try {
      return _configurationParser.parseBytes(bytes);
    } on AppConfigurationParseException {
      throw const AppDataBackupException('Backup settings are invalid.');
    }
  }
}
