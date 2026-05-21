import 'package:flutter_test/flutter_test.dart';

import '../lib/data/import/bible_ref_parser.dart';
import '../lib/data/import/import_exception.dart';

void main() {
  test('parse single reference John 3:16', () {
    const aliases = {'John': 43, 'Jn': 43};
    final parser = BibleRefParser(bookAliases: aliases);

    final refs = parser.parse('John 3:16');

    expect(refs.length, 1);
    expect(refs.first.bookId, 43);
    expect(refs.first.chapterStart, 3);
    expect(refs.first.verseStart, 16);
    expect(refs.first.chapterEnd, 3);
    expect(refs.first.verseEnd, 16);
  });

  test('parse same-chapter range John 3:16-18', () {
    const aliases = {'John': 43};
    final parser = BibleRefParser(bookAliases: aliases);

    final refs = parser.parse('John 3:16-18');

    expect(refs.single.bookId, 43);
    expect(refs.single.chapterStart, 3);
    expect(refs.single.verseStart, 16);
    expect(refs.single.chapterEnd, 3);
    expect(refs.single.verseEnd, 18);
  });

  test('parse cross-chapter range John 3:16-4:2', () {
    const aliases = {'John': 43};
    final parser = BibleRefParser(bookAliases: aliases);

    final refs = parser.parse('John 3:16-4:2');

    expect(refs.single.bookId, 43);
    expect(refs.single.chapterStart, 3);
    expect(refs.single.verseStart, 16);
    expect(refs.single.chapterEnd, 4);
    expect(refs.single.verseEnd, 2);
  });

  test('parse comma list John 3:16,18,20', () {
    const aliases = {'John': 43};
    final parser = BibleRefParser(bookAliases: aliases);

    final refs = parser.parse('John 3:16,18,20');

    expect(refs.length, 3);
    expect(refs.map((r) => r.verseStart).toList(), [16, 18, 20]);
    expect(refs.every((r) => r.chapterStart == 3 && r.chapterEnd == 3), isTrue);
  });

  test('unknown book alias throws strict error', () {
    final parser = BibleRefParser(bookAliases: const {'John': 43});

    expect(
      () => parser.parse('Joh 3:16'),
      throwsA(isA<ImportException>().having((e) => e.code, 'code', 'REF_UNKNOWN_BOOK')),
    );
  });
}
