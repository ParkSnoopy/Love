import 'package:flutter_test/flutter_test.dart';
import 'package:Love/app/bug_reporter.dart';

void main() {
  test('bug report targets Love repository', () {
    final uri = BugReporter.issueUri(body: 'test body');

    expect(uri.origin, 'https://github.com');
    expect(uri.path, '/ParkSnoopy/Love/issues/new');
    expect(uri.queryParameters['body'], 'test body');
  });
}
