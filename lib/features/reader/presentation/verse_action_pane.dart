import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/verse_export_formatter.dart';
import '../providers/verse_selection_controller.dart';
import '../providers/commentary_visibility_provider.dart';
import '../../study/providers/user_data_controller.dart';
import '../../study/data/user_data_repository.dart';
import '../../library/providers/library_controller.dart';
import 'reader_page.dart';
import '../../../app/app_localizations.dart';

class VerseActionPane extends ConsumerWidget {
  const VerseActionPane({
    super.key,
    required this.selectedVerses,
    required this.bookName,
    required this.chapter,
    required this.bookId,
  });

  final List<SelectedVerse> selectedVerses;
  final String bookName;
  final int chapter;
  final int bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final bookmarksAsync = ref.watch(bookmarksProvider);
    final highlightsAsync = ref.watch(highlightsProvider);
    final userDataRepo = ref.watch(userDataRepositoryProvider);
    final userDataDbPath = ref.watch(userDataDbPathProvider).value ?? '';
    final selection = ref.watch(verseSelectionProvider);

    final bookmarks = bookmarksAsync.value ?? [];
    final highlights = highlightsAsync.value ?? [];

    final sortedVersesList = [...selectedVerses]
      ..sort((a, b) => a.verse.compareTo(b.verse));

    final allBookmarked =
        sortedVersesList.isNotEmpty &&
        sortedVersesList.every(
          (sv) => bookmarks.any(
            (b) =>
                b.bookId == bookId &&
                b.chapter == chapter &&
                b.verse == sv.verse,
          ),
        );

    final isAnyHighlighted =
        sortedVersesList.isNotEmpty &&
        sortedVersesList.any(
          (sv) => highlights.any(
            (h) =>
                h.bookId == bookId &&
                h.chapter == chapter &&
                sv.verse >= h.verseStart &&
                sv.verse <= h.verseEnd,
          ),
        );

