import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/app_preferences.dart';
import '../data/reader_repository.dart';
import '../../../data/storage/db_path_provider.dart';

class ReaderRef {
  const ReaderRef({required this.bookId, required this.chapter});

  final int bookId;
  final int chapter;
}

final readerRefProvider = AsyncNotifierProvider<ReaderRefController, ReaderRef>(
  ReaderRefController.new,
);

class ReaderRefController extends AsyncNotifier<ReaderRef> {
  static const _prefsKeyBookId = 'reader_book_id';
  static const _prefsKeyChapter = 'reader_chapter';

  @override
  Future<ReaderRef> build() async {
    final dbPath = await ref.watch(activeDbPathProvider.future);
    final prefs = await AppPreferences.getInstance();
    var bookId = prefs.getInt(_prefsKeyBookId) ?? 1;
    var chapter = prefs.getInt(_prefsKeyChapter) ?? 1;

    // Validate and clamp to database limits
    if (dbPath != null) {
      const repo = ReaderRepository();
      final maxBook = repo.loadMaxBook(dbPath: dbPath);
      if (bookId > maxBook) {
        bookId = 1;
        chapter = 1;
      } else {
        final maxChapter = repo.loadMaxChapter(dbPath: dbPath, bookId: bookId);
        if (chapter > maxChapter) {
          chapter = maxChapter;
        }
      }
    }
    return ReaderRef(bookId: bookId, chapter: chapter);
  }

  Future<void> nextChapter() async {
    final dbPath = await ref.read(activeDbPathProvider.future);
    if (dbPath == null) return;

    final current = state.value;
    if (current == null) return;

    const repo = ReaderRepository();
    final maxChapter = repo.loadMaxChapter(
      dbPath: dbPath,
      bookId: current.bookId,
    );

    ReaderRef next;
    if (current.chapter < maxChapter) {
      next = ReaderRef(bookId: current.bookId, chapter: current.chapter + 1);
    } else {
      final maxBook = repo.loadMaxBook(dbPath: dbPath);
      if (current.bookId < maxBook) {
        next = ReaderRef(bookId: current.bookId + 1, chapter: 1);
      } else {
        return; // End of Bible
      }
    }

    state = AsyncData(next);
    await _save(next);
  }

  Future<void> prevChapter() async {
    final dbPath = await ref.read(activeDbPathProvider.future);
    if (dbPath == null) return;

    final current = state.value;
    if (current == null) return;

    ReaderRef prev;
    if (current.chapter > 1) {
      prev = ReaderRef(bookId: current.bookId, chapter: current.chapter - 1);
    } else {
      if (current.bookId > 1) {
        const repo = ReaderRepository();
        final prevBookId = current.bookId - 1;
        final maxChapterPrev = repo.loadMaxChapter(
          dbPath: dbPath,
          bookId: prevBookId,
        );
        prev = ReaderRef(bookId: prevBookId, chapter: maxChapterPrev);
      } else {
        return; // Beginning of Bible
      }
    }

    state = AsyncData(prev);
    await _save(prev);
  }

  Future<void> jumpTo({required int bookId, required int chapter}) async {
    final next = ReaderRef(bookId: bookId, chapter: chapter);
    state = AsyncData(next);
    await _save(next);
  }

  Future<void> _save(ReaderRef refVal) async {
    final prefs = await AppPreferences.getInstance();
    await prefs.setInt(_prefsKeyBookId, refVal.bookId);
    await prefs.setInt(_prefsKeyChapter, refVal.chapter);
  }
}
