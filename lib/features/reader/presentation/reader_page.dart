import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final rr = ref.watch(readerRefProvider);
    final selection = ref.watch(verseSelectionProvider);
    final userDataRepo = ref.watch(userDataRepositoryProvider);
    final userDataDbPath = ref.watch(userDataDbPathProvider);
    final activeCommentaryDbPath = ref.watch(activeCommentaryDbPathProvider).asData?.value;

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
          if (selection.mode != SelectionMode.none)
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: SizedBox(
                height: 52,
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        final text = VerseExportFormatter.format(
                          selectedVerseLines,
                        );
                        await Clipboard.setData(ClipboardData(text: text));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied to clipboard'),
                            ),
                          );
                        }
                      },
                      child: const Text('Copy'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final text = VerseExportFormatter.format(
                          selectedVerseLines,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Share pending: $text')),
                          );
                        }
                      },
                      child: const Text('Share'),
                    ),
                    TextButton(
                      onPressed: () {
                        final now = DateTime.now().millisecondsSinceEpoch;
                        for (final v in selectedVerseLines) {
                          userDataRepo.addBookmark(
                            dbPath: userDataDbPath,
                            bookId: rr.bookId,
                            chapter: v.chapter,
                            verse: v.verse,
                            createdAt: now,
                          );
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Bookmarked ${selectedVerseLines.length} verse(s)',
                            ),
                          ),
                        );
                      },
                      child: const Text('Bookmark'),
                    ),
                    TextButton(
                      onPressed: () {
                        final sorted = [...selectedVerseLines]
                          ..sort((a, b) => a.verse.compareTo(b.verse));
                        final first = sorted.first;
                        final last = sorted.last;
                        userDataRepo.addHighlight(
                          dbPath: userDataDbPath,
                          bookId: rr.bookId,
                          chapter: first.chapter,
                          verseStart: first.verse,
                          verseEnd: last.verse,
                          color: 'yellow',
                          createdAt: DateTime.now().millisecondsSinceEpoch,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Highlight ${first.chapter}:${first.verse}-${last.verse}',
                            ),
                          ),
                        );
                      },
                      child: const Text('Highlight'),
                    ),
                    TextButton(
                      onPressed: selection.mode == SelectionMode.single
                          ? () async {
                              final single = selection.single!;
                              final existing = userDataRepo.loadNote(
                                dbPath: userDataDbPath,
                                bookId: single.bookId,
                                chapter: single.chapter,
                                verse: single.verse,
                              );
                              final c = TextEditingController(
                                text: existing?.content ?? '',
                              );
                              final text = await showDialog<String>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(
                                    'Note ${single.chapter}:${single.verse}',
                                  ),
                                  content: TextField(
                                    controller: c,
                                    maxLines: 5,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(c.text.trim()),
                                      child: const Text('Save'),
                                    ),
                                  ],
                                ),
                              );
                              if (text != null && text.isNotEmpty) {
                                userDataRepo.upsertNote(
                                  dbPath: userDataDbPath,
                                  bookId: single.bookId,
                                  chapter: single.chapter,
                                  verse: single.verse,
                                  content: text,
                                  now: DateTime.now().millisecondsSinceEpoch,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Note saved')),
                                  );
                                }
                              }
                            }
                          : null,
                      child: const Text('Note'),
                    ),
                    TextButton(
                      onPressed: selection.mode == SelectionMode.single
                          ? () async {
                              final commentaryDbPath = ref.read(activeCommentaryDbPathProvider).asData?.value;
                              if (commentaryDbPath != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Showing commentary in split pane below.'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              } else {
                                showModalBottomSheet<void>(
                                  context: context,
                                  builder: (ctx) => _CommentarySelectionSheet(
                                    onSelected: () => Navigator.of(ctx).pop(),
                                  ),
                                );
                              }
                            }
                          : null,
                      child: const Text('Jump Comment'),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () =>
                          ref.read(verseSelectionProvider.notifier).clear(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            flex: activeCommentaryDbPath != null ? 3 : 1,
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
          if (activeCommentaryDbPath != null)
            Expanded(
              flex: 2,
              child: CommentaryPane(
                dbPath: activeCommentaryDbPath,
                bookId: rr.bookId,
                chapter: rr.chapter,
              ),
            ),
        ],
      ),
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
    CommentaryArticle? article;
    String? err;
    try {
      article = repo.loadCommentaryArticle(
        dbPath: widget.dbPath,
        bookId: widget.bookId,
        chapter: widget.chapter,
      );
    } catch (e) {
      err = 'Commentary Error: $e';
    }

    final theme = Theme.of(context);
    final baseTextStyle = theme.textTheme.bodyMedium ?? const TextStyle();

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
                    article?.title ?? 'No Commentary',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    ref.read(activeCommentarySelectionProvider.notifier).clear();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: err != null
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(err, style: const TextStyle(color: Colors.red)),
                  )
                : article == null
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'No commentary available for this chapter.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          child: Text.rich(
                            TextSpan(
                              children: _parseHtmlToTextSpans(
                                article.text,
                                baseTextStyle,
                              ),
                            ),
                          ),
                        ),
                      ),
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
                      onTap: () async {
                        await ref
                            .read(activeCommentarySelectionProvider.notifier)
                            .select(id: p.id, file: p.file);
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

