import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Love/data/backup/android_backup_file_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.love/backup');
  const picker = AndroidBackupFilePicker();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('requests unrestricted backup bytes from the Android picker', () async {
    MethodCall? receivedCall;
    final expected = Uint8List.fromList([1, 2, 3]);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          receivedCall = call;
          return expected;
        });

    final bytes = await picker.pickBackup();

    expect(receivedCall?.method, 'pickBackup');
    expect(receivedCall?.arguments, isNull);
    expect(bytes, expected);
  });

  test('returns null when the Android picker is cancelled', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);

    expect(await picker.pickBackup(), isNull);
  });
}
