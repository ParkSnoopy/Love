import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../lib/features/reader/providers/verse_selection_controller.dart';

void main() {
  test('tap enters single mode', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final key = VerseKey(bookId: 1, chapter: 1, verse: 1);

    c.read(verseSelectionProvider.notifier).tap(key);
    final s = c.read(verseSelectionProvider);

    expect(s.mode, SelectionMode.single);
    expect(s.selected, {key});
  });

  test('long press enters multi mode; tap toggles in multi', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final a = VerseKey(bookId: 1, chapter: 1, verse: 1);
    final b = VerseKey(bookId: 1, chapter: 1, verse: 2);

    c.read(verseSelectionProvider.notifier).longPress(a);
    c.read(verseSelectionProvider.notifier).tap(b);
    var s = c.read(verseSelectionProvider);
    expect(s.mode, SelectionMode.multi);
    expect(s.selected, {a, b});

    c.read(verseSelectionProvider.notifier).tap(a);
    s = c.read(verseSelectionProvider);
    expect(s.mode, SelectionMode.multi);
    expect(s.selected, {b});
  });

  test('clear resets state', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(verseSelectionProvider.notifier).longPress(
      VerseKey(bookId: 1, chapter: 1, verse: 1),
    );

    c.read(verseSelectionProvider.notifier).clear();
    final s = c.read(verseSelectionProvider);
    expect(s.mode, SelectionMode.none);
    expect(s.selected, isEmpty);
  });
}
