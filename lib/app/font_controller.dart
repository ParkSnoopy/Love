import 'package:flutter_riverpod/flutter_riverpod.dart';

enum FontType { sans, serif, mono }

final fontTypeProvider = NotifierProvider<FontTypeController, FontType>(
  FontTypeController.new,
);

class FontTypeController extends Notifier<FontType> {
  @override
  FontType build() => FontType.sans;

  void cycle() {
    state = switch (state) {
      FontType.sans => FontType.serif,
      FontType.serif => FontType.mono,
      FontType.mono => FontType.sans,
    };
  }
}
