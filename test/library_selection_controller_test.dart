import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/features/library/providers/library_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('library selection sets active bible pack selection', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(activeBibleSelectionProvider.future);

    await container
        .read(activeBibleSelectionProvider.notifier)
        .select(id: 'en_kjv', file: 'getbible/en_kjv.sqlite');

    final selected = container.read(activeBibleSelectionProvider).asData?.value;
    expect(selected?.id, 'en_kjv');
    expect(selected?.file, 'getbible/en_kjv.sqlite');
  });
}
