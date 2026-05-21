import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';

void main() {
  testWidgets('tap pack row sets active pack label in app bar', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('KJV'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('KJV'));
    await tester.pumpAndSettle();

    expect(find.text('Active: en_kjv'), findsOneWidget);
  });
}
