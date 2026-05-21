import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/reader/presentation/reader_page.dart';

void main() {
  testWidgets('single tap shows action bar with enabled jump comment', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ReaderPage(dbPath: 'assets/data/getbible/en_kjv.sqlite'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('[1:1]'));
    await tester.pumpAndSettle();

    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Jump Comment'), findsOneWidget);
    expect(find.text('Bookmark'), findsOneWidget);
    expect(find.text('Highlight'), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);

    final jumpBtn = tester.widget<TextButton>(
      find.ancestor(of: find.text('Jump Comment'), matching: find.byType(TextButton)),
    );
    expect(jumpBtn.onPressed, isNotNull);

    final noteBtn = tester.widget<TextButton>(
      find.ancestor(of: find.text('Note'), matching: find.byType(TextButton)),
    );
    expect(noteBtn.onPressed, isNotNull);
  });

  testWidgets('multi select disables jump comment', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ReaderPage(dbPath: 'assets/data/getbible/en_kjv.sqlite'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.textContaining('[1:1]'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('[1:2]'));
    await tester.pumpAndSettle();

    final jumpBtn = tester.widget<TextButton>(
      find.ancestor(of: find.text('Jump Comment'), matching: find.byType(TextButton)),
    );
    expect(jumpBtn.onPressed, isNull);

    final noteBtn = tester.widget<TextButton>(
      find.ancestor(of: find.text('Note'), matching: find.byType(TextButton)),
    );
    expect(noteBtn.onPressed, isNull);
  });
}
