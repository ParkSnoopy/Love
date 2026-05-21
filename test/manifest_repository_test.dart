import 'package:flutter_test/flutter_test.dart';

import '../lib/features/library/domain/bible_pack.dart';
import '../lib/features/library/domain/manifest_repository.dart';

void main() {
  test('ManifestRepository parses bible packs and drops non-bible rows', () {
    const json = '''
[
  {"id":"en_kjv","shortname":"KJV","language":"English","type":"bible"},
  {"id":"com_tsk","shortname":"TSK","language":"English","type":"comment"},
  {"id":"ko_korkrv","shortname":"개역개정","language":"한국어","type":"bible"}
]
''';

    final repo = ManifestRepository();
    final packs = repo.parseBiblePacks(json);

    expect(
      packs,
      const [
        BiblePack(
          id: 'en_kjv',
          shortName: 'KJV',
          language: 'English',
          type: 'bible',
        ),
        BiblePack(
          id: 'ko_korkrv',
          shortName: '개역개정',
          language: '한국어',
          type: 'bible',
        ),
      ],
    );
  });
}
