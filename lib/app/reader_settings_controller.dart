import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReaderSettingsState {
  const ReaderSettingsState({required this.fontSize, required this.lineSpacing});
  final double fontSize;
  final double lineSpacing;
}

class ReaderSettingsController extends AsyncNotifier<ReaderSettingsState> {
  static const _keyFontSize = 'reader_font_size';
  static const _keyLineSpacing = 'reader_line_spacing';

  @override
  Future<ReaderSettingsState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final fontSize = prefs.getDouble(_keyFontSize) ?? 16.0;
    final lineSpacing = prefs.getDouble(_keyLineSpacing) ?? 1.5;
    return ReaderSettingsState(fontSize: fontSize, lineSpacing: lineSpacing);
  }

  Future<void> setFontSize(double val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFontSize, val);
    state = AsyncData(ReaderSettingsState(
      fontSize: val,
      lineSpacing: state.value?.lineSpacing ?? 1.5,
    ));
  }

  Future<void> setLineSpacing(double val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyLineSpacing, val);
    state = AsyncData(ReaderSettingsState(
      fontSize: state.value?.fontSize ?? 16.0,
      lineSpacing: val,
    ));
  }
}

final readerSettingsProvider = AsyncNotifierProvider<ReaderSettingsController, ReaderSettingsState>(
  ReaderSettingsController.new,
);
