import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../lib/app/font_controller.dart';

void main() {
  test('font controller cycles sans -> serif -> mono -> sans', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(fontTypeProvider), FontType.sans);

    container.read(fontTypeProvider.notifier).cycle();
    expect(container.read(fontTypeProvider), FontType.serif);

    container.read(fontTypeProvider.notifier).cycle();
    expect(container.read(fontTypeProvider), FontType.mono);

    container.read(fontTypeProvider.notifier).cycle();
    expect(container.read(fontTypeProvider), FontType.sans);
  });
}
