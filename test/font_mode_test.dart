import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';

void main() {
  testWidgets('Font mode cycles Sans -> Serif -> Mono', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    expect(find.text('Font: Sans'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.font_download_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Font: Serif'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.font_download_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Font: Mono'), findsOneWidget);
  });
}
