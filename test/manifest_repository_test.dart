import 'package:flutter_test/flutter_test.dart';
import 'package:Love/features/library/domain/manifest_repository.dart';

void main() {
  group('ManifestRepository', () {
    test('normalizes cmn to Chinese and sorts Korean packs first per type', () {
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
    "id": "kor_bible",
    "shortname": "Korean Bible",
    "name": "Korean Bible",
    "language": "Korean",
    "type": "bible",
    "file": "nocr/kor_bible.sqlite",
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
        'kor_bible',
        'cmn_bible',
        'eng_bible',
        'kor_commentary',
        'eng_commentary',
      ]);
      expect(packs.firstWhere((p) => p.id == 'cmn_bible').language, 'Chinese');
      expect(
        packs.firstWhere((p) => p.id == 'kor_commentary').language,
        'Korean',
      );
    });
  });
}
