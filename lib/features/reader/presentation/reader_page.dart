import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException, sqlite3, OpenMode;

import '../domain/verse_export_formatter.dart';
import '../data/reader_repository.dart';
import '../providers/reader_controller.dart';
import '../providers/verse_selection_controller.dart';
import '../../study/providers/user_data_controller.dart';
import '../../study/data/user_data_repository.dart';
import '../../../data/storage/db_path_provider.dart';
import '../../library/providers/library_controller.dart';
import '../../library/domain/bible_pack.dart';
import '../../library/domain/manifest_repository.dart';
import '../providers/commentary_visibility_provider.dart';
import 'commentary_intro_sheet.dart';
import 'verse_action_pane.dart';
import '../../../app/reader_settings_controller.dart';
import '../../../app/font_controller.dart';
import '../../../app/app_localizations.dart';

class CommentaryFullScreenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void setFullScreen(bool value) => state = value;
}

final commentaryFullScreenProvider =
    NotifierProvider<CommentaryFullScreenNotifier, bool>(
      CommentaryFullScreenNotifier.new,
    );

class ReaderPage extends ConsumerWidget {
  const ReaderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbPathAsync = ref.watch(activeDbPathProvider);

    return dbPathAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) =>
          Scaffold(body: Center(child: Text(context.l10n.error(err)))),
      data: (dbPath) {
        if (dbPath == null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.l10n.t('noBibleSelected'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return _ReaderContentView(dbPath: dbPath);
      },
    );
  }
}

class _ReaderContentView extends ConsumerStatefulWidget {
  const _ReaderContentView({required this.dbPath});

  final String dbPath;

  @override
  ConsumerState<_ReaderContentView> createState() => _ReaderContentViewState();
}

class _ReaderContentViewState extends ConsumerState<_ReaderContentView> {
  final Map<VerseKey, GlobalKey> _verseKeys = {};
  final ScrollController _readerScrollController = ScrollController();
  int? _lastBookId;
  int? _lastChapter;

  GlobalKey _getKeyForVerse(VerseKey key) {
    return _verseKeys.putIfAbsent(key, () => GlobalKey());
  }

  Future<void> _changeChapterAndScrollToTop(
    ReaderRef current,
    Future<void> Function() changeChapter,
  ) async {
    await changeChapter();
    if (!mounted) return;

    final next = ref.read(readerRefProvider).value;
    if (next == null ||
        (next.bookId == current.bookId && next.chapter == current.chapter)) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_readerScrollController.hasClients) return;
      _readerScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _readerScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rrAsync = ref.watch(readerRefProvider);

    ref.listen<bool>(commentaryVisibilityProvider, (prev, next) {
      if (!next) {
        ref.read(commentaryFullScreenProvider.notifier).setFullScreen(false);
      }
    });

    ref.listen<VerseSelectionState>(verseSelectionProvider, (prev, next) {
      if (next.mode != SelectionMode.none) {
        ref.read(commentaryVisibilityProvider.notifier).hide();
      }
    });

