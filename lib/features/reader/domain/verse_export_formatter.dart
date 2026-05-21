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
    final sorted = [...verses]..sort((a, b) {
      final c = a.chapter.compareTo(b.chapter);
      if (c != 0) return c;
      return a.verse.compareTo(b.verse);
    });

    final first = sorted.first;
    final last = sorted.last;
    final sameChapter = first.chapter == last.chapter;
    final range = sameChapter
        ? '${first.chapter}:${first.verse}-${last.verse}'
        : '${first.chapter}:${first.verse}-${last.chapter}:${last.verse}';

    final header = '${first.bookName} $range';
    final body = sorted.map((v) => '[${v.chapter}:${v.verse}] ${v.text}').join('\n');
    return '$header\n\n$body';
  }
}
