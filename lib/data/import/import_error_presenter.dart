import 'package:flutter/foundation.dart';

import 'import_exception.dart';

class ImportErrorPresenter {
  static String toUserMessage(Object error) {
    if (error is! ImportException) {
      return 'Import failed. Please check data pack.';
    }
    if (kReleaseMode) {
      return 'Import failed. Please check data pack.';
    }
    return error.toString();
  }
}
