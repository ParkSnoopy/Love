import 'package:flutter_test/flutter_test.dart';

import '../lib/features/reader/domain/verse_export_formatter.dart';

void main() {
  test('formats selected verses to required export shape', () {
    const lines = [
      SelectedVerse(
        bookName: 'John',
        chapter: 3,
        verse: 16,
        text: 'For God so loved the world',
      ),
      SelectedVerse(
        bookName: 'John',
        chapter: 3,
        verse: 17,
        text: 'For God sent not his Son',
      ),
    ];

    final out = VerseExportFormatter.format(lines);

    expect(
      out,
      'John 3:16-17\n\n[3:16] For God so loved the world\n[3:17] For God sent not his Son',
    );
  });
}
