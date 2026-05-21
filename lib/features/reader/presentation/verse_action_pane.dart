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
    final bookmarksAsync = ref.watch(bookmarksProvider);
    final highlightsAsync = ref.watch(highlightsProvider);
    final userDataRepo = ref.watch(userDataRepositoryProvider);
    final userDataDbPath = ref.watch(userDataDbPathProvider);
    final selection = ref.watch(verseSelectionProvider);

    final bookmarks = bookmarksAsync.value ?? [];
    final highlights = highlightsAsync.value ?? [];

    final sortedVersesList = [...selectedVerses]
      ..sort((a, b) => a.verse.compareTo(b.verse));

    final allBookmarked = sortedVersesList.isNotEmpty && sortedVersesList.every((sv) =>
        bookmarks.any((b) => b.bookId == bookId && b.chapter == chapter && b.verse == sv.verse));

    final isAnyHighlighted = sortedVersesList.isNotEmpty && sortedVersesList.any((sv) =>
        highlights.any((h) =>
            h.bookId == bookId &&
            h.chapter == chapter &&
            sv.verse >= h.verseStart &&
            sv.verse <= h.verseEnd));

    final verseRangeStr = sortedVersesList.isEmpty
        ? ''
        : '${VerseExportFormatter.formatVerseNumbers(sortedVersesList.map((v) => v.verse).toList())}절';

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
                      '$bookName $chapter장 $verseRangeStr 선택됨 (${sortedVersesList.length}개)',
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
              title: const Text('클립보드에 복사'),
              onTap: () async {
                final text = VerseExportFormatter.format(sortedVersesList);
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('클립보드에 복사되었습니다.')),
                  );
                }
                ref.read(verseSelectionProvider.notifier).clear();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, size: 20),
              title: const Text('공유하기'),
              onTap: () async {
                final text = VerseExportFormatter.format(sortedVersesList);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('공유: $text')),
                  );
                }
                ref.read(verseSelectionProvider.notifier).clear();
              },
            ),
            ListTile(
              leading: Icon(allBookmarked ? Icons.bookmark_remove : Icons.bookmark_add, size: 20),
              title: Text(allBookmarked ? '북마크에서 제거' : '북마크에 추가'),
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
                    const SnackBar(content: Text('북마크가 제거되었습니다.')),
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
                    SnackBar(content: Text('${sortedVersesList.length}개의 구절이 북마크에 추가되었습니다.')),
                  );
                }
                ref.read(verseSelectionProvider.notifier).clear();
              },
            ),
            ListTile(
              leading: const Icon(Icons.border_color, size: 20),
              title: Text(isAnyHighlighted ? '하이라이트 제거' : '형광펜 하이라이트'),
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
                    const SnackBar(content: Text('하이라이트가 제거되었습니다.')),
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
                    const SnackBar(content: Text('형광펜 하이라이트가 추가되었습니다.')),
                  );
                }
                ref.read(verseSelectionProvider.notifier).clear();
              },
            ),
            ListTile(
              leading: const Icon(Icons.comment, size: 20),
              title: const Text('주석 보기'),
              onTap: () {
                if (sortedVersesList.isNotEmpty) {
                  ref.read(targetScrollCommentaryVerseProvider.notifier).state = sortedVersesList.first.verse;
                }
                final activeCommentary = ref.read(activeCommentarySelectionProvider).asData?.value;
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

            if (selection.mode == SelectionMode.single)
              ListTile(
                leading: const Icon(Icons.note_alt, size: 20),
                title: const Text('노트 작성 및 수정'),
                onTap: () async {
                  final single = selection.single!;
                  final existing = userDataRepo.loadNote(
                    dbPath: userDataDbPath,
                    bookId: single.bookId,
                    chapter: single.chapter,
                    verse: single.verse,
                  );
                  final c = TextEditingController(text: existing?.content ?? '');
                  final container = ProviderScope.containerOf(context);
                  
                  final text = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('노트 작성 (${single.chapter}:${single.verse})'),
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
                        bookId: single.bookId,
                        chapter: single.chapter,
                        verse: single.verse,
                      );
                    } else {
                      userDataRepo.upsertNote(
                        dbPath: userDataDbPath,
                        bookId: single.bookId,
                        chapter: single.chapter,
                        verse: single.verse,
                        content: text,
                        now: DateTime.now().millisecondsSinceEpoch,
                      );
                    }
                    container.invalidate(notesProvider);
                  }
                  container.read(verseSelectionProvider.notifier).clear();
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
          SnackBar(
            content: Text(
              '형광펜 하이라이트(${colorName == "yellow" ? "노란색" : colorName == "green" ? "초록색" : "빨간색"})가 추가되었습니다.',
            ),
          ),
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
