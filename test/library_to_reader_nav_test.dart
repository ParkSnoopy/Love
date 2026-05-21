import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';

void main() {
  testWidgets('library Reader button navigates to reader page', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reader'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Reader Genesis 1'), findsOneWidget);
  });
}
