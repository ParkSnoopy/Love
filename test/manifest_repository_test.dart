import 'package:flutter_test/flutter_test.dart';

import '../lib/features/library/domain/bible_pack.dart';
import '../lib/features/library/domain/manifest_repository.dart';

void main() {
  test('ManifestRepository parses bible packs including commentaries', () {
    const json = '''
[
  {"id":"en_kjv","file":"nocr/en_kjv.sqlite","shortname":"KJV","name":"King James Version","language":"English","type":"bible","source":"nocr"},
  {"id":"com_tsk","file":"comment/com_tsk.sqlite","shortname":"TSK","name":"Treasury of Scripture Knowledge","language":"English","type":"commentary","source":"comment"},
  {"id":"ko_korkrv","file":"nocr/ko_korkrv.sqlite","shortname":"개역개정","name":"개역개정","language":"한국어","type":"bible","source":"nocr"}
]
''';

    final repo = ManifestRepository();
    final packs = repo.parseBiblePacks(json);

    expect(packs, const [
      BiblePack(
        id: 'en_kjv',
        shortName: 'KJV',
        name: 'King James Version',
        language: 'English',
        type: 'bible',
        file: 'nocr/en_kjv.sqlite',
        source: 'nocr',
      ),
      BiblePack(
        id: 'com_tsk',
        shortName: 'TSK',
        name: 'Treasury of Scripture Knowledge',
        language: 'English',
        type: 'commentary',
        file: 'comment/com_tsk.sqlite',
        source: 'comment',
      ),
      BiblePack(
        id: 'ko_korkrv',
        shortName: '개역개정',
        name: '개역개정',
        language: '한국어',
        type: 'bible',
        file: 'nocr/ko_korkrv.sqlite',
        source: 'nocr',
      ),
    ]);
  });
}
