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

    test(
      'Korean delimiter headings preserve body text after the verse marker',
      () {
        final hochma = File(
          'assets/data/commentary/kor_hochma.xml',
        ).readAsStringSync();

        expect(
          hochma,
          contains(
            '<reference book="Gen" chapter="31" verses="1" />\n'
            '          <body>야곱이...다 빼앗고',
          ),
        );
        expect(
          hochma,
          contains(
            '<reference book="2Sam" chapter="4" verses="4" />\n'
            '          <body>절뚝발이 아들...므비보셋',
          ),
        );
        expect(
          hochma,
          contains(
            '<reference book="Exod" chapter="20" verses="5" />\n'
            '          <body>절하지 말며',
          ),
        );
        expect(
          hochma,
          contains(
            '<reference book="Deut" chapter="5" verses="9" />\n'
            '          <body>절하지 말며..섬기지 말라',
          ),
        );
        expect(
          hochma,
          contains(
            '<reference book="Num" chapter="31" verses="27" />\n'
            '          <body>절반은 회중에게',
          ),
        );
        expect(
          hochma,
          contains(
            '<reference book="Josh" chapter="15" verses="21-62" />\n'
            '          <body>1-12절에서는',
          ),
        );
      },
    );
  });
}
