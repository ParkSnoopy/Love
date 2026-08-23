import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_configuration.dart';
import 'app_configuration_parser.dart';

class AppConfigurationMigrator {
  const AppConfigurationMigrator({this.defaults = AppConfiguration.defaults});

  static const _parser = AppConfigurationParser();

  final Map<String, Object?> defaults;

  Future<void> migrateIfNeeded({
    required String appDataPath,
    required String appVersion,
  }) async {
    final directory = Directory(appDataPath);
    await directory.create(recursive: true);
    final versionFile = File(p.join(appDataPath, 'configuration.version'));
    if (await _readVersion(versionFile) == appVersion) return;

    final preferencesFile = File(p.join(appDataPath, 'preferences.json'));
    final stagedPreferences = File(
      p.join(appDataPath, '.preferences.migrate.json'),
    );
    final previousPreferences = File(
      p.join(appDataPath, '.preferences.previous.json'),
    );
    final local = await _readConfiguration(preferencesFile);
    final updated = _parser.merge(defaults: defaults, overrides: [local]);

    await _deleteIfExists(stagedPreferences);
    await _deleteIfExists(previousPreferences);
    await stagedPreferences.writeAsBytes(_parser.encode(updated), flush: true);
    if (preferencesFile.existsSync()) {
      await preferencesFile.rename(previousPreferences.path);
    }

    try {
      await stagedPreferences.rename(preferencesFile.path);
    } catch (_) {
      if (previousPreferences.existsSync()) {
        await previousPreferences.rename(preferencesFile.path);
      }
      rethrow;
    }

    await versionFile.writeAsString(appVersion, flush: true);
    await _deleteIfExists(previousPreferences);
  }

  Future<String?> _readVersion(File file) async {
    try {
      if (file.existsSync()) return await file.readAsString();
    } catch (_) {}
    return null;
  }

  Future<Map<String, Object?>> _readConfiguration(File file) async {
    try {
      if (!file.existsSync()) return <String, Object?>{};
      return _parser.parseBytes(await file.readAsBytes());
    } on AppConfigurationParseException catch (_) {}
    return <String, Object?>{};
  }

  Future<void> _deleteIfExists(File file) async {
    if (file.existsSync()) await file.delete();
  }
}
