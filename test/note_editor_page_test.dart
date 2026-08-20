import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Love/app/app_localizations.dart';
import 'package:Love/features/study/presentation/note_editor_page.dart';

void main() {
  testWidgets('shows selected verses above the full-height note editor', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const NoteEditorPage(
          title: 'Write note',
          reference: '창세기 1:1-2',
          verses: [
            NoteEditorVerse(verse: 1, text: '태초에 하나님이'),
            NoteEditorVerse(verse: 2, text: '땅이 혼돈하고'),
          ],
          initialContent: 'Remember this passage.',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('창세기 1:1-2'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('태초에 하나님이'),
      ),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Remember this passage.'), findsOneWidget);

    final verseArea = tester.getSize(find.byType(SizedBox).first);
    final body =
        tester.getSize(find.byType(Scaffold)).height -
        tester.getSize(find.byType(AppBar)).height;
    expect(verseArea.height, closeTo(body / 3, 1));
  });
}
