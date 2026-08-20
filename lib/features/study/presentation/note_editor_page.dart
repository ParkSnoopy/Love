import 'package:flutter/material.dart';

import '../../../app/app_localizations.dart';

class NoteEditorVerse {
  const NoteEditorVerse({required this.verse, required this.text});

  final int verse;
  final String text;
}

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({
    super.key,
    required this.title,
    required this.reference,
    required this.verses,
    required this.initialContent,
  });

  final String title;
  final String reference;
  final List<NoteEditorVerse> verses;
  final String initialContent;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialContent,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_controller.text),
            child: Text(l10n.t('save')),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            SizedBox(
              height: constraints.maxHeight / 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  border: Border(
                    bottom: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.verses.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Text(
                        widget.reference,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }
                    final verse = widget.verses[index - 1];
                    return Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${verse.verse} ',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(text: verse.text),
                        ],
                      ),
                      style: theme.textTheme.bodyLarge,
                    );
                  },
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: l10n.t('noteHint'),
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
