import 'package:flutter_test/flutter_test.dart';
import 'package:Love/features/reader/domain/verse_export_formatter.dart';

void main() {
  group('VerseExportFormatter', () {
    test('formats empty list as empty string', () {
      expect(VerseExportFormatter.format([]), '');
    });

    test('formatVerseNumbers groups contiguous and separate numbers', () {
      expect(
        VerseExportFormatter.formatVerseNumbers([1, 2, 3, 5, 7, 8, 10]),
        '1-3, 5, 7-8, 10',
      );
      expect(VerseExportFormatter.formatVerseNumbers([1]), '1');
      expect(VerseExportFormatter.formatVerseNumbers([1, 3, 5]), '1, 3, 5');
      expect(VerseExportFormatter.formatVerseNumbers([1, 2]), '1-2');
    });

    test('format formats multiple selected verses with header and body', () {
      final verses = [
        const SelectedVerse(
          bookName: '창세기',
          chapter: 1,
          verse: 1,
          text: '태초에 하나님이 천지를 창조하시니라',
        ),
        const SelectedVerse(
          bookName: '창세기',
          chapter: 1,
          verse: 3,
          text: '하나님이 이르시되 빛이 있으라 하시니 빛이 있었고',
        ),
        const SelectedVerse(
          bookName: '창세기',
          chapter: 1,
          verse: 4,
          text: '빛이 하나님이 보시기에 좋았더라',
        ),
      ];

      final expected =
          '창세기 1:1, 1:3-4\n\n'
          '[1:1] 태초에 하나님이 천지를 창조하시니라\n'
          '[1:3] 하나님이 이르시되 빛이 있으라 하시니 빛이 있었고\n'
          '[1:4] 빛이 하나님이 보시기에 좋았더라';

      expect(VerseExportFormatter.format(verses), expected);
    });

    test('format formats multi-chapter and multi-book scenarios correctly', () {
      final verses = [
        const SelectedVerse(
          bookName: '창세기',
          chapter: 1,
          verse: 1,
          text: '태초에...',
        ),
        const SelectedVerse(
          bookName: '창세기',
          chapter: 1,
          verse: 3,
          text: '빛이...',
        ),
        const SelectedVerse(
          bookName: '창세기',
          chapter: 2,
          verse: 1,
          text: '천지와...',
        ),
        const SelectedVerse(
          bookName: '출애굽기',
          chapter: 1,
          verse: 1,
          text: '야곱과...',
        ),
      ];

      final expected =
          '창세기 1:1, 1:3, 2:1; 출애굽기 1:1\n\n'
          '[1:1] 태초에...\n'
          '[1:3] 빛이...\n'
          '[2:1] 천지와...\n'
          '[1:1] 야곱과...';

      expect(VerseExportFormatter.format(verses), expected);
    });
  });
}
