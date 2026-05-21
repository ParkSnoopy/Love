import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';

void main() {
  testWidgets('app boots to Library with primary actions visible', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsWidgets);
    expect(find.text('Reader'), findsWidgets);
    expect(find.text('Search'), findsWidgets);
    expect(find.textContaining('Theme:'), findsOneWidget);
    expect(find.textContaining('Font:'), findsOneWidget);
  });
}
