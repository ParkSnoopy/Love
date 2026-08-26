import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_configuration.dart';
import 'app_preferences.dart';

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
    required this.customBase,
    required this.customPrimaryValue,
  });

  final CustomThemeBase customBase;
  final int customPrimaryValue;

  static const defaults = AppThemeSettings(
    customBase: CustomThemeBase.light,
    customPrimaryValue: AppConfiguration.customThemePrimaryDefault,
  );

  ThemeMode get materialThemeMode => customBase.materialThemeMode;

  AppThemeSettings copyWith({
    CustomThemeBase? customBase,
    int? customPrimaryValue,
  }) => AppThemeSettings(
    customBase: customBase ?? this.customBase,
    customPrimaryValue: customPrimaryValue ?? this.customPrimaryValue,
  );
}

final themeProvider = AsyncNotifierProvider<ThemeController, AppThemeSettings>(
  ThemeController.new,
);

class ThemeController extends AsyncNotifier<AppThemeSettings> {
  @override
  Future<AppThemeSettings> build() async {
    final prefs = await AppPreferences.getInstance();
    final customBase = CustomThemeBase.fromStorageIndex(
      prefs.getInt(AppConfiguration.customThemeBaseKey) ??
          AppConfiguration.customThemeBaseDefault,
    );
    final customPrimaryValue = _validatedPrimaryValue(
      prefs.getInt(AppConfiguration.customThemePrimaryKey),
    );
    return AppThemeSettings(
      customBase: customBase,
      customPrimaryValue: customPrimaryValue,
    );
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
    });
    state = AsyncData(
      AppThemeSettings(customBase: base, customPrimaryValue: validatedPrimary),
    );
  }

  static int _validatedPrimaryValue(int? value) =>
      value != null && value >= 0 && value <= 0xFFFFFFFF
      ? value | 0xFF000000
      : AppConfiguration.customThemePrimaryDefault;
}
