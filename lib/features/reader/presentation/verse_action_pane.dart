import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/verse_export_formatter.dart';
import '../providers/verse_selection_controller.dart';
import '../../study/providers/user_data_controller.dart';

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
    final selection = ref.watch(verseSelectionProvider);
    final userDataRepo = ref.watch(userDataRepositoryProvider);
    final userDataDbPath = ref.watch(userDataDbPathProvider);

    final sortedVerses = [...selectedVerses]
      ..sort((a, b) => a.verse.compareTo(b.verse));

    final verseRangeStr = sortedVerses.length == 1
        ? '${sortedVerses.first.verse}절'
        : '${sortedVerses.first.verse}-${sortedVerses.last.verse}절';

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
                      '$bookName $chapter장 $verseRangeStr 선택됨 (${sortedVerses.length}개)',
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
                final text = VerseExportFormatter.format(sortedVerses);
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
                final text = VerseExportFormatter.format(sortedVerses);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('공유: $text')),
                  );
                }
                ref.read(verseSelectionProvider.notifier).clear();
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_add, size: 20),
              title: const Text('북마크에 추가'),
              onTap: () {
                final now = DateTime.now().millisecondsSinceEpoch;
                for (final v in sortedVerses) {
                  userDataRepo.addBookmark(
                    dbPath: userDataDbPath,
                    bookId: bookId,
                    chapter: chapter,
                    verse: v.verse,
                    createdAt: now,
                  );
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${sortedVerses.length}개의 구절이 북마크에 추가되었습니다.')),
                );
                ref.read(verseSelectionProvider.notifier).clear();
              },
            ),
            ListTile(
              leading: const Icon(Icons.border_color, size: 20),
              title: const Text('형광펜 하이라이트'),
              onTap: () {
                final first = sortedVerses.first;
                final last = sortedVerses.last;
                userDataRepo.addHighlight(
                  dbPath: userDataDbPath,
                  bookId: bookId,
                  chapter: chapter,
                  verseStart: first.verse,
                  verseEnd: last.verse,
                  color: 'yellow',
                  createdAt: DateTime.now().millisecondsSinceEpoch,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('형광펜 하이라이트가 추가되었습니다.')),
                );
                ref.read(verseSelectionProvider.notifier).clear();
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
                  
                  ref.read(verseSelectionProvider.notifier).clear();
                  
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
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
