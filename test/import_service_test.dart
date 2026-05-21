import 'package:flutter_test/flutter_test.dart';

import '../lib/data/import/import_service.dart';

void main() {
  test('import service validates real bundled bible db schema', () {
    const service = ImportService();

    service.validateBibleFile('assets/data/getbible/en_kjv.sqlite');
  });

  test('import service validates real commentary db schema', () {
    const service = ImportService();

    service.validateCommentaryFile('assets/data/comment/com_tsk.sqlite');
  });
}
