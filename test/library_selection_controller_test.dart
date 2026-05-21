import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../lib/features/library/providers/library_controller.dart';

void main() {
  test('library selection sets active bible pack id', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(activeBiblePackIdProvider), isNull);

    container.read(activeBiblePackIdProvider.notifier).select('en_kjv');
    expect(container.read(activeBiblePackIdProvider), 'en_kjv');
  });
}
