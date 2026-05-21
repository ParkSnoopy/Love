import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';

void main() {
  testWidgets('validate import button shows success snackbar', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Validate Import'));
    await tester.pumpAndSettle();

    expect(find.text('Import validate OK'), findsOneWidget);
  });
}
