import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException, sqlite3, OpenMode;

import '../domain/verse_export_formatter.dart';
import '../data/reader_repository.dart';
import '../providers/reader_controller.dart';
import '../providers/verse_selection_controller.dart';
import '../../study/providers/user_data_controller.dart';
import '../../../data/storage/db_path_provider.dart';
import '../../library/providers/library_controller.dart';
import '../../library/domain/bible_pack.dart';
import '../../library/domain/manifest_repository.dart';
import '../providers/commentary_visibility_provider.dart';
import 'verse_action_pane.dart';

class CommentaryFullScreenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void setFullScreen(bool value) => state = value;
}

final commentaryFullScreenProvider =
    NotifierProvider<CommentaryFullScreenNotifier, bool>(CommentaryFullScreenNotifier.new);

class ReaderPage extends ConsumerWidget {
  const ReaderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbPathAsync = ref.watch(activeDbPathProvider);

    return dbPathAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (dbPath) {
        if (dbPath == null) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No Bible selected or installed.\nPlease go to Library and select a version.',
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

class _ReaderContentView extends ConsumerWidget {
  const _ReaderContentView({required this.dbPath});

  final String dbPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (rr) {
        final selection = ref.watch(verseSelectionProvider);
        final userDataRepo = ref.watch(userDataRepositoryProvider);
        final userDataDbPath = ref.watch(userDataDbPathProvider);
        final activeCommentaryDbPath = ref.watch(activeCommentaryDbPathProvider).asData?.value;
        final isCommentaryVisible = ref.watch(commentaryVisibilityProvider);
        final isCommentaryActive = activeCommentaryDbPath != null && isCommentaryVisible;
        final isFullScreen = ref.watch(commentaryFullScreenProvider);

        const repo = ReaderRepository();
        var verses = const <VerseLine>[];
        var bookName = 'Bible';
        String? loadError;
        try {
          verses = repo.loadChapter(
            dbPath: dbPath,
            bookId: rr.bookId,
            chapter: rr.chapter,
          );
          bookName = repo.loadBookName(dbPath: dbPath, bookId: rr.bookId);
        } on SqliteException catch (e) {
          loadError = 'DB Error: ${e.message}\nPath: $dbPath';
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
              onTap: () => _showPicker(context, ref, rr, dbPath),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$bookName ${rr.chapter}'),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Toggle Commentary',
                icon: Icon(
                  isCommentaryActive ? Icons.comment : Icons.comment_outlined,
                  color: isCommentaryActive ? Theme.of(context).colorScheme.primary : null,
                ),
                onPressed: () {
                  final activeCommentary = ref.read(activeCommentarySelectionProvider).asData?.value;
                  if (activeCommentary == null) {
                    showModalBottomSheet<void>(
                      context: context,
                      builder: (ctx) => _CommentarySelectionSheet(
                        onSelected: () => Navigator.of(ctx).pop(),
                      ),
                    );
                  } else {
                    ref.read(commentaryVisibilityProvider.notifier).toggle();
                  }
                },
              ),
              IconButton(
                onPressed: () => ref.read(readerRefProvider.notifier).prevChapter(),
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                onPressed: () => ref.read(readerRefProvider.notifier).nextChapter(),
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
                      : ListView.builder(
                          itemCount: verses.length,
                          itemBuilder: (context, i) {
                            final v = verses[i];
                            final key = VerseKey(
                              bookId: v.bookId,
                              chapter: v.chapter,
                              verse: v.verse,
                            );
                            final selected = selection.selected.contains(key);
                            return ListTile(
                              selected: selected,
                              onTap: () {
                                ref.read(verseSelectionProvider.notifier).tap(key);
                                userDataRepo.addHistory(
                                  dbPath: userDataDbPath,
                                  bookId: v.bookId,
                                  chapter: v.chapter,
                                  verse: v.verse,
                                  visitedAt: DateTime.now().millisecondsSinceEpoch,
                                );
                              },
                              onLongPress: () => ref
                                  .read(verseSelectionProvider.notifier)
                                  .longPress(key),
                              title: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${v.verse} ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.primary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    TextSpan(text: v.text),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              if (isCommentaryActive)
                Expanded(
                  flex: isFullScreen ? 1 : 2,
                  child: CommentaryPane(
                    dbPath: activeCommentaryDbPath,
                    bookId: rr.bookId,
                    chapter: rr.chapter,
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

  void _showPicker(
    BuildContext context,
    WidgetRef ref,
    ReaderRef rr,
    String dbPath,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _BookChapterPicker(
        dbPath: dbPath,
        initialBookId: rr.bookId,
        initialChapter: rr.chapter,
        onSelected: (bookId, chapter) {
          ref
              .read(readerRefProvider.notifier)
              .jumpTo(bookId: bookId, chapter: chapter);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }
}

class _BookChapterPicker extends StatefulWidget {
  const _BookChapterPicker({
    required this.dbPath,
    required this.initialBookId,
    required this.initialChapter,
    required this.onSelected,
  });

  final String dbPath;
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

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  void _loadBooks() {
    final db = sqlite3.open(widget.dbPath, mode: OpenMode.readOnly);
    try {
      final rows = db.select(
        'SELECT book_id, name_native, name_en, chapter_count FROM books ORDER BY book_id',
      );
      setState(() {
        _books = rows
            .map(
              (r) => <String, dynamic>{
                'id': r['book_id'],
                'name': (r['name_native'] as String?)?.trim().isNotEmpty == true
                    ? r['name_native']
                    : r['name_en'],
                'count': r['chapter_count'],
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
            child: Text(
              'Select Book & Chapter',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ListView.builder(
                    controller: scrollController,
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
    required this.bookId,
    required this.chapter,
  });

  final String dbPath;
  final int bookId;
  final int chapter;

  @override
  ConsumerState<CommentaryPane> createState() => _CommentaryPaneState();
}

class _CommentaryPaneState extends ConsumerState<CommentaryPane> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CommentaryPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookId != widget.bookId || oldWidget.chapter != widget.chapter) {
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
    final tagRegex = RegExp(r'<(b|i)>(.*?)</\1>|<[^>]+>|([^<]+)', caseSensitive: false);
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
        spans.add(TextSpan(text: match.group(3)));
      }
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    const repo = ReaderRepository();
    List<CommentaryVerse> verses = [];
    String? err;
    try {
      verses = repo.loadCommentaryVerses(
        dbPath: widget.dbPath,
        bookId: widget.bookId,
        chapter: widget.chapter,
      );
    } catch (e) {
      err = 'Commentary Error: $e';
    }

    final theme = Theme.of(context);
    final baseTextStyle = theme.textTheme.bodyMedium ?? const TextStyle();
    final activeCommentary = ref.watch(activeCommentarySelectionProvider).asData?.value;

    var bookName = repo.loadBookName(dbPath: widget.dbPath, bookId: widget.bookId);
    if (widget.dbPath.contains('com_kor_') && RegExp(r'^[a-zA-Z\s]+$').hasMatch(bookName)) {
      final names = bibleBookNames[widget.bookId];
      if (names != null && names.isNotEmpty) {
        bookName = names.last;
      }
    }
    final headerTitle = activeCommentary != null
        ? '${activeCommentary.name} - $bookName ${widget.chapter}장'
        : '$bookName ${widget.chapter}장';

    final isFullScreen = ref.watch(commentaryFullScreenProvider);
    final hasVerseComments = verses.any((v) => v.verse > 0);

    Widget contentWidget;
    if (err != null) {
      contentWidget = Padding(
        padding: const EdgeInsets.all(16),
        child: Text(err, style: const TextStyle(color: Colors.red)),
      );
    } else if (verses.isEmpty) {
      contentWidget = const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            'No commentary available for this chapter.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else if (hasVerseComments) {
      contentWidget = Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: verses.length,
          itemBuilder: (context, i) {
            final v = verses[i];
            if (v.text.trim().isEmpty) return const SizedBox.shrink();

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
              color: theme.colorScheme.surfaceContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.verse == 0 ? '장의 서론 / 개요' : '${v.verse}절',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text.rich(
                      TextSpan(
                        children: _parseHtmlToTextSpans(
                          v.text,
                          baseTextStyle.copyWith(height: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } else {
      final intro = verses.firstWhere((v) => v.verse == 0, orElse: () => verses.first);
      contentWidget = Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          child: Text.rich(
            TextSpan(
              children: _parseHtmlToTextSpans(
                intro.text,
                baseTextStyle.copyWith(height: 1.5),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
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
                if (activeCommentary != null)
                  IconButton(
                    icon: const Icon(Icons.menu_book, size: 18),
                    tooltip: '서론 및 소개 보기',
                    onPressed: () {
                      _showCommentaryIntros(context, activeCommentary.file, activeCommentary.name);
                    },
                  ),
                IconButton(
                  icon: Icon(
                    isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    size: 18,
                  ),
                  tooltip: isFullScreen ? '전체화면 종료' : '전체화면으로 보기',
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
          Expanded(
            child: contentWidget,
          ),
        ],
      ),
    );
  }
}

class _CommentarySelectionSheet extends ConsumerWidget {
  const _CommentarySelectionSheet({required this.onSelected});

  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const repo = ManifestRepository();
    return FutureBuilder<List<BiblePack>>(
      future: repo.loadBiblePacksFromAsset(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final packs = snapshot.data
                ?.where((p) => p.type == 'commentary')
                .toList() ??
            [];
        if (packs.isEmpty) {
          return const SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No commentaries found.'),
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
                  'Select Commentary to Activate',
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
                        tooltip: '서론 및 소개 보기',
                        onPressed: () {
                          _showCommentaryIntros(context, p.file, p.name);
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

void _showCommentaryIntros(BuildContext context, String manifestFile, String commentaryName) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return _CommentaryIntroListSheet(
            manifestFile: manifestFile,
            commentaryName: commentaryName,
            scrollController: scrollController,
          );
        },
      );
    },
  );
}

class _CommentaryIntroListSheet extends StatefulWidget {
  const _CommentaryIntroListSheet({
    required this.manifestFile,
    required this.commentaryName,
    required this.scrollController,
  });

  final String manifestFile;
  final String commentaryName;
  final ScrollController scrollController;

  @override
  State<_CommentaryIntroListSheet> createState() => _CommentaryIntroListSheetState();
}

class _CommentaryIntroListSheetState extends State<_CommentaryIntroListSheet> {
  late Future<List<CommentaryIntroduction>?> _introsFuture;

  @override
  void initState() {
    super.initState();
    _introsFuture = _loadIntros();
  }

  Future<List<CommentaryIntroduction>?> _loadIntros() async {
    const repo = ReaderRepository();
    final dbPath = await repo.resolveDbPath(widget.manifestFile);
    if (dbPath == null) return null;
    return repo.loadCommentaryIntroductions(dbPath: dbPath);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<CommentaryIntroduction>?>(
      future: _introsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final intros = snapshot.data;
        if (intros == null || intros.isEmpty) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      '이 주석에는 서론 및 배경 설명 정보가 없습니다.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.commentaryName} - 서론 및 소개',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: widget.scrollController,
                itemCount: intros.length,
                itemBuilder: (context, idx) {
                  final intro = intros[idx];
                  return ListTile(
                    leading: Icon(
                      intro.bookId == 0 ? Icons.info_outline : Icons.book_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(
                      intro.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _CommentaryIntroViewerPage(
                            intro: intro,
                            commentaryName: widget.commentaryName,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CommentaryIntroViewerPage extends StatelessWidget {
  const _CommentaryIntroViewerPage({
    required this.intro,
    required this.commentaryName,
  });

  final CommentaryIntroduction intro;
  final String commentaryName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseTextStyle = theme.textTheme.bodyMedium?.copyWith(
          height: 1.6,
          fontSize: 16,
        ) ??
        const TextStyle(height: 1.6, fontSize: 16);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              intro.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              commentaryName,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Text.rich(
              TextSpan(
                children: _parseIntroMarkdownAndHtml(
                  intro.text,
                  baseTextStyle,
                  theme,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

List<TextSpan> _parseIntroMarkdownAndHtml(String rawText, TextStyle baseStyle, ThemeData theme) {
  final lines = rawText.split('\n');
  final spans = <TextSpan>[];

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty) {
      spans.add(const TextSpan(text: '\n'));
      continue;
    }

    if (line.startsWith('#')) {
      final headerLevel = RegExp(r'^#+').firstMatch(line)?.group(0)?.length ?? 1;
      final headerText = line.replaceAll(RegExp(r'^#+\s*'), '').trim();
      
      double fontSizeFactor = 1.25;
      if (headerLevel == 1) fontSizeFactor = 1.45;
      if (headerLevel == 2) fontSizeFactor = 1.3;
      
      spans.add(
        TextSpan(
          text: '$headerText\n',
          style: baseStyle.copyWith(
            fontSize: (baseStyle.fontSize ?? 16) * fontSizeFactor,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      );
      continue;
    }

    final lineSpans = _parseLineHtml(line, baseStyle);
    spans.addAll(lineSpans);
    spans.add(const TextSpan(text: '\n'));
  }

  return spans;
}

List<TextSpan> _parseLineHtml(String line, TextStyle baseStyle) {
  var text = line
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<p>', caseSensitive: false), '');

  final spans = <TextSpan>[];
  final tagRegex = RegExp(r'<(b|i)>(.*?)</\1>|<[^>]+>|([^<]+)', caseSensitive: false);
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
      spans.add(TextSpan(text: match.group(3)));
    }
  }

  if (spans.isEmpty) {
    spans.add(TextSpan(text: text));
  }
  return spans;
}

