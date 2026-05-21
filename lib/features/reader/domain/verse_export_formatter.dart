class SelectedVerse {
  const SelectedVerse({
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.text,
  });

  final String bookName;
  final int chapter;
  final int verse;
  final String text;
}

class VerseExportFormatter {
  static String format(List<SelectedVerse> verses) {
    if (verses.isEmpty) return '';

    // Group by book name, preserving order of first appearance
    final List<String> bookOrder = [];
    final Map<String, List<SelectedVerse>> booksGroup = {};
    for (final v in verses) {
      if (!booksGroup.containsKey(v.bookName)) {
        bookOrder.add(v.bookName);
        booksGroup[v.bookName] = [];
      }
      booksGroup[v.bookName]!.add(v);
    }

    final List<String> bookSummaries = [];
    for (final bookName in bookOrder) {
      final bookVerses = booksGroup[bookName]!;
      bookVerses.sort((a, b) {
        final c = a.chapter.compareTo(b.chapter);
        if (c != 0) return c;
        return a.verse.compareTo(b.verse);
      });

      // Group by chapter
      final Map<int, List<int>> chapterGroups = {};
      final List<int> chapterOrder = [];
      for (final v in bookVerses) {
        if (!chapterGroups.containsKey(v.chapter)) {
          chapterOrder.add(v.chapter);
          chapterGroups[v.chapter] = [];
        }
        chapterGroups[v.chapter]!.add(v.verse);
      }

      final List<String> chapterRanges = [];
      for (final chapter in chapterOrder) {
        final sortedVerses = chapterGroups[chapter]!..sort();
        final ranges = _groupContiguous(sortedVerses);
        for (final r in ranges) {
          chapterRanges.add('$chapter:$r');
        }
      }

      bookSummaries.add('$bookName ${chapterRanges.join(', ')}');
    }

    final header = bookSummaries.join('; ');

    // For body, sort verses globally by book, chapter, then verse
    final sorted = [...verses]
      ..sort((a, b) {
        final bookAIdx = bookOrder.indexOf(a.bookName);
        final bookBIdx = bookOrder.indexOf(b.bookName);
        final bookCompare = bookAIdx.compareTo(bookBIdx);
        if (bookCompare != 0) return bookCompare;

        final c = a.chapter.compareTo(b.chapter);
        if (c != 0) return c;
        return a.verse.compareTo(b.verse);
      });
    final body = sorted
        .map((v) => '[${v.chapter}:${v.verse}] ${v.text}')
        .join('\n');

    return '$header\n\n$body';
  }

  static String formatVerseNumbers(List<int> verseNumbers) {
    if (verseNumbers.isEmpty) return '';
    final sorted = [...verseNumbers]..sort();
    return _groupContiguous(sorted).join(', ');
  }

  static List<String> _groupContiguous(List<int> sorted) {
    if (sorted.isEmpty) return [];
    final List<String> ranges = [];
    int start = sorted[0];
    int prev = sorted[0];
    for (int i = 1; i < sorted.length; i++) {
      int current = sorted[i];
      if (current == prev + 1) {
        prev = current;
      } else {
        if (start == prev) {
          ranges.add('$start');
        } else {
          ranges.add('$start-$prev');
        }
        start = current;
        prev = current;
      }
    }
    if (start == prev) {
      ranges.add('$start');
    } else {
      ranges.add('$start-$prev');
    }
    return ranges;
  }
}