    final verseRangeStr = sortedVersesList.isEmpty
        ? ''
        : '${VerseExportFormatter.formatVerseNumbers(sortedVersesList.map((v) => v.verse).toList())}${l10n.t('verseLabel')}';

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.surfaceContainer,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.selectedVerses(
                        '$bookName $chapter $verseRangeStr',
                        sortedVersesList.length,
                      ),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      ref.read(verseSelectionProvider.notifier).clear();
                    },
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.copy, size: 20),
              title: Text(l10n.t('copyToClipboard')),
              onTap: () async {
                final text = VerseExportFormatter.format(sortedVersesList);
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.t('copiedToClipboard'))),
                  );
                }
                ref.read(verseSelectionProvider.notifier).clear();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, size: 20),
              title: Text(l10n.t('share')),
              onTap: () async {
                final text = VerseExportFormatter.format(sortedVersesList);
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l10n.shareText(text))));
                }
                ref.read(verseSelectionProvider.notifier).clear();
              },
            ),
            ListTile(
              leading: Icon(
                allBookmarked ? Icons.bookmark_remove : Icons.bookmark_add,
                size: 20,
              ),
              title: Text(
                allBookmarked
                    ? l10n.t('removeBookmark')
                    : l10n.t('addBookmark'),
              ),
              onTap: () {
                if (allBookmarked) {
                  for (final v in sortedVersesList) {
                    userDataRepo.deleteBookmark(
                      dbPath: userDataDbPath,
                      bookId: bookId,
                      chapter: chapter,
                      verse: v.verse,
                    );
                  }
                  ref.invalidate(bookmarksProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.t('bookmarkRemoved'))),
                  );
                } else {
                  final now = DateTime.now().millisecondsSinceEpoch;
                  for (final v in sortedVersesList) {
                    userDataRepo.addBookmark(
                      dbPath: userDataDbPath,
                      bookId: bookId,
                      chapter: chapter,
                      verse: v.verse,
                      createdAt: now,
                    );
                  }
                  ref.invalidate(bookmarksProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.addedBookmarks(sortedVersesList.length),
                      ),
                    ),
                  );
                }
                ref.read(verseSelectionProvider.notifier).clear();
              },
            ),
            ListTile(
              leading: const Icon(Icons.border_color, size: 20),
              title: Text(
                isAnyHighlighted
                    ? l10n.t('highlightRemove')
                    : l10n.t('highlightAdd'),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildColorCircle(
                    context: context,
                    displayColor: Colors.yellow[600]!,
                    colorName: 'yellow',
                    sortedVerses: sortedVersesList,
                    userDataRepo: userDataRepo,
                    userDataDbPath: userDataDbPath,
                    ref: ref,
                  ),
                  _buildColorCircle(
                    context: context,
                    displayColor: Colors.green[600]!,
                    colorName: 'green',
                    sortedVerses: sortedVersesList,
                    userDataRepo: userDataRepo,
                    userDataDbPath: userDataDbPath,
                    ref: ref,
                  ),
                  _buildColorCircle(
                    context: context,
                    displayColor: Colors.red[600]!,
                    colorName: 'red',
                    sortedVerses: sortedVersesList,
                    userDataRepo: userDataRepo,
                    userDataDbPath: userDataDbPath,
                    ref: ref,
                  ),
                ],
              ),
              onTap: () {
                if (isAnyHighlighted) {
                  final first = sortedVersesList.first;
                  final last = sortedVersesList.last;
                  userDataRepo.removeHighlightRange(
                    dbPath: userDataDbPath,
                    bookId: bookId,
                    chapter: chapter,
                    verseStart: first.verse,
                    verseEnd: last.verse,
                  );
                  ref.invalidate(highlightsProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.t('highlightRemoved'))),
                  );
                } else {
                  final first = sortedVersesList.first;
                  final last = sortedVersesList.last;
                  userDataRepo.addHighlight(
                    dbPath: userDataDbPath,
                    bookId: bookId,
                    chapter: chapter,
                    verseStart: first.verse,
                    verseEnd: last.verse,
                    color: 'yellow',
                    createdAt: DateTime.now().millisecondsSinceEpoch,
                  );
                  ref.invalidate(highlightsProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.highlightAdded('yellow'))),
                  );
                }
                ref.read(verseSelectionProvider.notifier).clear();
              },
            ),
            ListTile(
              leading: const Icon(Icons.note_alt, size: 20),
              title: Text(l10n.t('writeEditNote')),
              onTap: () async {
                if (sortedVersesList.isEmpty) return;
                final existing = selection.mode == SelectionMode.single
                    ? userDataRepo.loadNote(
                        dbPath: userDataDbPath,
                        bookId: bookId,
                        chapter: chapter,
                        verse: selection.single!.verse,
                      )
                    : null;
                final c = TextEditingController(text: existing?.content ?? '');
                final container = ProviderScope.containerOf(context);
                final range = VerseExportFormatter.formatVerseNumbers(
                  sortedVersesList.map((v) => v.verse).toList(),
                );

                final text = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.noteTitle('$chapter:$range')),
                    content: TextField(
                      controller: c,
                      maxLines: 5,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: l10n.t('noteHint'),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(l10n.t('cancel')),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(c.text),
                        child: Text(l10n.t('save')),
                      ),
                    ],
                  ),
                );

                if (text != null) {
                  if (text.trim().isEmpty) {
                    for (final v in sortedVersesList) {
                      userDataRepo.deleteNote(
                        dbPath: userDataDbPath,
                        bookId: bookId,
                        chapter: chapter,
                        verse: v.verse,
                      );
                    }
                  } else {
                    final now = DateTime.now().millisecondsSinceEpoch;
                    for (final v in sortedVersesList) {
                      userDataRepo.upsertNote(
                        dbPath: userDataDbPath,
                        bookId: bookId,
                        chapter: chapter,
                        verse: v.verse,
                        content: text,
                        now: now,
                      );
                    }
                  }
                  container.invalidate(notesProvider);
                }
                container.read(verseSelectionProvider.notifier).clear();
              },
            ),
            ListTile(
              leading: const Icon(Icons.comment, size: 20),
              title: Text(l10n.t('viewCommentary')),
              onTap: () {
                if (sortedVersesList.isNotEmpty) {
                  ref.read(targetScrollCommentaryVerseProvider.notifier).state =
                      sortedVersesList.first.verse;
                }
                final activeCommentary = ref
                    .read(activeCommentarySelectionProvider)
                    .asData
                    ?.value;
                if (activeCommentary == null) {
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (ctx) => CommentarySelectionSheet(
                      onSelected: () {
                        Navigator.of(ctx).pop();
                        ref.read(commentaryVisibilityProvider.notifier).show();
                        ref.read(verseSelectionProvider.notifier).clear();
                      },
                    ),
                  );
                } else {
                  ref.read(commentaryVisibilityProvider.notifier).show();
                  ref.read(verseSelectionProvider.notifier).clear();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorCircle({
    required BuildContext context,
    required Color displayColor,
    required String colorName,
    required List<SelectedVerse> sortedVerses,
    required UserDataRepository userDataRepo,
    required String userDataDbPath,
    required WidgetRef ref,
  }) {
    return GestureDetector(
      onTap: () {
        final first = sortedVerses.first;
        final last = sortedVerses.last;
        userDataRepo.addHighlight(
          dbPath: userDataDbPath,
          bookId: bookId,
          chapter: chapter,
          verseStart: first.verse,
          verseEnd: last.verse,
          color: colorName,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
        ref.invalidate(highlightsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.highlightAdded(colorName))),
        );
        ref.read(verseSelectionProvider.notifier).clear();
      },
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: displayColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 1,
          ),
        ),
      ),
    );
  }
}
