import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_configuration.dart';
import 'app_preferences.dart';

class ReaderSettingsState {
  const ReaderSettingsState({
    required this.fontSize,
    required this.lineSpacing,
    this.uiScale = 1.0,
    this.fontWeight = FontWeight.normal,
  });

  final double fontSize;
  final double lineSpacing;
  final double uiScale;
  final FontWeight fontWeight;
}

class ReaderSettingsController extends AsyncNotifier<ReaderSettingsState> {
  static const _keyFontSize = AppConfiguration.readerFontSizeKey;
  static const _keyLineSpacing = AppConfiguration.readerLineSpacingKey;
  static const _keyUiScale = AppConfiguration.uiScaleKey;
  static const _keyFontWeight = AppConfiguration.readerFontWeightKey;

  @override
  Future<ReaderSettingsState> build() async {
    final prefs = await AppPreferences.getInstance();
    final fontSize =
        prefs.getDouble(_keyFontSize) ?? AppConfiguration.readerFontSizeDefault;
    final lineSpacing =
        prefs.getDouble(_keyLineSpacing) ??
        AppConfiguration.readerLineSpacingDefault;
    final uiScale =
        prefs.getDouble(_keyUiScale) ?? AppConfiguration.uiScaleDefault;
    final fontWeightIndex =
        prefs.getInt(_keyFontWeight) ??
        AppConfiguration.readerFontWeightDefault;
    final fontWeight =
        fontWeightIndex >= 0 && fontWeightIndex < FontWeight.values.length
        ? FontWeight.values[fontWeightIndex]
        : FontWeight.normal;
    return ReaderSettingsState(
      fontSize: fontSize,
      lineSpacing: lineSpacing,
      uiScale: uiScale,
      fontWeight: fontWeight,
    );
  }

  Future<void> setFontSize(double val) async {
    final prefs = await AppPreferences.getInstance();
    await prefs.setDouble(_keyFontSize, val);
    state = AsyncData(
      ReaderSettingsState(
        fontSize: val,
        lineSpacing:
            state.value?.lineSpacing ??
            AppConfiguration.readerLineSpacingDefault,
        uiScale: state.value?.uiScale ?? AppConfiguration.uiScaleDefault,
        fontWeight: state.value?.fontWeight ?? FontWeight.normal,
      ),
    );
  }

  Future<void> setLineSpacing(double val) async {
    final prefs = await AppPreferences.getInstance();
    await prefs.setDouble(_keyLineSpacing, val);
    state = AsyncData(
      ReaderSettingsState(
        fontSize:
            state.value?.fontSize ?? AppConfiguration.readerFontSizeDefault,
        lineSpacing: val,
        uiScale: state.value?.uiScale ?? AppConfiguration.uiScaleDefault,
        fontWeight: state.value?.fontWeight ?? FontWeight.normal,
      ),
    );
  }

  Future<void> setUiScale(double val) async {
    final prefs = await AppPreferences.getInstance();
    await prefs.setDouble(_keyUiScale, val);
    state = AsyncData(
      ReaderSettingsState(
        fontSize:
            state.value?.fontSize ?? AppConfiguration.readerFontSizeDefault,
        lineSpacing:
            state.value?.lineSpacing ??
            AppConfiguration.readerLineSpacingDefault,
        uiScale: val,
        fontWeight: state.value?.fontWeight ?? FontWeight.normal,
      ),
    );
  }

  Future<void> setFontWeight(FontWeight val) async {
    final prefs = await AppPreferences.getInstance();
    await prefs.setInt(_keyFontWeight, FontWeight.values.indexOf(val));
    state = AsyncData(
      ReaderSettingsState(
        fontSize:
            state.value?.fontSize ?? AppConfiguration.readerFontSizeDefault,
        lineSpacing:
            state.value?.lineSpacing ??
            AppConfiguration.readerLineSpacingDefault,
        uiScale: state.value?.uiScale ?? AppConfiguration.uiScaleDefault,
        fontWeight: val,
      ),
    );
  }
}

final readerSettingsProvider =
    AsyncNotifierProvider<ReaderSettingsController, ReaderSettingsState>(
      ReaderSettingsController.new,
    );
