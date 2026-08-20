import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('XML corpus schemas', () {
    test('validate every Bible and commentary corpus document', () {
      const schemaPaths = {
        'assets/data/bible': 'assets/data/schema/bible.xml',
        'assets/data/commentary': 'assets/data/schema/commentary.xml',
      };

      for (final entry in schemaPaths.entries) {
        final schema = File(entry.value);
        expect(schema.existsSync(), isTrue, reason: 'Missing ${entry.value}');

        final documents = Directory(entry.key)
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.xml'));
        for (final document in documents) {
          final result = Process.runSync('xmllint', [
            '--noout',
            '--schema',
            schema.path,
            document.path,
          ]);
          expect(
            result.exitCode,
            0,
            reason: '${document.path}: ${result.stderr}',
          );
        }
      }
    });
  });
}
