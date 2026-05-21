import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../reader/data/reader_repository.dart';
import '../../reader/providers/reader_controller.dart';
import '../../reader/providers/verse_selection_controller.dart';
import '../providers/user_data_controller.dart';
import '../../../data/storage/db_path_provider.dart';

class SavedPage extends ConsumerWidget {
  const SavedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeDbPathAsync = ref.watch(activeDbPathProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Saved'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.bookmark), text: 'Bookmarks'),
              Tab(icon: Icon(Icons.border_color), text: 'Highlights'),
              Tab(icon: Icon(Icons.note_alt), text: 'Notes'),
            ],
          ),
        ),
        body: activeDbPathAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (dbPath) {
            if (dbPath == null) {
              return const Center(
                child: Text('No active Bible database. Please select a version in settings.'),
              );
            }
            return TabBarView(
              children: [
                _BookmarksTab(dbPath: dbPath),
                _HighlightsTab(dbPath: dbPath),
                _NotesTab(dbPath: dbPath),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _twoDigits(int n) => n.toString().padLeft(2, '0');

String _formatTimestamp(int ts) {
  final date = DateTime.fromMillisecondsSinceEpoch(ts);
  return '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)} ${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
}

String _getBookName(String dbPath, int bookId) {
  const repo = ReaderRepository();
  var bookName = repo.loadBookName(dbPath: dbPath, bookId: bookId);
  if (dbPath.contains('com_kor_') && RegExp(r'^[a-zA-Z\s]+$').hasMatch(bookName)) {
    final names = bibleBookNames[bookId];
    if (names != null && names.isNotEmpty) {
      bookName = names.last;
    }
  }
  return bookName;
}

class _BookmarksTab extends ConsumerWidget {
  const _BookmarksTab({required this.dbPath});

  final String dbPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarksAsync = ref.watch(bookmarksProvider);
    final theme = Theme.of(context);

    return bookmarksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (bookmarks) {
        if (bookmarks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_outline, size: 64, color: theme.colorScheme.outline),
                const SizedBox(height: 16),
                const Text('No bookmarks saved yet.', style: TextStyle(fontSize: 16)),
              ],
            ),
          );
        }

        const readerRepo = ReaderRepository();
        final userDataRepo = ref.read(userDataRepositoryProvider);
        final userDataDbPath = ref.read(userDataDbPathProvider);

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: bookmarks.length,
          itemBuilder: (context, index) {
            final entry = bookmarks[index];
            final bookName = _getBookName(dbPath, entry.bookId);
            final verseText = readerRepo.loadVerseText(
              dbPath: dbPath,
              bookId: entry.bookId,
              chapter: entry.chapter,
              verse: entry.verse,
            );

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$bookName ${entry.chapter}:${entry.verse}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      _formatTimestamp(entry.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    verseText.isNotEmpty ? verseText : '[Verse text not found in current translation]',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    userDataRepo.deleteBookmark(
                      dbPath: userDataDbPath,
                      bookId: entry.bookId,
                      chapter: entry.chapter,
                      verse: entry.verse,
                    );
                    ref.invalidate(bookmarksProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bookmark removed.')),
                    );
                  },
                ),
                onTap: () {
                  final targetKey = VerseKey(bookId: entry.bookId, chapter: entry.chapter, verse: entry.verse);
                  ref.read(readerRefProvider.notifier).jumpTo(bookId: entry.bookId, chapter: entry.chapter);
                  ref.read(verseSelectionProvider.notifier).clear();
                  ref.read(verseSelectionProvider.notifier).tap(targetKey);
                  ref.read(targetScrollVerseProvider.notifier).state = targetKey;
                  context.go('/reader');
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _HighlightsTab extends ConsumerWidget {
  const _HighlightsTab({required this.dbPath});

  final String dbPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlightsAsync = ref.watch(highlightsProvider);
    final theme = Theme.of(context);

    return highlightsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (highlights) {
        if (highlights.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.border_color, size: 64, color: theme.colorScheme.outline),
                const SizedBox(height: 16),
                const Text('No highlights saved yet.', style: TextStyle(fontSize: 16)),
              ],
            ),
          );
        }

        const readerRepo = ReaderRepository();
        final userDataRepo = ref.read(userDataRepositoryProvider);
        final userDataDbPath = ref.read(userDataDbPathProvider);

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: highlights.length,
          itemBuilder: (context, index) {
            final entry = highlights[index];
            final bookName = _getBookName(dbPath, entry.bookId);
            final verseText = readerRepo.loadVersesTextRange(
              dbPath: dbPath,
              bookId: entry.bookId,
              chapter: entry.chapter,
              verseStart: entry.verseStart,
              verseEnd: entry.verseEnd,
            );

            final rangeStr = entry.verseStart == entry.verseEnd
                ? '${entry.verseStart}'
                : '${entry.verseStart}-${entry.verseEnd}';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$bookName ${entry.chapter}:$rangeStr',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                    Text(
                      _formatTimestamp(entry.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    verseText.isNotEmpty ? verseText : '[Verses not found in current translation]',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    userDataRepo.deleteHighlight(
                      dbPath: userDataDbPath,
                      id: entry.id,
                    );
                    ref.invalidate(highlightsProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Highlight removed.')),
                    );
                  },
                ),
                onTap: () {
                  final targetKey = VerseKey(bookId: entry.bookId, chapter: entry.chapter, verse: entry.verseStart);
                  ref.read(readerRefProvider.notifier).jumpTo(bookId: entry.bookId, chapter: entry.chapter);
                  ref.read(verseSelectionProvider.notifier).clear();
                  for (int v = entry.verseStart; v <= entry.verseEnd; v++) {
                    ref.read(verseSelectionProvider.notifier).tap(
                      VerseKey(bookId: entry.bookId, chapter: entry.chapter, verse: v),
                    );
                  }
                  ref.read(targetScrollVerseProvider.notifier).state = targetKey;
                  context.go('/reader');
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _NotesTab extends ConsumerWidget {
  const _NotesTab({required this.dbPath});

  final String dbPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);
    final theme = Theme.of(context);

    return notesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (notes) {
        if (notes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.note_alt_outlined, size: 64, color: theme.colorScheme.outline),
                const SizedBox(height: 16),
                const Text('No notes saved yet.', style: TextStyle(fontSize: 16)),
              ],
            ),
          );
        }

        const readerRepo = ReaderRepository();
        final userDataRepo = ref.read(userDataRepositoryProvider);
        final userDataDbPath = ref.read(userDataDbPathProvider);

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final entry = notes[index];
            final bookName = _getBookName(dbPath, entry.bookId);
            final verseText = readerRepo.loadVerseText(
              dbPath: dbPath,
              bookId: entry.bookId,
              chapter: entry.chapter,
              verse: entry.verse,
            );

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$bookName ${entry.chapter}:${entry.verse}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.tertiary,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              _formatTimestamp(entry.updatedAt),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () {
                                userDataRepo.deleteNote(
                                  dbPath: userDataDbPath,
                                  bookId: entry.bookId,
                                  chapter: entry.chapter,
                                  verse: entry.verse,
                                );
                                ref.invalidate(notesProvider);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Note deleted.')),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        final c = TextEditingController(text: entry.content);
                        final text = await showDialog<String>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text('노트 수정 ($bookName ${entry.chapter}:${entry.verse})'),
                            content: TextField(
                              controller: c,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: '여기에 구절에 대한 주석이나 묵상을 적어보세요...',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('취소'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(c.text),
                                child: const Text('저장'),
                              ),
                            ],
                          ),
                        );

                        if (text != null) {
                          if (text.trim().isEmpty) {
                            userDataRepo.deleteNote(
                              dbPath: userDataDbPath,
                              bookId: entry.bookId,
                              chapter: entry.chapter,
                              verse: entry.verse,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Note deleted.')),
                              );
                            }
                          } else {
                            userDataRepo.upsertNote(
                              dbPath: userDataDbPath,
                              bookId: entry.bookId,
                              chapter: entry.chapter,
                              verse: entry.verse,
                              content: text,
                              now: DateTime.now().millisecondsSinceEpoch,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Note updated.')),
                              );
                            }
                          }
                          ref.invalidate(notesProvider);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          entry.content,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () {
                        final targetKey = VerseKey(bookId: entry.bookId, chapter: entry.chapter, verse: entry.verse);
                        ref.read(readerRefProvider.notifier).jumpTo(bookId: entry.bookId, chapter: entry.chapter);
                        ref.read(verseSelectionProvider.notifier).clear();
                        ref.read(verseSelectionProvider.notifier).tap(targetKey);
                        ref.read(targetScrollVerseProvider.notifier).state = targetKey;
                        context.go('/reader');
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Icon(Icons.menu_book, size: 14, color: theme.colorScheme.primary),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              verseText.isNotEmpty
                                  ? verseText
                                  : '[Verse text not found in current translation]',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
