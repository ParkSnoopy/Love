import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_configuration.dart';
import 'app_preferences.dart';

enum AppThemeMode {
  system(0, ThemeMode.system),
  lightOrange(1, ThemeMode.light),
  lightGreen(3, ThemeMode.light),
  darkOrange(4, ThemeMode.dark),
  darkPurple(2, ThemeMode.dark);

  const AppThemeMode(this.storageIndex, this.materialThemeMode);

  final int storageIndex;
  final ThemeMode materialThemeMode;

  static AppThemeMode fromStorageIndex(int index) => values.firstWhere(
    (mode) => mode.storageIndex == index,
    orElse: () => system,
  );
}

final themeModeProvider =
    AsyncNotifierProvider<ThemeModeController, AppThemeMode>(
      ThemeModeController.new,
    );

class ThemeModeController extends AsyncNotifier<AppThemeMode> {
  static const _key = AppConfiguration.appThemeModeKey;

  @override
  Future<AppThemeMode> build() async {
    final prefs = await AppPreferences.getInstance();
    final index = prefs.getInt(_key) ?? AppConfiguration.appThemeModeDefault;
    return AppThemeMode.fromStorageIndex(index);
  }

  Future<void> cycle() async {
    final current = state.value ?? AppThemeMode.system;
    final next = switch (current) {
      AppThemeMode.system => AppThemeMode.lightOrange,
      AppThemeMode.lightOrange => AppThemeMode.lightGreen,
      AppThemeMode.lightGreen => AppThemeMode.darkOrange,
      AppThemeMode.darkOrange => AppThemeMode.darkPurple,
      AppThemeMode.darkPurple => AppThemeMode.system,
    };
    final prefs = await AppPreferences.getInstance();
    await prefs.setInt(_key, next.storageIndex);
    state = AsyncData(next);
  }
}
