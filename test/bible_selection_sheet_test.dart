import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Love/app/app_localizations.dart';
import 'package:Love/app/app_preferences.dart';
import 'package:Love/features/library/presentation/library_page.dart';
import 'package:Love/features/library/providers/library_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppPreferences.useMemoryStoreForTesting();
  });

  tearDown(() {
    AppPreferences.clearMemoryStoreForTesting();
  });

  testWidgets('closes the picker before applying a Bible selection', (
    tester,
  ) async {
    String? selectedId;

    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            return MaterialApp(
              locale: const Locale('ko'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) => FilledButton(
                    onPressed: () async {
                      selectedId = await showModalBottomSheet<String>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const BibleSelectionSheet(),
                      );
                      if (selectedId == null || !context.mounted) return;
                      await ref
                          .read(activeBibleSelectionProvider.notifier)
                          .select(selectedId!);
                    },
                    child: const Text('성경 선택'),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('성경 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Korean'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('읽기 쉬운 성경').first,
      find.byType(ListView),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('읽기 쉬운 성경').first);
    await tester.pumpAndSettle();

    expect(selectedId, 'kor_koerv');
    expect(find.byType(BibleSelectionSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
