import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/reader/presentation/reader_page.dart';
import '../lib/data/storage/db_path_provider.dart';

void main() {
  testWidgets('reader page shows Genesis 1:1 line', (tester) async {
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

    expect(
      find.textContaining(
        '[1:1] In the beginning God created the heaven and the earth.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('reader page shows nothing-installed message when db missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeDbPathProvider.overrideWith(
            (ref) => 'assets/data/getbible/__missing__.sqlite',
          ),
        ],
        child: const MaterialApp(home: ReaderPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('DB Error'), findsOneWidget);
  });
}
