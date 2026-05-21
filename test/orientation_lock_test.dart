import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart' as app;

void main() {
  testWidgets('main requests portrait-only preferred orientations', (tester) async {
    MethodCall? captured;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          captured = call;
        }
        return null;
      },
    );

    await app.main();
    await tester.pump();

    expect(captured, isNotNull);
    final args = (captured!.arguments as List<dynamic>).cast<String>();
    expect(args, containsAllInOrder(<String>['DeviceOrientation.portraitUp', 'DeviceOrientation.portraitDown']));
    expect(args, isNot(contains('DeviceOrientation.landscapeLeft')));
    expect(args, isNot(contains('DeviceOrientation.landscapeRight')));

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });
}
