import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../data/storage/app_storage.dart';

class AppPreferences {
  AppPreferences._(this._file, Map<String, Object?> values) : _values = values;

  static AppPreferences? _instance;
  static Map<String, Object?>? _memoryValuesForTesting;

  final File? _file;
  final Map<String, Object?> _values;

  static void useMemoryStoreForTesting([
    Map<String, Object?> values = const {},
  ]) {
    _memoryValuesForTesting = Map<String, Object?>.from(values);
    _instance = null;
  }

  static void clearMemoryStoreForTesting() {
    _memoryValuesForTesting = null;
    _instance = null;
  }

  static Future<AppPreferences> getInstance() async {
    final existing = _instance;
    if (existing != null) return existing;

    final memoryValues = _memoryValuesForTesting;
    if (memoryValues != null) {
      return _instance = AppPreferences._(null, memoryValues);
    }

    final file = File(p.join(await _settingsDirPath(), 'preferences.json'));
    final values = await _readValues(file);
    return _instance = AppPreferences._(file, values);
  }

  static Future<String> _settingsDirPath() async {
    return (await getAppDataDirectory()).path;
  }

  static Future<Map<String, Object?>> _readValues(File file) async {
    try {
      if (!file.existsSync()) return <String, Object?>{};
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        return Map<String, Object?>.from(decoded);
      }
    } catch (_) {}
    return <String, Object?>{};
  }

  int? getInt(String key) {
    final value = _values[key];
    return value is int ? value : null;
  }

  double? getDouble(String key) {
    final value = _values[key];
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return null;
  }

  String? getString(String key) {
    final value = _values[key];
    return value is String ? value : null;
  }

  Future<void> setInt(String key, int value) async {
    _values[key] = value;
    await _save();
  }

  Future<void> setDouble(String key, double value) async {
    _values[key] = value;
    await _save();
  }

  Future<void> setString(String key, String value) async {
    _values[key] = value;
    await _save();
  }

  Future<void> remove(String key) async {
    _values.remove(key);
    await _save();
  }

  Future<void> _save() async {
    final file = _file;
    if (file == null) return;
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(_values));
  }
}
