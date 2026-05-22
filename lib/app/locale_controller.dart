import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_preferences.dart';

class AppLocaleController extends AsyncNotifier<Locale?> {
  static const _key = 'app_locale_code';

  @override
  Future<Locale?> build() async {
    final prefs = await AppPreferences.getInstance();
    final code = prefs.getString(_key);
    return _localeFromCode(code);
  }

  Future<void> setLocale(Locale? locale) async {
    final prefs = await AppPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
    state = AsyncData(locale);
  }

  Future<void> cycle() async {
    final current = state.value;
    final next = switch (current?.languageCode) {
      null => const Locale('ko'),
      'ko' => const Locale('en'),
      'en' => const Locale('zh'),
      'zh' => const Locale('ja'),
      _ => null,
    };
    await setLocale(next);
  }

  Locale? _localeFromCode(String? code) {
    return switch (code) {
      'ko' => const Locale('ko'),
      'en' => const Locale('en'),
      'zh' => const Locale('zh'),
      'ja' => const Locale('ja'),
      _ => null,
    };
  }
}

final appLocaleProvider = AsyncNotifierProvider<AppLocaleController, Locale?>(
  AppLocaleController.new,
);
