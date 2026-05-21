import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FontType { sans, serif, mono }

String fontFamilyForType(FontType fontType) {
  return switch (fontType) {
    FontType.sans => 'NotoSansKR',
    FontType.serif => 'NotoSerifKR',
    FontType.mono => 'NanumGothicCoding',
  };
}

final fontTypeProvider = AsyncNotifierProvider<FontTypeController, FontType>(
  FontTypeController.new,
);

class FontTypeController extends AsyncNotifier<FontType> {
  static const _key = 'reader_font_type';

  @override
  Future<FontType> build() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_key) ?? FontType.sans.index;
    if (index >= 0 && index < FontType.values.length) {
      return FontType.values[index];
    }
    return FontType.sans;
  }

  Future<void> cycle() async {
    final current = state.value ?? FontType.sans;
    final next = switch (current) {
      FontType.sans => FontType.serif,
      FontType.serif => FontType.mono,
      FontType.mono => FontType.sans,
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, next.index);
    state = AsyncData(next);
  }
}
