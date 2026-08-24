import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_configuration.dart';
import 'app_preferences.dart';

enum AppThemeMode {
  system(0, ThemeMode.system),
  lightOrange(1, ThemeMode.light),
  lightGreen(3, ThemeMode.light),
  darkOrange(4, ThemeMode.dark),
  darkPurple(2, ThemeMode.dark),
  custom(5, ThemeMode.light);

  const AppThemeMode(this.storageIndex, this.materialThemeMode);

  final int storageIndex;
  final ThemeMode materialThemeMode;

  static AppThemeMode fromStorageIndex(int index) => values.firstWhere(
    (mode) => mode.storageIndex == index,
    orElse: () => system,
  );
}

enum CustomThemeBase {
  light(0, Brightness.light, ThemeMode.light),
  dark(1, Brightness.dark, ThemeMode.dark);

  const CustomThemeBase(
    this.storageIndex,
    this.brightness,
    this.materialThemeMode,
  );

  final int storageIndex;
  final Brightness brightness;
  final ThemeMode materialThemeMode;

  static CustomThemeBase fromStorageIndex(int index) => values.firstWhere(
    (base) => base.storageIndex == index,
    orElse: () => light,
  );
}

@immutable
class AppThemeSettings {
  const AppThemeSettings({
    required this.mode,
    required this.customBase,
    required this.customPrimaryValue,
  });

  final AppThemeMode mode;
  final CustomThemeBase customBase;
  final int customPrimaryValue;

  static const defaults = AppThemeSettings(
    mode: AppThemeMode.system,
    customBase: CustomThemeBase.light,
    customPrimaryValue: AppConfiguration.customThemePrimaryDefault,
  );

  ThemeMode get materialThemeMode => mode == AppThemeMode.custom
      ? customBase.materialThemeMode
      : mode.materialThemeMode;

  AppThemeSettings copyWith({
    AppThemeMode? mode,
    CustomThemeBase? customBase,
    int? customPrimaryValue,
  }) => AppThemeSettings(
    mode: mode ?? this.mode,
    customBase: customBase ?? this.customBase,
    customPrimaryValue: customPrimaryValue ?? this.customPrimaryValue,
  );
}

final themeModeProvider =
    AsyncNotifierProvider<ThemeModeController, AppThemeSettings>(
      ThemeModeController.new,
    );

class ThemeModeController extends AsyncNotifier<AppThemeSettings> {
  @override
  Future<AppThemeSettings> build() async {
    final prefs = await AppPreferences.getInstance();
    final mode = AppThemeMode.fromStorageIndex(
      prefs.getInt(AppConfiguration.appThemeModeKey) ??
          AppConfiguration.appThemeModeDefault,
    );
    final customBase = CustomThemeBase.fromStorageIndex(
      prefs.getInt(AppConfiguration.customThemeBaseKey) ??
          AppConfiguration.customThemeBaseDefault,
    );
    final customPrimaryValue = _validatedPrimaryValue(
      prefs.getInt(AppConfiguration.customThemePrimaryKey),
    );
    return AppThemeSettings(
      mode: mode,
      customBase: customBase,
      customPrimaryValue: customPrimaryValue,
    );
  }

  Future<void> cycle() async {
    final current = state.value ?? AppThemeSettings.defaults;
    final next = switch (current.mode) {
      AppThemeMode.system => AppThemeMode.lightOrange,
      AppThemeMode.lightOrange => AppThemeMode.lightGreen,
      AppThemeMode.lightGreen => AppThemeMode.darkOrange,
      AppThemeMode.darkOrange => AppThemeMode.darkPurple,
      AppThemeMode.darkPurple || AppThemeMode.custom => AppThemeMode.system,
    };
    await setMode(next);
  }

  Future<void> setMode(AppThemeMode mode) async {
    final prefs = await AppPreferences.getInstance();
    await prefs.setInt(AppConfiguration.appThemeModeKey, mode.storageIndex);
    final current = state.requireValue;
    state = AsyncData(current.copyWith(mode: mode));
  }

  Future<void> setCustomTheme({
    required CustomThemeBase base,
    required int primaryValue,
  }) async {
    final validatedPrimary = _validatedPrimaryValue(primaryValue);
    final prefs = await AppPreferences.getInstance();
    await prefs.setValues({
      AppConfiguration.customThemeBaseKey: base.storageIndex,
      AppConfiguration.customThemePrimaryKey: validatedPrimary,
      AppConfiguration.appThemeModeKey: AppThemeMode.custom.storageIndex,
    });
    state = AsyncData(
      AppThemeSettings(
        mode: AppThemeMode.custom,
        customBase: base,
        customPrimaryValue: validatedPrimary,
      ),
    );
  }

  static int _validatedPrimaryValue(int? value) =>
      value != null && value >= 0 && value <= 0xFFFFFFFF
      ? value | 0xFF000000
      : AppConfiguration.customThemePrimaryDefault;
}