    return rrAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) =>
          Scaffold(body: Center(child: Text(context.l10n.error(err)))),
      data: (rr) {
        // Clear keys if chapter changed
        if (_lastBookId != rr.bookId || _lastChapter != rr.chapter) {
          _verseKeys.clear();
          _lastBookId = rr.bookId;
          _lastChapter = rr.chapter;
        }

        final selection = ref.watch(verseSelectionProvider);
        final userDataRepo = ref.watch(userDataRepositoryProvider);
        final userDataDbPath = ref.watch(userDataDbPathProvider).value ?? '';
        final activeCommentaryDbPath = ref
            .watch(activeCommentaryDbPathProvider)
            .asData
            ?.value;
        final isCommentaryVisible = ref.watch(commentaryVisibilityProvider);
        final isCommentaryActive =
            activeCommentaryDbPath != null && isCommentaryVisible;
        final isFullScreen = ref.watch(commentaryFullScreenProvider);
        final activeBible = ref
            .watch(activeBibleSelectionProvider)
            .asData
            ?.value;
        final l10n = context.l10n;
        final activeBibleName = activeBible?.name ?? l10n.t('unknownBible');

        final bookmarksAsync = ref.watch(bookmarksProvider);
        final bookmarkedVerses =
            bookmarksAsync.value
                ?.where((b) => b.bookId == rr.bookId && b.chapter == rr.chapter)
                .map((b) => b.verse)
                .toSet() ??
            const <int>{};

        final highlightsAsync = ref.watch(highlightsProvider);
        final highlights =
            highlightsAsync.value
                ?.where((h) => h.bookId == rr.bookId && h.chapter == rr.chapter)
                .toList() ??
            const <HighlightEntry>[];

        final readerSettingsAsync = ref.watch(readerSettingsProvider);
        final readerSettings =
            readerSettingsAsync.value ??
            const ReaderSettingsState(fontSize: 18.0, lineSpacing: 1.5);

        // Check if we need to scroll to a verse
        final targetScroll = ref.watch(targetScrollVerseProvider);
        if (targetScroll != null &&
            targetScroll.bookId == rr.bookId &&
            targetScroll.chapter == rr.chapter) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final key = _verseKeys[targetScroll];
            if (key != null && key.currentContext != null) {
              Scrollable.ensureVisible(
                key.currentContext!,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
              ref.read(targetScrollVerseProvider.notifier).state = null;
            }
          });
        }

        const repo = ReaderRepository();
        var verses = const <VerseLine>[];
        var bookName = l10n.t('bible');
        var hasCurrentChapterCommentary = true;
        String? loadError;
        try {
          verses = repo.loadChapter(
            dbPath: widget.dbPath,
            bookId: rr.bookId,
            chapter: rr.chapter,
          );
          bookName = repo.loadBookName(
            dbPath: widget.dbPath,
            bookId: rr.bookId,
          );
          if (activeCommentaryDbPath != null) {
            try {
              hasCurrentChapterCommentary = repo.hasCommentaryForChapter(
                dbPath: activeCommentaryDbPath,
                bookId: rr.bookId,
                chapter: rr.chapter,
              );
            } on SqliteException {
              hasCurrentChapterCommentary = true;
            }
          }
        } on SqliteException catch (e) {
          loadError = l10n.dbError(e.message, widget.dbPath);
        }
        final selectedVerseLines = verses
            .where(
              (v) => selection.selected.contains(
                VerseKey(bookId: v.bookId, chapter: v.chapter, verse: v.verse),
              ),
            )
            .map(
              (v) => SelectedVerse(
                bookName: bookName,
                chapter: v.chapter,
                verse: v.verse,
                text: v.text,
              ),
            )
            .toList(growable: false);

        return Scaffold(
          appBar: AppBar(
            title: InkWell(
              onTap: () => _showPicker(
                context,
                rr,
                widget.dbPath,
                activeBibleName,
                onSelected: (bookId, chapter) => _changeChapterAndScrollToTop(
                  rr,
                  () => ref
                      .read(readerRefProvider.notifier)
                      .jumpTo(bookId: bookId, chapter: chapter),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$bookName ${rr.chapter}'),
                        Text(
                          activeBibleName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
            actions: [
              IconButton(
                tooltip: l10n.t('toggleCommentary'),
                icon: _CommentaryActionIcon(
                  isVisible: isCommentaryActive,
                  hasActiveCommentary: activeCommentaryDbPath != null,
                  hasCurrentChapterCommentary: hasCurrentChapterCommentary,
                ),
                onPressed: () {
                  final activeCommentary = ref
                      .read(activeCommentarySelectionProvider)
                      .asData
                      ?.value;
                  if (activeCommentary == null) {
                    showModalBottomSheet<void>(
                      context: context,
                      builder: (ctx) => CommentarySelectionSheet(
                        onSelected: () => Navigator.of(ctx).pop(),
                      ),
                    );
                  } else {
                    ref.read(commentaryVisibilityProvider.notifier).toggle();
                  }
                },
              ),
              IconButton(
                onPressed: () => _changeChapterAndScrollToTop(
                  rr,
                  () => ref.read(readerRefProvider.notifier).prevChapter(),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                onPressed: () => _changeChapterAndScrollToTop(
                  rr,
                  () => ref.read(readerRefProvider.notifier).nextChapter(),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          body: Column(
            children: [
              if (!isFullScreen)
                Expanded(
                  child: loadError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(loadError, textAlign: TextAlign.center),
                          ),
                        )
                      : SingleChildScrollView(
                          key: const PageStorageKey<String>('reader-scroll'),
                          controller: _readerScrollController,
                          child: Column(
                            children: verses.map((v) {
                              final key = VerseKey(
                                bookId: v.bookId,
                                chapter: v.chapter,
                                verse: v.verse,
                              );
                              final selected = selection.selected.contains(key);
                              final previousSelected = selection.selected
                                  .contains(
                                    VerseKey(
                                      bookId: v.bookId,
                                      chapter: v.chapter,
                                      verse: v.verse - 1,
                                    ),
                                  );
                              final nextSelected = selection.selected.contains(
                                VerseKey(
                                  bookId: v.bookId,
                                  chapter: v.chapter,
                                  verse: v.verse + 1,
                                ),
                              );
                              final isBookmarked = bookmarkedVerses.contains(
                                v.verse,
                              );

                              final matchingHighlight = highlights.firstWhere(
                                (h) =>
                                    v.verse >= h.verseStart &&
                                    v.verse <= h.verseEnd,
                                orElse: () => const HighlightEntry(
                                  id: -1,
                                  bookId: 0,
                                  chapter: 0,
                                  verseStart: 0,
                                  verseEnd: 0,
                                  color: '',
                                  createdAt: 0,
                                ),
                              );

                              Color? textColor;
                              if (matchingHighlight.id != -1) {
                                final isDark =
                                    Theme.of(context).brightness ==
                                    Brightness.dark;
                                textColor = switch (matchingHighlight.color) {
                                  'yellow' =>
                                    isDark
                                        ? Colors.yellow[300]
                                        : const Color(0xFFB58900),
                                  'green' =>
                                    isDark
                                        ? Colors.green[300]
                                        : Colors.green[700],
                                  'red' =>
                                    isDark ? Colors.red[300] : Colors.red[700],
                                  _ =>
                                    isDark
                                        ? Colors.yellow[300]
                                        : const Color(0xFFB58900),
                                };
                              }

                              return DecoratedBox(
                                key: _getKeyForVerse(key),
                                decoration: selected
                                    ? _selectedVerseDecoration(
                                        context,
                                        previousSelected: previousSelected,
                                        nextSelected: nextSelected,
                                      )
                                    : const BoxDecoration(),
                                child: ListTile(
                                  selected: selected,
                                  selectedTileColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: _selectedVerseBorderRadius(
                                      previousSelected: previousSelected,
                                      nextSelected: nextSelected,
                                    ),
                                  ),
                                  onTap: () {
                                    ref
                                        .read(verseSelectionProvider.notifier)
                                        .tap(key);
                                    userDataRepo.addHistory(
                                      dbPath: userDataDbPath,
                                      bookId: v.bookId,
                                      chapter: v.chapter,
                                      verse: v.verse,
                                      visitedAt:
                                          DateTime.now().millisecondsSinceEpoch,
                                    );
                                  },
                                  onLongPress: () => ref
                                      .read(verseSelectionProvider.notifier)
                                      .longPress(key),
                                  title: Text.rich(
                                    TextSpan(
                                      style: TextStyle(
                                        fontSize: readerSettings.fontSize,
                                        height: readerSettings.lineSpacing,
                                        color: textColor,
                                      ),
                                      children: [
                                        if (isBookmarked)
                                          const WidgetSpan(
                                            alignment:
                                                PlaceholderAlignment.middle,
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                right: 4.0,
                                              ),
                                              child: Icon(
                                                Icons.bookmark,
                                                color: Colors.amber,
                                                size: 14,
                                              ),
                                            ),
                                          ),
                                        TextSpan(
                                          text: '${v.verse} ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color:
                                                textColor ??
                                                Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                            fontSize:
                                                readerSettings.fontSize * 0.75,
                                          ),
                                        ),
                                        TextSpan(text: v.text),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                ),
              if (isCommentaryActive)
                Expanded(
                  flex: isFullScreen ? 1 : 2,
                  child: CommentaryPane(
                    dbPath: activeCommentaryDbPath,
                    bibleDbPath: widget.dbPath,
                    bookId: rr.bookId,
                    chapter: rr.chapter,
                    hasCurrentChapterCommentary: hasCurrentChapterCommentary,
                  ),
                ),
            ],
          ),
          bottomNavigationBar: selection.mode != SelectionMode.none
              ? VerseActionPane(
                  selectedVerses: selectedVerseLines,
                  bookName: bookName,
                  chapter: rr.chapter,
                  bookId: rr.bookId,
                )
              : null,
        );
      },
    );
  }
}

BoxDecoration _selectedVerseDecoration(
  BuildContext context, {
  required bool previousSelected,
  required bool nextSelected,
}) {
  final side = BorderSide(
    color: Theme.of(context).colorScheme.primary,
    width: 1.5,
  );

  return BoxDecoration(
    borderRadius: _selectedVerseBorderRadius(
      previousSelected: previousSelected,
      nextSelected: nextSelected,
    ),
    border: Border(
      left: side,
      top: previousSelected ? BorderSide.none : side,
      right: side,
      bottom: nextSelected ? BorderSide.none : side,
    ),
  );
}

BorderRadius _selectedVerseBorderRadius({
  required bool previousSelected,
  required bool nextSelected,
}) {
  const radius = Radius.circular(8);
  return BorderRadius.vertical(
    top: previousSelected ? Radius.zero : radius,
    bottom: nextSelected ? Radius.zero : radius,
  );
}

class _CommentaryActionIcon extends StatelessWidget {
  const _CommentaryActionIcon({
    required this.isVisible,
    required this.hasActiveCommentary,
    required this.hasCurrentChapterCommentary,
  });

  final bool isVisible;
  final bool hasActiveCommentary;
  final bool hasCurrentChapterCommentary;

  @override
  Widget build(BuildContext context) {
    final color = isVisible ? Theme.of(context).colorScheme.primary : null;
    if (hasActiveCommentary && !hasCurrentChapterCommentary) {
      final slashColor = color ?? IconTheme.of(context).color;
      return SizedBox.square(
        dimension: 24,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.comment_outlined, color: color),
            Transform.rotate(
              angle: -0.7,
              child: Container(
                width: 24,
                height: 2,
                decoration: BoxDecoration(
                  color: slashColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Icon(
      isVisible ? Icons.comment : Icons.comment_outlined,
      color: color,
    );
  }
}

void _showPicker(
  BuildContext context,
  ReaderRef rr,
  String dbPath,
  String bibleName, {
  required Future<void> Function(int bookId, int chapter) onSelected,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _BookChapterPicker(
      dbPath: dbPath,
      bibleName: bibleName,
      initialBookId: rr.bookId,
      initialChapter: rr.chapter,
      onSelected: (bookId, chapter) async {
        Navigator.of(ctx).pop();
        await onSelected(bookId, chapter);
      },
    ),
  );
}

class _BookChapterPicker extends StatefulWidget {
  const _BookChapterPicker({
    required this.dbPath,
    required this.bibleName,
    required this.initialBookId,
    required this.initialChapter,
    required this.onSelected,
  });

  final String dbPath;
  final String bibleName;
  final int initialBookId;
  final int initialChapter;
  final void Function(int bookId, int chapter) onSelected;

  @override
  State<_BookChapterPicker> createState() => _BookChapterPickerState();
}

class _BookChapterPickerState extends State<_BookChapterPicker> {
  late int _selectedBookId = widget.initialBookId;
  List<Map<String, dynamic>> _books = [];
  bool _loading = true;
  final ScrollController _booksScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadBooks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final idx = _books.indexWhere((b) => b['id'] == _selectedBookId);
      if (idx != -1 && _booksScrollController.hasClients) {
        _booksScrollController.jumpTo(idx * 48.0);
      }
    });
  }

  @override
  void dispose() {
    _booksScrollController.dispose();
    super.dispose();
  }

  void _scrollToBook(int index) {
    if (index >= 0 &&
        index < _books.length &&
        _booksScrollController.hasClients) {
      _booksScrollController.animateTo(
        index * 48.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _loadBooks() {
    final db = sqlite3.open(widget.dbPath, mode: OpenMode.readOnly);
    try {
      final columns = db
          .select('PRAGMA table_info(books)')
          .map((row) => row['name'] as String)
          .toSet();

      final nameNativeCol = columns.contains('name_native')
          ? 'name_native'
          : 'name';
      final nameEnCol = columns.contains('name_en') ? 'name_en' : 'eng_name';
      final chapterCol = columns.contains('chapter_count')
          ? 'chapter_count'
          : 'chapters';
      final hasTestament = columns.contains('testament');
      final testamentCol = hasTestament ? 'testament' : 'NULL';

      final rows = db.select(
        'SELECT book_id, $nameNativeCol, $nameEnCol, $chapterCol, $testamentCol AS testament FROM books ORDER BY book_id',
      );
      setState(() {
        _books = rows
            .map(
              (r) => <String, dynamic>{
                'id': r['book_id'],
                'name': (r[nameNativeCol] as String?)?.trim().isNotEmpty == true
                    ? r[nameNativeCol]
                    : r[nameEnCol],
                'count': r[chapterCol],
                'testament':
                    r['testament'] as String? ??
                    (r['book_id'] as int <= 39 ? 'OT' : 'NT'),
              },
            )
            .toList();
        _loading = false;
      });
    } finally {
      db.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final book = _books.firstWhere(
      (b) => b['id'] == _selectedBookId,
      orElse: () => _books.first,
    );
    final chapterCount = (book['count'] as int?) ?? 1;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.t('selectBookChapter'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.bibleName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: 8.0,
                          left: 8.0,
                          right: 8.0,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: () {
                                  final idx = _books.indexWhere(
                                    (b) => b['testament'] == 'OT',
                                  );
                                  if (idx != -1) _scrollToBook(idx);
                                },
                                child: Text(context.l10n.t('oldTestament')),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: () {
                                  final idx = _books.indexWhere(
                                    (b) => b['testament'] == 'NT',
                                  );
                                  if (idx != -1) _scrollToBook(idx);
                                },
                                child: Text(context.l10n.t('newTestament')),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: _booksScrollController,
                          itemExtent: 48.0,
                          itemCount: _books.length,
                          itemBuilder: (ctx, i) {
                            final b = _books[i];
                            return ListTile(
                              selected: _selectedBookId == b['id'],
                              title: Text(b['name']),
                              onTap: () => setState(() {
                                _selectedBookId = b['id'];
                              }),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 1,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                        ),
                    itemCount: chapterCount,
                    itemBuilder: (ctx, i) {
                      final ch = i + 1;
                      return InkWell(
                        onTap: () => widget.onSelected(_selectedBookId, ch),
                        child: Center(
                          child: Text(
                            '$ch',
                            style: TextStyle(
                              fontWeight:
                                  widget.initialChapter == ch &&
                                      widget.initialBookId == _selectedBookId
                                  ? FontWeight.bold
                                  : null,
                              color:
                                  widget.initialChapter == ch &&
                                      widget.initialBookId == _selectedBookId
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CommentaryPane extends ConsumerStatefulWidget {
  const CommentaryPane({
    super.key,
    required this.dbPath,
    required this.bibleDbPath,
    required this.bookId,
    required this.chapter,
    required this.hasCurrentChapterCommentary,
  });

  final String dbPath;
  final String bibleDbPath;
  final int bookId;
  final int chapter;
  final bool hasCurrentChapterCommentary;

  @override
  ConsumerState<CommentaryPane> createState() => _CommentaryPaneState();
}

class _CommentarySwitchOption {
  const _CommentarySwitchOption({required this.pack});

  final BiblePack pack;
}

class _CommentaryPaneState extends ConsumerState<CommentaryPane> {
  final _scrollController = ScrollController();
  Future<List<_CommentarySwitchOption>>? _alternativeCommentariesFuture;

  Future<List<_CommentarySwitchOption>>
  _findCommentariesForCurrentChapter() async {
    const manifestRepo = ManifestRepository();
    const readerRepo = ReaderRepository();
    final activeCommentary = ref
        .read(activeCommentarySelectionProvider)
        .asData
        ?.value;
    final packs = await manifestRepo.loadBiblePacksFromAsset();
    final matches = <_CommentarySwitchOption>[];

    for (final pack in packs.where((p) => p.type == 'commentary')) {
      if (pack.id == activeCommentary?.id ||
          pack.file == activeCommentary?.file) {
        continue;
      }
      final dbPath = await readerRepo.resolveDbPath(pack.file, type: pack.type);
      if (dbPath == null) continue;
      try {
        final hasCommentary = readerRepo.hasCommentaryForChapter(
          dbPath: dbPath,
          bookId: widget.bookId,
          chapter: widget.chapter,
        );
        if (hasCommentary) {
          matches.add(_CommentarySwitchOption(pack: pack));
        }
      } on SqliteException {
        continue;
      }
    }

    return matches;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CommentaryPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookId != widget.bookId ||
        oldWidget.chapter != widget.chapter ||
        oldWidget.dbPath != widget.dbPath ||
        oldWidget.hasCurrentChapterCommentary !=
            widget.hasCurrentChapterCommentary) {
      _alternativeCommentariesFuture = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    }
  }

  List<TextSpan> _parseHtmlToTextSpans(String html, TextStyle baseStyle) {
    var text = html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<p>', caseSensitive: false), '');

    final spans = <TextSpan>[];
    final tagRegex = RegExp(
      r'<(b|i)>(.*?)</\1>|<[^>]+>|([^<]+)',
      caseSensitive: false,
    );
    final matches = tagRegex.allMatches(text);

    for (final match in matches) {
      if (match.group(1) != null) {
        final tag = match.group(1)!.toLowerCase();
        final content = match.group(2) ?? '';
        spans.add(
          TextSpan(
            text: content,
            style: baseStyle.copyWith(
              fontWeight: tag == 'b' ? FontWeight.bold : null,
              fontStyle: tag == 'i' ? FontStyle.italic : null,
            ),
          ),
        );
      } else if (match.group(3) != null) {
        spans.add(TextSpan(text: match.group(3), style: baseStyle));
      }
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: baseStyle));
    }
    return spans;
  }

  void _startAlternativeCommentarySearch() {
    setState(() {
      _alternativeCommentariesFuture = _findCommentariesForCurrentChapter();
    });
  }

  Widget _buildAlternativeCommentarySearch(BuildContext context) {
    final future = _alternativeCommentariesFuture;
    if (widget.hasCurrentChapterCommentary && future == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      elevation: 0,
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.hasCurrentChapterCommentary) ...[
              Text(
                l10n.t('noCommentaryForChapter'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.manage_search),
                  label: Text(l10n.t('checkAnotherCommentaryDatabase')),
                  onPressed: _startAlternativeCommentarySearch,
                ),
              ),
            ],
            if (future != null) ...[
              const SizedBox(height: 8),
              FutureBuilder<List<_CommentarySwitchOption>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Row(
                      children: [
                        const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(l10n.t('searchingCommentaryDatabases')),
                      ],
                    );
                  }

                  if (snapshot.hasError) {
                    return Text(
                      '${l10n.t('commentaryError')}: ${snapshot.error}',
                      style: TextStyle(color: theme.colorScheme.error),
                    );
                  }

                  final matches =
                      snapshot.data ?? const <_CommentarySwitchOption>[];
                  if (matches.isEmpty) {
                    return Text(l10n.t('noOtherCommentaryForChapter'));
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n
                            .t('otherCommentariesFound')
                            .replaceAll('{count}', matches.length.toString()),
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      for (final option in matches)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.swap_horiz),
                            label: Text(
                              '${l10n.t('switchToCommentary')}: ${option.pack.shortName}',
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () async {
                              await ref
                                  .read(
                                    activeCommentarySelectionProvider.notifier,
                                  )
                                  .select(
                                    id: option.pack.id,
                                    file: option.pack.file,
                                    name: option.pack.name,
                                  );
                              ref
                                  .read(commentaryVisibilityProvider.notifier)
                                  .show();
                              if (mounted) {
                                setState(() {
                                  _alternativeCommentariesFuture = null;
                                });
                              }
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const repo = ReaderRepository();
    final l10n = context.l10n;
    List<CommentaryVerse> verses = [];
    String? err;
    try {
      verses = repo.loadCommentaryVerses(
        dbPath: widget.dbPath,
        bookId: widget.bookId,
        chapter: widget.chapter,
      );
    } catch (e) {
      err = '${l10n.t('commentaryError')}: $e';
    }

    final theme = Theme.of(context);
    final readerSettings =
        ref.watch(readerSettingsProvider).value ??
        const ReaderSettingsState(fontSize: 18.0, lineSpacing: 1.5);
    final fontType = ref.watch(fontTypeProvider).value ?? FontType.serif;
    final baseTextStyle =
        theme.textTheme.bodyMedium?.copyWith(
          fontFamily: fontFamilyForType(fontType),
          fontSize: readerSettings.fontSize,
          height: readerSettings.lineSpacing,
        ) ??
        TextStyle(
          fontFamily: fontFamilyForType(fontType),
          fontSize: readerSettings.fontSize,
          height: readerSettings.lineSpacing,
        );
    final activeCommentary = ref
        .watch(activeCommentarySelectionProvider)
        .asData
        ?.value;

    var bookName = repo.loadBookName(
      dbPath: widget.dbPath,
      bookId: widget.bookId,
    );
    if (widget.dbPath.contains('com_kor_') &&
        RegExp(r'^[a-zA-Z\s]+$').hasMatch(bookName)) {
      final names = bibleBookNames[widget.bookId];
      if (names != null && names.isNotEmpty) {
        bookName = names.last;
      }
    }
    final headerTitle = activeCommentary != null
        ? '${activeCommentary.name} - $bookName ${widget.chapter}'
        : '$bookName ${widget.chapter}';

    final isFullScreen = ref.watch(commentaryFullScreenProvider);
    final hasVerseComments = verses.any((v) => v.verse > 0);

    Widget contentWidget;
    if (err != null) {
      contentWidget = Padding(
        padding: const EdgeInsets.all(16),
        child: Text(err, style: const TextStyle(color: Colors.red)),
      );
    } else if (verses.isEmpty) {
      contentWidget = Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            l10n.t('noCommentaryForChapter'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else if (hasVerseComments) {
      final keys = <int, GlobalKey>{};
      for (final v in verses) {
        if (v.text.trim().isNotEmpty) {
          keys[v.verse] = GlobalKey();
        }
      }

      final targetVerse = ref.watch(targetScrollCommentaryVerseProvider);
      if (targetVerse != null && verses.isNotEmpty) {
        CommentaryVerse? targetComment;
        for (final cv in verses) {
          if (cv.text.trim().isEmpty) continue;
          if (cv.verse <= targetVerse) {
            if (targetComment == null || cv.verse > targetComment.verse) {
              targetComment = cv;
            }
          }
        }
        targetComment ??= verses.firstWhere(
          (cv) => cv.text.trim().isNotEmpty,
          orElse: () => verses.first,
        );
        final key = keys[targetComment.verse];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (key != null) {
            final context = key.currentContext;
            if (context != null) {
              Scrollable.ensureVisible(
                context,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          }
          ref.read(targetScrollCommentaryVerseProvider.notifier).state = null;
        });
      }

      contentWidget = Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          key: const PageStorageKey<String>('commentary-scroll'),
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              for (final v in verses)
                if (v.text.trim().isNotEmpty)
                  Card(
                    key: keys[v.verse],
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.verse == 0
                                ? l10n.t('chapterIntro')
                                : '${v.verse}${l10n.t('verseLabel')}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text.rich(
                            TextSpan(
                              style: baseTextStyle,
                              children: _parseHtmlToTextSpans(
                                v.text,
                                baseTextStyle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
      );
    } else {
      final intro = verses.firstWhere(
        (v) => v.verse == 0,
        orElse: () => verses.first,
      );
      contentWidget = Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          key: const PageStorageKey<String>('commentary-scroll'),
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          child: Text.rich(
            TextSpan(
              style: baseTextStyle,
              children: _parseHtmlToTextSpans(intro.text, baseTextStyle),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surfaceContainer,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    headerTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.manage_search, size: 18),
                  tooltip: l10n.t('checkAnotherCommentaryDatabase'),
                  onPressed: _startAlternativeCommentarySearch,
                ),
                if (activeCommentary != null)
                  IconButton(
                    icon: const Icon(Icons.menu_book, size: 18),
                    tooltip: context.l10n.t('viewIntro'),
                    onPressed: () {
                      showCommentaryIntros(
                        context,
                        activeCommentary.file,
                        activeCommentary.name,
                        widget.dbPath,
                      );
                    },
                  ),
                IconButton(
                  icon: Icon(
                    isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    size: 18,
                  ),
                  tooltip: isFullScreen
                      ? l10n.t('exitFullscreen')
                      : l10n.t('enterFullscreen'),
                  onPressed: () {
                    ref.read(commentaryFullScreenProvider.notifier).toggle();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    ref.read(commentaryVisibilityProvider.notifier).hide();
                  },
                ),
              ],
            ),
          ),
          _buildAlternativeCommentarySearch(context),
          Expanded(child: contentWidget),
        ],
      ),
    );
  }
}

class CommentarySelectionSheet extends ConsumerWidget {
  const CommentarySelectionSheet({required this.onSelected, super.key});

  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const repo = ManifestRepository();
    final bibleDbPath = ref.watch(activeDbPathProvider).asData?.value;
    return FutureBuilder<List<BiblePack>>(
      future: repo.loadBiblePacksFromAsset(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final packs =
            snapshot.data?.where((p) => p.type == 'commentary').toList() ?? [];
        if (packs.isEmpty) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(context.l10n.t('noCommentariesFound')),
            ),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.l10n.t('selectCommentaryToActivate'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: packs.length,
                  itemBuilder: (context, idx) {
                    final p = packs[idx];
                    return ListTile(
                      title: Text(p.shortName),
                      subtitle: Text('${p.language} - ${p.name}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.info_outline),
                        tooltip: context.l10n.t('viewIntro'),
                        onPressed: () async {
                          final activeBibleDbPathFuture = ref.read(
                            activeDbPathProvider.future,
                          );
                          final resolvedBibleDbPath =
                              bibleDbPath ?? await activeBibleDbPathFuture;
                          if (!context.mounted) return;
                          showCommentaryIntros(
                            context,
                            p.file,
                            p.name,
                            resolvedBibleDbPath,
                          );
                        },
                      ),
                      onTap: () async {
                        await ref
                            .read(activeCommentarySelectionProvider.notifier)
                            .select(id: p.id, file: p.file, name: p.name);
                        ref.read(commentaryVisibilityProvider.notifier).show();
                        onSelected();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
