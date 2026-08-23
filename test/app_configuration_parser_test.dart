import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:Love/app/app_configuration_parser.dart';

void main() {
  const parser = AppConfigurationParser();

  test('parses scalar configuration values', () {
    final values = parser.parseBytes(
      Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'integer': 7,
            'decimal': 1.25,
            'enabled': true,
            'label': 'saved',
            'optional': null,
          }),
        ),
      ),
    );

    expect(values['integer'], 7);
    expect(values['decimal'], 1.25);
    expect(values['enabled'], isTrue);
    expect(values['label'], 'saved');
    expect(values['optional'], isNull);
  });

  test('rejects nested configuration values', () {
    expect(
      () => parser.parseString(jsonEncode({'nested': <String, Object?>{}})),
      throwsA(isA<AppConfigurationParseException>()),
    );
  });

  test('merges defaults and ordered overrides', () {
    expect(
      parser.merge(
        defaults: {'preserved': 1, 'overridden': 2},
        overrides: [
          {'overridden': 3, 'local_only': 4},
          {'overridden': 5},
        ],
      ),
      {'preserved': 1, 'overridden': 5, 'local_only': 4},
    );
  });
}
