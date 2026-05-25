import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const appStorageFolderName = 'love';

String fallbackAppDataPath() {
  final home = Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) {
    return p.join(home, '.local', 'share', appStorageFolderName);
  }
  return p.join(Directory.current.path, '.$appStorageFolderName');
}

Future<Directory> getAppDataDirectory() async {
  try {
    return await getApplicationSupportDirectory();
  } catch (_) {
    return Directory(fallbackAppDataPath());
  }
}
