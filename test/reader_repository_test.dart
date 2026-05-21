import 'package:flutter_test/flutter_test.dart';

import '../lib/features/reader/data/reader_repository.dart';

void main() {
  test('reader repository loads Genesis 1:1 from real KJV db', () {
    const repo = ReaderRepository();

    final verses = repo.loadChapter(
      dbPath: 'assets/data/getbible/en_kjv.sqlite',
      bookId: 1,
      chapter: 1,
    );

    expect(verses.isNotEmpty, isTrue);
    expect(verses.first.verse, 1);
    expect(
      verses.first.text,
      contains('In the beginning God created the heaven and the earth.'),
    );
  });
}
