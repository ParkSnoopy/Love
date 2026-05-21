import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/reader/presentation/reader_page.dart';
import '../lib/data/storage/db_path_provider.dart';

void main() {
  testWidgets('jump comment opens empty-state sheet in single mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeDbPathProvider.overrideWith(
            (ref) => 'assets/data/getbible/en_kjv.sqlite',
          ),
        ],
        child: const MaterialApp(home: ReaderPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('[1:1]'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jump Comment'));
    await tester.pumpAndSettle();

    expect(
      find.text('No commentary installed/mapped for this verse'),
      findsOneWidget,
    );
    expect(find.text('Manage commentary packs'), findsOneWidget);
  });
}
