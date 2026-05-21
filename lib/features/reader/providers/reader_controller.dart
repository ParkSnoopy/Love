import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReaderRef {
  const ReaderRef({required this.bookId, required this.chapter});

  final int bookId;
  final int chapter;
}

final readerRefProvider = NotifierProvider<ReaderRefController, ReaderRef>(
  ReaderRefController.new,
);

class ReaderRefController extends Notifier<ReaderRef> {
  @override
  ReaderRef build() => const ReaderRef(bookId: 1, chapter: 1);

  void nextChapter() {
    state = ReaderRef(bookId: state.bookId, chapter: state.chapter + 1);
  }

  void prevChapter() {
    final next = state.chapter > 1 ? state.chapter - 1 : 1;
    state = ReaderRef(bookId: state.bookId, chapter: next);
  }
}
