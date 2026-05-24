import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_localizations.dart';
import '../../../app/font_controller.dart';
import '../../../app/reader_settings_controller.dart';
import '../data/reader_repository.dart';

void showCommentaryIntros(
  BuildContext context,
  String manifestFile,
  String commentaryName,
  String? bibleDbPath,
) {
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
            bibleDbPath: bibleDbPath,
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
    required this.bibleDbPath,
    required this.scrollController,
  });

  final String manifestFile;
  final String commentaryName;
  final String? bibleDbPath;
  final ScrollController scrollController;

  @override
  State<_CommentaryIntroListSheet> createState() =>
      _CommentaryIntroListSheetState();
}

class _CommentaryIntroListSheetState extends State<_CommentaryIntroListSheet> {
  late Future<_CommentaryIntroData?> _introsFuture;

  @override
  void initState() {
    super.initState();
    _introsFuture = _loadIntros();
  }

  Future<_CommentaryIntroData?> _loadIntros() async {
    const repo = ReaderRepository();
    final dbPath = await repo.resolveDbPath(
      widget.manifestFile,
      type: 'commentary',
    );
    if (dbPath == null) return null;
    final intros = repo.loadCommentaryIntroductions(dbPath: dbPath);
    final bibleBookNames = <int, String>{};
    final bibleDbPath = widget.bibleDbPath;
    if (bibleDbPath != null) {
      for (final intro in intros) {
        if (intro.bookId <= 0 || bibleBookNames.containsKey(intro.bookId)) {
          continue;
        }
        try {
          bibleBookNames[intro.bookId] = repo.loadBookName(
            dbPath: bibleDbPath,
            bookId: intro.bookId,
          );
        } catch (_) {
          // Keep commentary DB title if active Bible DB cannot resolve this book.
        }
      }
    }
    return _CommentaryIntroData(intros: intros, bibleBookNames: bibleBookNames);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<_CommentaryIntroData?>(
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
        final data = snapshot.data;
        final intros = data?.intros;
        if (data == null || intros == null || intros.isEmpty) {
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
                      context.l10n.t('noIntroInfo'),
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
                      '${widget.commentaryName} - ${context.l10n.t('introAndInfo')}',
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
                  final title = _introDisplayTitle(
                    intro,
                    data.bibleBookNames,
                    context.l10n,
                  );
                  return ListTile(
                    leading: Icon(
                      intro.bookId == 0
                          ? Icons.info_outline
                          : Icons.book_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(
                      title,
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
                            title: title,
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

class _CommentaryIntroData {
  const _CommentaryIntroData({
    required this.intros,
    required this.bibleBookNames,
  });

  final List<CommentaryIntroduction> intros;
  final Map<int, String> bibleBookNames;
}

String _introDisplayTitle(
  CommentaryIntroduction intro,
  Map<int, String> localizedBookNames,
  AppLocalizations l10n,
) {
  if (intro.bookId <= 0) return intro.title;
  final localizedBookName = localizedBookNames[intro.bookId]?.trim();
  if (localizedBookName == null || localizedBookName.isEmpty) {
    return intro.title;
  }
  return l10n.bookIntroductionTitle(localizedBookName);
}

class _CommentaryIntroViewerPage extends ConsumerWidget {
  const _CommentaryIntroViewerPage({
    required this.intro,
    required this.title,
    required this.commentaryName,
  });

  final CommentaryIntroduction intro;
  final String title;
  final String commentaryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final readerSettings =
        ref.watch(readerSettingsProvider).value ??
        const ReaderSettingsState(fontSize: 18.0, lineSpacing: 1.5);
    final fontType = ref.watch(fontTypeProvider).value ?? FontType.serif;
    final baseTextStyle =
        theme.textTheme.bodyMedium?.copyWith(
          fontFamily: fontFamilyForType(fontType),
          height: readerSettings.lineSpacing,
          fontSize: readerSettings.fontSize,
        ) ??
        TextStyle(
          fontFamily: fontFamilyForType(fontType),
          height: readerSettings.lineSpacing,
          fontSize: readerSettings.fontSize,
        );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
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
                style: baseTextStyle,
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

List<TextSpan> _parseIntroMarkdownAndHtml(
  String rawText,
  TextStyle baseStyle,
  ThemeData theme,
) {
  final lines = rawText.split('\n');
  final spans = <TextSpan>[];

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty) {
      spans.add(const TextSpan(text: '\n'));
      continue;
    }

    if (line.startsWith('#')) {
      final headerLevel =
          RegExp(r'^#+').firstMatch(line)?.group(0)?.length ?? 1;
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
