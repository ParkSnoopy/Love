import 'dart:convert';
import 'dart:io';

class AppUpdateCheckException implements Exception {
  const AppUpdateCheckException();
}

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.updateAvailable,
    required this.releasePage,
  });

  final bool updateAvailable;
  final Uri releasePage;
}

typedef ReleaseJsonFetcher = Future<String> Function(Uri uri);

class AppUpdateChecker {
  AppUpdateChecker({
    this.buildCommit = embeddedBuildCommit,
    ReleaseJsonFetcher? fetchReleaseJson,
  }) : _fetchReleaseJson = fetchReleaseJson ?? _fetchLatestReleaseJson;

  static const String unknownBuildCommit = 'unknown';
  static const String embeddedBuildCommit = String.fromEnvironment(
    'BUILD_COMMIT',
    defaultValue: unknownBuildCommit,
  );
  static final Uri latestReleaseApi = Uri.parse(
    'https://api.github.com/repos/ParkSnoopy/Love/releases/latest',
  );

  final String buildCommit;
  final ReleaseJsonFetcher _fetchReleaseJson;

  Future<AppUpdateCheckResult> check() async {
    final normalizedBuildCommit = buildCommit.trim().toLowerCase();
    if (normalizedBuildCommit.isEmpty ||
        normalizedBuildCommit == unknownBuildCommit) {
      throw const AppUpdateCheckException();
    }

    try {
      final decoded = jsonDecode(await _fetchReleaseJson(latestReleaseApi));
      if (decoded is! Map<String, dynamic>) {
        throw const AppUpdateCheckException();
      }
      final releaseCommit = decoded['target_commitish'];
      final releasePageValue = decoded['html_url'];
      if (releaseCommit is! String || releasePageValue is! String) {
        throw const AppUpdateCheckException();
      }
      final normalizedReleaseCommit = releaseCommit.trim().toLowerCase();
      final releasePage = Uri.tryParse(releasePageValue);
      if (normalizedReleaseCommit.isEmpty ||
          releasePage == null ||
          releasePage.scheme != 'https' ||
          releasePage.host != 'github.com' ||
          !releasePage.path.startsWith('/ParkSnoopy/Love/releases/')) {
        throw const AppUpdateCheckException();
      }

      return AppUpdateCheckResult(
        updateAvailable: normalizedBuildCommit != normalizedReleaseCommit,
        releasePage: releasePage,
      );
    } on AppUpdateCheckException {
      rethrow;
    } catch (_) {
      throw const AppUpdateCheckException();
    }
  }

  static Future<String> _fetchLatestReleaseJson(Uri uri) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, 'Love update checker');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw const AppUpdateCheckException();
      }
      return await response.transform(utf8.decoder).join();
    } finally {
      client.close(force: true);
    }
  }
}
