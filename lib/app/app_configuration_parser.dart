import 'dart:convert';
import 'dart:typed_data';

class AppConfigurationParseException implements Exception {
  const AppConfigurationParseException();
}

class AppConfigurationParser {
  const AppConfigurationParser();

  Map<String, Object?> parseBytes(Uint8List bytes) {
    try {
      return parseString(utf8.decode(bytes));
    } on AppConfigurationParseException {
      rethrow;
    } catch (_) {
      throw const AppConfigurationParseException();
    }
  }

  Map<String, Object?> parseString(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) {
        throw const AppConfigurationParseException();
      }
      for (final value in decoded.values) {
        if (value != null &&
            value is! num &&
            value is! bool &&
            value is! String) {
          throw const AppConfigurationParseException();
        }
      }
      return Map<String, Object?>.from(decoded);
    } on AppConfigurationParseException {
      rethrow;
    } catch (_) {
      throw const AppConfigurationParseException();
    }
  }

  Map<String, Object?> merge({
    Map<String, Object?> defaults = const {},
    Iterable<Map<String, Object?>> overrides = const [],
  }) {
    final merged = <String, Object?>{}..addAll(defaults);
    for (final override in overrides) {
      merged.addAll(override);
    }
    return merged;
  }

  Uint8List encode(Map<String, Object?> configuration) {
    return Uint8List.fromList(utf8.encode(jsonEncode(configuration)));
  }
}
