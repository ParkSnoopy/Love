import 'package:flutter_test/flutter_test.dart';

import '../lib/features/library/domain/bible_pack.dart';
import '../lib/features/library/domain/manifest_repository.dart';

void main() {
  test('ManifestRepository parses bible packs and drops non-bible rows', () {
    const json = '''
[
  {"id":"en_kjv","file":"nocr/en_kjv.sqlite","shortname":"KJV","language":"English","type":"bible"},
  {"id":"com_tsk","file":"comment/com_tsk.sqlite","shortname":"TSK","language":"English","type":"comment"},
  {"id":"ko_korkrv","file":"nocr/ko_korkrv.sqlite","shortname":"개역개정","language":"한국어","type":"bible"}
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
          file: 'nocr/en_kjv.sqlite',
        ),
        BiblePack(
          id: 'ko_korkrv',
          shortName: '개역개정',
          language: '한국어',
          type: 'bible',
          file: 'nocr/ko_korkrv.sqlite',
        ),
      ],
    );
  });
}
