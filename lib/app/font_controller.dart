import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_preferences.dart';

enum FontType { sans, serif }

String fontFamilyForType(FontType fontType) {
  return switch (fontType) {
    FontType.sans => 'NotoSansCJK',
    FontType.serif => 'NotoSerifCJK',
  };
}

final fontTypeProvider = AsyncNotifierProvider<FontTypeController, FontType>(
  FontTypeController.new,
);

class FontTypeController extends AsyncNotifier<FontType> {
  static const _key = 'reader_font_type';

  @override
  Future<FontType> build() async {
    final prefs = await AppPreferences.getInstance();
    final index = prefs.getInt(_key) ?? FontType.serif.index;
    if (index >= 0 && index < FontType.values.length) {
      return FontType.values[index];
    }
    return FontType.serif;
  }

  Future<void> cycle() async {
    final current = state.value ?? FontType.serif;
    final next = switch (current) {
      FontType.sans => FontType.serif,
      FontType.serif => FontType.sans,
    };
    final prefs = await AppPreferences.getInstance();
    await prefs.setInt(_key, next.index);
    state = AsyncData(next);
  }
}
