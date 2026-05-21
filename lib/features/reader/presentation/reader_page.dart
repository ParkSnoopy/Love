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
                          ? () {
                              showModalBottomSheet<void>(
                                context: context,
                                builder: (ctx) => SafeArea(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'No commentary installed/mapped for this verse',
                                        ),
                                        const SizedBox(height: 12),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(),
                                          child: const Text(
                                            'Manage commentary packs',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
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
    if (_loading)
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );

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
