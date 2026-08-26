import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:Love/app/app_theme.dart';
import 'package:Love/features/library/domain/manifest_repository.dart';

void main() {
  group('ManifestRepository', () {
    test(
      'normalizes languages and gives requested Korean Bibles precedence',
      () {
        const jsonText = '''
[
  {
    "id": "eng_bible",
    "shortname": "English Bible",
    "name": "English Bible",
    "language": "English",
    "type": "bible",
    "file": "nocr/eng_bible.sqlite",
    "source": "nocr"
  },
  {
    "id": "cmn_bible",
    "shortname": "Chinese Bible",
    "name": "Chinese Bible",
    "language": "cmn",
    "type": "bible",
    "file": "helloao/cmn_bible.sqlite",
    "source": "helloao"
  },
  {
    "id": "kor_other",
    "shortname": "새번역",
    "name": "새번역",
    "language": "Korean",
    "type": "bible",
    "file": "nocr/kor_bible.sqlite",
    "source": "nocr"
  },
  {
    "id": "kor_woori",
    "shortname": "우리말 성경",
    "name": "우리말 성경",
    "language": "Korean",
    "type": "bible",
    "file": "nocr/kor_woori.sqlite",
    "source": "nocr"
  },
  {
    "id": "kor_korkr4",
    "shortname": "개역개정 4판",
    "name": "개역개정 4판",
    "language": "Korean",
    "type": "bible",
    "file": "nocr/kor_korkr4.sqlite",
    "source": "nocr"
  },
  {
    "id": "kor_korkrv",
    "shortname": "개역개정판",
    "name": "개역개정판",
    "language": "Korean",
    "type": "bible",
    "file": "nocr/kor_korkrv.sqlite",
    "source": "nocr"
  },
  {
    "id": "eng_commentary",
    "shortname": "English Commentary",
    "name": "English Commentary",
    "language": "English",
    "type": "commentary",
    "file": "helloao/eng_commentary.sqlite",
    "source": "helloao"
  },
  {
    "id": "kor_commentary",
    "shortname": "Korean Commentary",
    "name": "Korean Commentary",
    "language": "kor",
    "type": "commentary",
    "file": "nocr/kor_commentary.sqlite",
    "source": "nocr"
  }
]
''';

        final packs = const ManifestRepository().parseBiblePacks(jsonText);

        expect(packs.map((p) => p.id), [
          'kor_korkrv',
          'kor_korkr4',
          'kor_woori',
          'kor_other',
          'cmn_bible',
          'eng_bible',
          'kor_commentary',
          'eng_commentary',
        ]);
        expect(
          packs.firstWhere((p) => p.id == 'cmn_bible').language,
          'Chinese',
        );
        expect(
          packs.firstWhere((p) => p.id == 'kor_commentary').language,
          'Korean',
        );
      },
    );

    test('generated short names omit the language code', () {
      final manifest =
          jsonDecode(File('assets/data/manifest.json').readAsStringSync())
              as List<dynamic>;

      for (final rawEntry in manifest) {
        final entry = rawEntry as Map<String, dynamic>;
        final id = entry['id'] as String;
        final file = entry['file'] as String;
        final stem = file.substring(0, file.length - '.sqlite'.length);
        final separator = stem.indexOf('_');
        expect(separator, greaterThan(0), reason: file);
        final languagePrefix = stem.substring(0, separator);
        final prefixedId = '${languagePrefix}_';
        final shortId = id.startsWith(prefixedId)
            ? id.substring(prefixedId.length)
            : id;
        expect(entry['shortname'], shortId.toUpperCase(), reason: id);
      }
    });
  });

  test('custom light base uses warm editorial surfaces', () {
    final theme = buildCustomTheme(
      'NotoSerifCJK',
      brightness: Brightness.light,
      primary: const Color(0xFFCC785C),
    );

    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, const Color(0xFFFAF9F5));
    expect(theme.colorScheme.primary, const Color(0xFFCC785C));
    expect(theme.colorScheme.surfaceContainer, const Color(0xFFEFE9DE));
    expect(theme.colorScheme.onSurface, const Color(0xFF141413));
  });
}
