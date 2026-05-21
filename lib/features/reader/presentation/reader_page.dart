import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import '../domain/verse_export_formatter.dart';
import '../data/reader_repository.dart';
import '../providers/reader_controller.dart';
import '../providers/verse_selection_controller.dart';
import '../../study/providers/user_data_controller.dart';

class ReaderPage extends ConsumerWidget {
  const ReaderPage({super.key, required this.dbPath});

  final String dbPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rr = ref.watch(readerRefProvider);
    final selection = ref.watch(verseSelectionProvider);
    final userDataRepo = ref.watch(userDataRepositoryProvider);
    final userDataDbPath = ref.watch(userDataDbPathProvider);
    const repo = ReaderRepository();
    var verses = const <dynamic>[];
    var bookName = 'Bible';
    String? loadError;
    try {
      verses = repo.loadChapter(dbPath: dbPath, bookId: rr.bookId, chapter: rr.chapter);
      bookName = repo.loadBookName(dbPath: dbPath, bookId: rr.bookId);
    } on SqliteException {
      loadError = 'Nothing installed yet. DB not open: $dbPath\nPlease install/select a Bible pack in Library.';
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
        title: Text('Reader $bookName ${rr.chapter}'),
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
                        final text = VerseExportFormatter.format(selectedVerseLines);
                        await Clipboard.setData(ClipboardData(text: text));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied to clipboard')),
                          );
                        }
                      },
                      child: const Text('Copy'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final text = VerseExportFormatter.format(selectedVerseLines);
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
                          SnackBar(content: Text('Bookmarked ${selectedVerseLines.length} verse(s)')),
                        );
                      },
                      child: const Text('Bookmark'),
                    ),
                    TextButton(
                      onPressed: () {
                        final sorted = [...selectedVerseLines]..sort((a, b) => a.verse.compareTo(b.verse));
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
                          SnackBar(content: Text('Highlight ${first.chapter}:${first.verse}-${last.verse}')),
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
                              final c = TextEditingController(text: existing?.content ?? '');
                              final text = await showDialog<String>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text('Note ${single.chapter}:${single.verse}'),
                                  content: TextField(
                                    controller: c,
                                    maxLines: 5,
                                    decoration: const InputDecoration(border: OutlineInputBorder()),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.of(ctx).pop(c.text.trim()),
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'No commentary installed/mapped for this verse',
                                        ),
                                        const SizedBox(height: 12),
                                        TextButton(
                                          onPressed: () => Navigator.of(ctx).pop(),
                                          child: const Text('Manage commentary packs'),
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
                      onPressed: () => ref.read(verseSelectionProvider.notifier).clear(),
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
                      child: Text(
                        loadError,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: verses.length,
                    itemBuilder: (context, i) {
                      final v = verses[i];
                      final key = VerseKey(bookId: v.bookId, chapter: v.chapter, verse: v.verse);
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
                        onLongPress: () => ref.read(verseSelectionProvider.notifier).longPress(key),
                        title: Text('[${v.chapter}:${v.verse}] ${v.text}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
