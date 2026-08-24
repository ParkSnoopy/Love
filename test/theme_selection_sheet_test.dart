import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Love/app/app_localizations.dart';
import 'package:Love/app/theme_controller.dart';
import 'package:Love/features/library/presentation/theme_selection_sheet.dart';

void main() {
  testWidgets('configures and returns a custom theme selection', (
    tester,
  ) async {
    ThemeSelectionResult? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<ThemeSelectionResult>(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => const ThemeSelectionSheet(
                    settings: AppThemeSettings.defaults,
                  ),
                );
              },
              child: const Text('Open themes'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open themes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('theme-mode-custom')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.tap(
      find.byKey(const ValueKey('custom-theme-color-4280453922')),
    );
    await tester.dragUntilVisible(
      find.text('Apply'),
      find.byType(SingleChildScrollView),
      const Offset(0, -250),
    );
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(result?.mode, AppThemeMode.custom);
    expect(result?.customBase, CustomThemeBase.dark);
    expect(result?.customPrimaryValue, 0xFF228B22);
  });
}
