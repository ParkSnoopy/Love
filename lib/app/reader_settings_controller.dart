import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_configuration.dart';
import 'app_preferences.dart';
import 'font_controller.dart';
import 'super_otc_font_loader.dart';

enum ReaderFontWeight {
  thin(FontWeight.w100),
  extraLight(FontWeight.w200),
  light(FontWeight.w300),
  demiLight(FontWeight.w300),
  normal(FontWeight.w400),
  medium(FontWeight.w500),
  semiBold(FontWeight.w600),
  bold(FontWeight.w700),
  black(FontWeight.w900);

  const ReaderFontWeight(this.flutterWeight);

  final FontWeight flutterWeight;

  static const _sansValues = [
    thin,
    light,
    demiLight,
    normal,
    medium,
    bold,
    black,
  ];
  static const _serifValues = [
    extraLight,
    light,
    normal,
    medium,
    semiBold,
    bold,
    black,
  ];

  static List<ReaderFontWeight> valuesFor(FontType fontType) =>
      switch (fontType) {
        FontType.sans => _sansValues,
        FontType.serif => _serifValues,
      };

  ReaderFontWeight resolveFor(FontType fontType) => switch ((fontType, this)) {
    (FontType.sans, extraLight) => thin,
    (FontType.sans, semiBold) => bold,
    (FontType.serif, thin) => extraLight,
    (FontType.serif, demiLight) => normal,
    _ => this,
  };

  FontWeight flutterWeightFor(FontType fontType) =>
      resolveFor(fontType).flutterWeight;

  String assetPathFor(FontType fontType) => switch (fontType) {
    FontType.sans => 'assets/fonts/NotoSansCJK.ttc',
    FontType.serif => 'assets/fonts/NotoSerifCJK.ttc',
  };

  int faceIndexFor(FontType fontType) {
    final resolved = resolveFor(fontType);
    return switch ((fontType, resolved)) {
      (FontType.sans, thin) => 1,
      (FontType.sans, light) => 6,
      (FontType.sans, demiLight) => 11,
      (FontType.sans, normal) => 26,
      (FontType.sans, medium) => 16,
      (FontType.sans, bold) => 36,
      (FontType.sans, black) => 21,
      (FontType.serif, extraLight) => 1,
      (FontType.serif, light) => 6,
      (FontType.serif, normal) => 11,
      (FontType.serif, medium) => 16,
      (FontType.serif, semiBold) => 21,
      (FontType.serif, bold) => 26,
      (FontType.serif, black) => 31,
      _ => throw StateError('Unsupported Super OTC font style'),
    };
  }

  String fontFamilyFor(FontType fontType) {
    final resolved = resolveFor(fontType);
    return switch ((fontType, resolved)) {
      (FontType.sans, thin) => 'NotoSansCJKThin',
      (FontType.sans, light) => 'NotoSansCJKLight',
      (FontType.sans, demiLight) => 'NotoSansCJKDemiLight',
      (FontType.sans, normal) => 'NotoSansCJK',
      (FontType.sans, medium) => 'NotoSansCJKMedium',
      (FontType.sans, bold) => 'NotoSansCJKBold',
      (FontType.sans, black) => 'NotoSansCJKBlack',
      (FontType.serif, extraLight) => 'NotoSerifCJKExtraLight',
      (FontType.serif, light) => 'NotoSerifCJKLight',
      (FontType.serif, normal) => 'NotoSerifCJK',
      (FontType.serif, medium) => 'NotoSerifCJKMedium',
      (FontType.serif, semiBold) => 'NotoSerifCJKSemiBold',
      (FontType.serif, bold) => 'NotoSerifCJKBold',
      (FontType.serif, black) => 'NotoSerifCJKBlack',
      _ => throw StateError('Unsupported Super OTC font style'),
    };
  }

  static ReaderFontWeight fromName(String? name) =>
      values.firstWhere((weight) => weight.name == name, orElse: () => normal);

  static ReaderFontWeight fromLegacyIndex(int index) => switch (index) {
    0 => thin,
    1 => extraLight,
    2 => light,
    3 => normal,
    4 => medium,
    5 => semiBold,
    6 => bold,
    7 || 8 => black,
    _ => normal,
  };
}

Future<void> ensureReaderFontWeightLoaded(ReaderFontWeight weight) async {
  for (final fontType in FontType.values) {
    await SuperOtcFontLoader.ensureLoaded(
      assetPath: weight.assetPathFor(fontType),
      faceIndex: weight.faceIndexFor(fontType),
      family: weight.fontFamilyFor(fontType),
    );
  }
}

class ReaderSettingsState {
  const ReaderSettingsState({
    required this.fontSize,
    required this.lineSpacing,
    this.uiScale = 1.0,
    this.fontWeight = ReaderFontWeight.normal,
  });

  final double fontSize;
  final double lineSpacing;
  final double uiScale;
  final ReaderFontWeight fontWeight;
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
    final savedFontWeight = prefs.getString(_keyFontWeight);
    final legacyFontWeightIndex = prefs.getInt(_keyFontWeight);
    final fontWeight = savedFontWeight != null
        ? ReaderFontWeight.fromName(savedFontWeight)
        : legacyFontWeightIndex != null
        ? ReaderFontWeight.fromLegacyIndex(legacyFontWeightIndex)
        : ReaderFontWeight.fromName(AppConfiguration.readerFontWeightDefault);
    if (savedFontWeight != fontWeight.name) {
      await prefs.setString(_keyFontWeight, fontWeight.name);
    }
    await ensureReaderFontWeightLoaded(fontWeight);
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
        fontWeight: state.value?.fontWeight ?? ReaderFontWeight.normal,
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
        fontWeight: state.value?.fontWeight ?? ReaderFontWeight.normal,
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
        fontWeight: state.value?.fontWeight ?? ReaderFontWeight.normal,
      ),
    );
  }

  Future<void> setFontWeight(ReaderFontWeight val) async {
    await ensureReaderFontWeightLoaded(val);
    final prefs = await AppPreferences.getInstance();
    await prefs.setString(_keyFontWeight, val.name);
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
