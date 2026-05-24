import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_preferences.dart';

class ReaderSettingsState {
  const ReaderSettingsState({
    required this.fontSize,
    required this.lineSpacing,
    this.uiScale = 1.0,
  });

  final double fontSize;
  final double lineSpacing;
  final double uiScale;
}

class ReaderSettingsController extends AsyncNotifier<ReaderSettingsState> {
  static const _keyFontSize = 'reader_font_size';
  static const _keyLineSpacing = 'reader_line_spacing';
  static const _keyUiScale = 'ui_scale';

  @override
  Future<ReaderSettingsState> build() async {
    final prefs = await AppPreferences.getInstance();
    final fontSize = prefs.getDouble(_keyFontSize) ?? 18.0;
    final lineSpacing = prefs.getDouble(_keyLineSpacing) ?? 1.5;
    final uiScale = prefs.getDouble(_keyUiScale) ?? 1.0;
    return ReaderSettingsState(
      fontSize: fontSize,
      lineSpacing: lineSpacing,
      uiScale: uiScale,
    );
  }

  Future<void> setFontSize(double val) async {
    final prefs = await AppPreferences.getInstance();
    await prefs.setDouble(_keyFontSize, val);
    state = AsyncData(
      ReaderSettingsState(
        fontSize: val,
        lineSpacing: state.value?.lineSpacing ?? 1.5,
        uiScale: state.value?.uiScale ?? 1.0,
      ),
    );
  }

  Future<void> setLineSpacing(double val) async {
    final prefs = await AppPreferences.getInstance();
    await prefs.setDouble(_keyLineSpacing, val);
    state = AsyncData(
      ReaderSettingsState(
        fontSize: state.value?.fontSize ?? 18.0,
        lineSpacing: val,
        uiScale: state.value?.uiScale ?? 1.0,
      ),
    );
  }

  Future<void> setUiScale(double val) async {
    final prefs = await AppPreferences.getInstance();
    await prefs.setDouble(_keyUiScale, val);
    state = AsyncData(
      ReaderSettingsState(
        fontSize: state.value?.fontSize ?? 18.0,
        lineSpacing: state.value?.lineSpacing ?? 1.5,
        uiScale: val,
      ),
    );
  }
}

final readerSettingsProvider =
    AsyncNotifierProvider<ReaderSettingsController, ReaderSettingsState>(
      ReaderSettingsController.new,
    );
