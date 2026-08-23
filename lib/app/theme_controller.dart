import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_configuration.dart';
import 'app_preferences.dart';

final themeModeProvider = AsyncNotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends AsyncNotifier<ThemeMode> {
  static const _key = AppConfiguration.appThemeModeKey;

  @override
  Future<ThemeMode> build() async {
    final prefs = await AppPreferences.getInstance();
    final index = prefs.getInt(_key) ?? AppConfiguration.appThemeModeDefault;
    if (index >= 0 && index < ThemeMode.values.length) {
      return ThemeMode.values[index];
    }
    return ThemeMode.system;
  }

  Future<void> cycle() async {
    final current = state.value ?? ThemeMode.system;
    final next = switch (current) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    final prefs = await AppPreferences.getInstance();
    await prefs.setInt(_key, next.index);
    state = AsyncData(next);
  }
}
