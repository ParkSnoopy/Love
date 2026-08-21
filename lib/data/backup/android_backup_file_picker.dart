import 'package:flutter/services.dart';

class AndroidBackupFilePicker {
  const AndroidBackupFilePicker();

  static const _channel = MethodChannel('com.example.love/backup');

  Future<Uint8List?> pickBackup() =>
      _channel.invokeMethod<Uint8List>('pickBackup');
}
