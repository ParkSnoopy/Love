import 'package:flutter_riverpod/flutter_riverpod.dart';

class VerseKey {
  const VerseKey({
    required this.bookId,
    required this.chapter,
    required this.verse,
  });

  final int bookId;
  final int chapter;
  final int verse;

  @override
  bool operator ==(Object other) {
    return other is VerseKey &&
        other.bookId == bookId &&
        other.chapter == chapter &&
        other.verse == verse;
  }

  @override
  int get hashCode => Object.hash(bookId, chapter, verse);
}

enum SelectionMode { none, single, multi }

class VerseSelectionState {
  const VerseSelectionState({required this.mode, required this.selected});

  final SelectionMode mode;
  final Set<VerseKey> selected;

  VerseKey? get single => selected.length == 1 ? selected.first : null;

  static const empty = VerseSelectionState(
    mode: SelectionMode.none,
    selected: <VerseKey>{},
  );
}

final verseSelectionProvider =
    NotifierProvider<VerseSelectionController, VerseSelectionState>(
      VerseSelectionController.new,
    );

class VerseSelectionController extends Notifier<VerseSelectionState> {
  @override
  VerseSelectionState build() => VerseSelectionState.empty;

  void tap(VerseKey key) {
    if (state.mode == SelectionMode.multi) {
      final next = {...state.selected};
      if (next.contains(key)) {
        next.remove(key);
      } else {
        next.add(key);
      }
      state = next.isEmpty
          ? VerseSelectionState.empty
          : VerseSelectionState(mode: SelectionMode.multi, selected: next);
      return;
    }

    if (state.mode == SelectionMode.single) {
      if (state.selected.contains(key)) {
        state = VerseSelectionState.empty;
      } else {
        state = VerseSelectionState(
          mode: SelectionMode.single,
          selected: {key},
        );
      }
      return;
    }

    state = VerseSelectionState(mode: SelectionMode.single, selected: {key});
  }

  void longPress(VerseKey key) {
    final next = {...state.selected, key};
    state = VerseSelectionState(mode: SelectionMode.multi, selected: next);
  }

  void clear() {
    state = VerseSelectionState.empty;
  }
}

class TargetScrollVerseController extends Notifier<VerseKey?> {
  @override
  VerseKey? build() => null;

  set state(VerseKey? value) => super.state = value;
}

final targetScrollVerseProvider =
    NotifierProvider<TargetScrollVerseController, VerseKey?>(
      TargetScrollVerseController.new,
    );

class TargetScrollCommentaryVerseController extends Notifier<int?> {
  @override
  int? build() => null;

  set state(int? value) => super.state = value;
}

final targetScrollCommentaryVerseProvider =
    NotifierProvider<TargetScrollCommentaryVerseController, int?>(
      TargetScrollCommentaryVerseController.new,
    );
