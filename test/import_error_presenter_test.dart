import 'package:flutter_test/flutter_test.dart';

import '../lib/data/import/import_error_presenter.dart';
import '../lib/data/import/import_exception.dart';

void main() {
  test('non-import exception -> release-safe message', () {
    final msg = ImportErrorPresenter.toUserMessage(Exception('x'));
    expect(msg, 'Import failed. Please check data pack.');
  });

  test('import exception includes detail in debug mode', () {
    final ex = ImportException(
      code: 'MISSING_TABLE',
      message: 'Required table missing: verses',
      phase: 'Validate Bible',
      detail: 'verses',
    );
    final msg = ImportErrorPresenter.toUserMessage(ex);
    expect(msg.contains('ImportException(MISSING_TABLE)'), isTrue);
    expect(msg.contains('Validate Bible'), isTrue);
  });
}
