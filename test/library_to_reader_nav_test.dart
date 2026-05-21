import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';

void main() {
  testWidgets('library Reader button pushes ReaderPage with chapter content', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsWidgets);

    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();

    expect(find.textContaining('Reader Genesis 1'), findsOneWidget);
    expect(find.byType(ListTile), findsWidgets);
    expect(find.textContaining('[1:1]'), findsOneWidget);
  });
}
