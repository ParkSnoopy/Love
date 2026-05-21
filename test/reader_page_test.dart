import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/reader/presentation/reader_page.dart';

void main() {
  testWidgets('reader page shows Genesis 1:1 line', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ReaderPage(dbPath: 'assets/data/getbible/en_kjv.sqlite'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('[1:1] In the beginning God created the heaven and the earth.'), findsOneWidget);
  });
}
