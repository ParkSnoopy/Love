import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Love/app/app_localizations.dart';
import 'package:Love/app/app_update_checker.dart';
import 'package:Love/features/library/presentation/app_update_tile.dart';

void main() {
  Widget buildApp(
    AppUpdateChecker checker, {
    ReleasePageOpener? openReleasePage,
  }) {
    return MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: AppUpdateTile(
          checker: checker,
          openReleasePage: openReleasePage ?? (_) async => true,
        ),
      ),
    );
  }

  testWidgets('shows and opens the latest release when update is available', (
    tester,
  ) async {
    Uri? openedPage;
    final checker = AppUpdateChecker(
      buildCommit: '1111111111',
      fetchReleaseJson: (_) async => '''
        {
          "target_commitish": "2222222222",
          "html_url": "https://github.com/ParkSnoopy/Love/releases/tag/latest"
        }
      ''',
    );
    await tester.pumpWidget(
      buildApp(
        checker,
        openReleasePage: (uri) async {
          openedPage = uri;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check update'));
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('Open latest release'), findsOneWidget);

    await tester.tap(find.text('Open latest release'));
    await tester.pumpAndSettle();

    expect(
      openedPage,
      Uri.parse('https://github.com/ParkSnoopy/Love/releases/tag/latest'),
    );
  });

  testWidgets('reports when the installed build is current', (tester) async {
    final checker = AppUpdateChecker(
      buildCommit: '1111111111',
      fetchReleaseJson: (_) async => '''
        {
          "target_commitish": "1111111111",
          "html_url": "https://github.com/ParkSnoopy/Love/releases/tag/latest"
        }
      ''',
    );
    await tester.pumpWidget(buildApp(checker));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check update'));
    await tester.pumpAndSettle();

    expect(find.text('Love is up to date.'), findsOneWidget);
    expect(find.text('Update available'), findsNothing);
  });

  testWidgets('reports a failed update check', (tester) async {
    final checker = AppUpdateChecker(
      buildCommit: AppUpdateChecker.unknownBuildCommit,
      fetchReleaseJson: (_) async => '{}',
    );
    await tester.pumpWidget(buildApp(checker));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check update'));
    await tester.pumpAndSettle();

    expect(find.text('Could not check for updates.'), findsOneWidget);
  });
}
