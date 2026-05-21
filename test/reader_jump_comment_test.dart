import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/reader/presentation/reader_page.dart';

void main() {
  testWidgets('jump comment opens empty-state sheet in single mode', (tester) async {
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

    await tester.tap(find.text('Jump Comment'));
    await tester.pumpAndSettle();

    expect(find.text('No commentary installed/mapped for this verse'), findsOneWidget);
    expect(find.text('Manage commentary packs'), findsOneWidget);
  });
}
