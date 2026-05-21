import 'import_exception.dart';

class VerseRefRange {
  const VerseRefRange({
    required this.bookId,
    required this.chapterStart,
    required this.verseStart,
    required this.chapterEnd,
    required this.verseEnd,
  });

  final int bookId;
  final int chapterStart;
  final int verseStart;
  final int chapterEnd;
  final int verseEnd;
}

class BibleRefParser {
  BibleRefParser({required Map<String, int> bookAliases})
    : _aliases = bookAliases;

  final Map<String, int> _aliases;

  List<VerseRefRange> parse(String input) {
    final main = RegExp(
      r'^\s*([1-3]?[A-Za-z]+)\s+(\d+):(\d+)(.*)\s*$',
    ).firstMatch(input);
    if (main == null) {
      throw ImportException(
        code: 'REF_PARSE_FAIL',
        message: 'Unable to parse bible reference',
        phase: 'Parse References',
        detail: input,
      );
    }

    final book = main.group(1)!;
    final bookId = _aliases[book];
    if (bookId == null) {
      throw ImportException(
        code: 'REF_UNKNOWN_BOOK',
        message: 'Unknown book alias: $book',
        phase: 'Parse References',
        detail: input,
      );
    }

    final chapter = int.parse(main.group(2)!);
    final verse = int.parse(main.group(3)!);
    final tail = (main.group(4) ?? '').trim();

    if (tail.isEmpty) {
      return [
        VerseRefRange(
          bookId: bookId,
          chapterStart: chapter,
          verseStart: verse,
          chapterEnd: chapter,
          verseEnd: verse,
        ),
      ];
    }

    if (tail.startsWith('-')) {
      final rhs = tail.substring(1).trim();
      final sameChapter = RegExp(r'^(\d+)$').firstMatch(rhs);
      if (sameChapter != null) {
        final endVerse = int.parse(sameChapter.group(1)!);
        return [
          VerseRefRange(
            bookId: bookId,
            chapterStart: chapter,
            verseStart: verse,
            chapterEnd: chapter,
            verseEnd: endVerse,
          ),
        ];
      }

      final crossChapter = RegExp(r'^(\d+):(\d+)$').firstMatch(rhs);
      if (crossChapter != null) {
        final endChapter = int.parse(crossChapter.group(1)!);
        final endVerse = int.parse(crossChapter.group(2)!);
        return [
          VerseRefRange(
            bookId: bookId,
            chapterStart: chapter,
            verseStart: verse,
            chapterEnd: endChapter,
            verseEnd: endVerse,
          ),
        ];
      }
    }

    if (tail.startsWith(',')) {
      final list = tail
          .substring(1)
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty);
      final out = <VerseRefRange>[
        VerseRefRange(
          bookId: bookId,
          chapterStart: chapter,
          verseStart: verse,
          chapterEnd: chapter,
          verseEnd: verse,
        ),
      ];
      for (final token in list) {
        final v = int.tryParse(token);
        if (v == null) {
          throw ImportException(
            code: 'REF_PARSE_FAIL',
            message: 'Unable to parse bible reference',
            phase: 'Parse References',
            detail: input,
          );
        }
        out.add(
          VerseRefRange(
            bookId: bookId,
            chapterStart: chapter,
            verseStart: v,
            chapterEnd: chapter,
            verseEnd: v,
          ),
        );
      }
      return out;
    }

    throw ImportException(
      code: 'REF_PARSE_FAIL',
      message: 'Unable to parse bible reference',
      phase: 'Parse References',
      detail: input,
    );
  }
}
