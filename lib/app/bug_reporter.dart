import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class BugReportLog {
  BugReportLog._();

  static const int _maxEntries = 40;
  static final List<String> _entries = <String>[];

  static void record(Object error, StackTrace? stackTrace) {
    final timestamp = DateTime.now().toIso8601String();
    final buffer = StringBuffer()
      ..writeln('[$timestamp] ${error.runtimeType}: $error');
    if (stackTrace != null) {
      buffer.writeln(stackTrace);
    }
    _entries.add(buffer.toString().trimRight());
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
  }

  static void recordFlutterError(FlutterErrorDetails details) {
    record(details.exception, details.stack);
  }

  static String recentText({int maxChars = 6000}) {
    if (_entries.isEmpty) {
      return 'No captured errors in this session.';
    }

    final text = _entries.join('\n\n---\n\n');
    if (text.length <= maxChars) {
      return text;
    }

    return '... trimmed older log entries ...\n${text.substring(text.length - maxChars)}';
  }
}

class BugReporter {
  BugReporter._();

  static const String _issueUrl =
      'https://github.com/ParkSnoopy/Love/issues/new';

  static Uri issueUri({String? body}) {
    return Uri.parse(_issueUrl).replace(
      queryParameters: <String, String>{
        'title': '[Bug]: ',
        'body': body ?? issueBody(),
      },
    );
  }

  static String issueBody() {
    final timestamp = DateTime.now().toIso8601String();
    return '''## What happened?

<!-- Please describe what you were doing and what went wrong. -->

## Expected behavior

<!-- What did you expect to happen? -->

## Environment

- App: Love
- Platform: ${defaultTargetPlatform.name}
- Report created: $timestamp

## Captured error log

<!-- This log is captured locally from this app session. Remove anything you do not want to share before submitting. -->

```text
${BugReportLog.recentText()}
```
''';
  }

  static Future<bool> openIssue() async {
    final body = issueBody();
    await Clipboard.setData(ClipboardData(text: body));
    try {
      return launchUrl(
        issueUri(body: body),
        mode: LaunchMode.externalApplication,
      );
    } catch (error, stackTrace) {
      BugReportLog.record(error, stackTrace);
      return false;
    }
  }
}
