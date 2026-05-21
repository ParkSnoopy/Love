import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/main.dart';

void main() {
  testWidgets('Library shows at least one bible pack from manifest (KJV visible)', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('KJV'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('KJV'), findsOneWidget);
  });
}
