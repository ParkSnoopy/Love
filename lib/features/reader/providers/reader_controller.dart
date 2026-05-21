import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/reader_repository.dart';
import '../../../data/storage/db_path_provider.dart';

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

  Future<void> nextChapter() async {
    final dbPath = await ref.read(activeDbPathProvider.future);
    if (dbPath == null) return;

    const repo = ReaderRepository();
    final maxChapter = repo.loadMaxChapter(
      dbPath: dbPath,
      bookId: state.bookId,
    );

    if (state.chapter < maxChapter) {
      state = ReaderRef(bookId: state.bookId, chapter: state.chapter + 1);
    } else {
      final maxBook = repo.loadMaxBook(dbPath: dbPath);
      if (state.bookId < maxBook) {
        state = ReaderRef(bookId: state.bookId + 1, chapter: 1);
      }
    }
  }

  Future<void> prevChapter() async {
    final dbPath = await ref.read(activeDbPathProvider.future);
    if (dbPath == null) return;

    if (state.chapter > 1) {
      state = ReaderRef(bookId: state.bookId, chapter: state.chapter - 1);
    } else {
      if (state.bookId > 1) {
        const repo = ReaderRepository();
        final prevBookId = state.bookId - 1;
        final maxChapterPrev = repo.loadMaxChapter(
          dbPath: dbPath,
          bookId: prevBookId,
        );
        state = ReaderRef(bookId: prevBookId, chapter: maxChapterPrev);
      }
    }
  }

  void jumpTo({required int bookId, required int chapter}) {
    state = ReaderRef(bookId: bookId, chapter: chapter);
  }
}
