import 'package:flutter_test/flutter_test.dart';
import 'package:Love/app/app_update_checker.dart';

void main() {
  test(
    'reports an update when latest release commit differs from build',
    () async {
      final checker = AppUpdateChecker(
        buildCommit: '1111111111111111111111111111111111111111',
        fetchReleaseJson: (_) async => '''
        {
          "target_commitish": "2222222222222222222222222222222222222222",
          "html_url": "https://github.com/ParkSnoopy/Love/releases/tag/rolling-20260824"
        }
      ''',
      );

      final result = await checker.check();

      expect(result.updateAvailable, isTrue);
      expect(
        result.releasePage,
        Uri.parse(
          'https://github.com/ParkSnoopy/Love/releases/tag/rolling-20260824',
        ),
      );
    },
  );

  test('reports current build when latest release commit matches', () async {
    final checker = AppUpdateChecker(
      buildCommit: 'ABCDEF1234',
      fetchReleaseJson: (_) async => '''
        {
          "target_commitish": "abcdef1234",
          "html_url": "https://github.com/ParkSnoopy/Love/releases/latest"
        }
      ''',
    );

    final result = await checker.check();

    expect(result.updateAvailable, isFalse);
  });

  test('rejects missing build commit metadata', () async {
    final checker = AppUpdateChecker(
      buildCommit: AppUpdateChecker.unknownBuildCommit,
      fetchReleaseJson: (_) async => '{}',
    );

    expect(checker.check, throwsA(isA<AppUpdateCheckException>()));
  });

  test('rejects malformed latest release metadata', () async {
    final checker = AppUpdateChecker(
      buildCommit: 'abcdef1234',
      fetchReleaseJson: (_) async => '{"target_commitish":"main"}',
    );

    expect(checker.check, throwsA(isA<AppUpdateCheckException>()));
  });

  test('uses the latest Love release endpoint', () async {
    Uri? requestedUri;
    final checker = AppUpdateChecker(
      buildCommit: 'abcdef1234',
      fetchReleaseJson: (uri) async {
        requestedUri = uri;
        return '''
          {
            "target_commitish": "abcdef1234",
            "html_url": "https://github.com/ParkSnoopy/Love/releases/latest"
          }
        ''';
      },
    );

    await checker.check();

    expect(
      requestedUri,
      Uri.parse('https://api.github.com/repos/ParkSnoopy/Love/releases/latest'),
    );
  });
}
