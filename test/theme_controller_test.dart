import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Love/app/app_configuration.dart';
import 'package:Love/app/app_preferences.dart';
import 'package:Love/app/app_theme.dart';
import 'package:Love/app/theme_controller.dart';

void main() {
  setUp(AppPreferences.useMemoryStoreForTesting);
  tearDown(AppPreferences.clearMemoryStoreForTesting);

  test('builds contrast-aware custom palettes on either base', () {
    const primary = Color(0xFFFFF59D);
    final light = buildCustomTheme(
      'NotoSerifCJK',
      brightness: Brightness.light,
      primary: primary,
    );
    final dark = buildCustomTheme(
      'NotoSerifCJK',
      brightness: Brightness.dark,
      primary: primary,
    );

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.colorScheme.primary, primary);
    expect(dark.colorScheme.primary, primary);
    expect(light.colorScheme.onPrimary, Colors.black);
    expect(dark.colorScheme.onPrimary, Colors.black);
    expect(light.scaffoldBackgroundColor, const Color(0xFFFAF9F5));
    expect(
      dark.scaffoldBackgroundColor,
      ThemeData.dark().scaffoldBackgroundColor,
    );
  });

  test('persists custom base and primary color together', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(themeProvider.future);

    await container
        .read(themeProvider.notifier)
        .setCustomTheme(base: CustomThemeBase.dark, primaryValue: 0xFF1565C0);

    final settings = container.read(themeProvider).requireValue;
    expect(settings.customBase, CustomThemeBase.dark);
    expect(settings.customPrimaryValue, 0xFF1565C0);
    expect(settings.materialThemeMode, ThemeMode.dark);

    final preferences = await AppPreferences.getInstance();
    expect(
      preferences.getInt(AppConfiguration.customThemeBaseKey),
      CustomThemeBase.dark.storageIndex,
    );
    expect(
      preferences.getInt(AppConfiguration.customThemePrimaryKey),
      0xFF1565C0,
    );
  });

  test('falls back from invalid imported custom values', () async {
    AppPreferences.useMemoryStoreForTesting({
      AppConfiguration.customThemeBaseKey: 99,
      AppConfiguration.customThemePrimaryKey: -1,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final settings = await container.read(themeProvider.future);

    expect(settings.customBase, CustomThemeBase.light);
    expect(
      settings.customPrimaryValue,
      AppConfiguration.customThemePrimaryDefault,
    );
  });

  test('ignores retired preset theme selection', () async {
    AppPreferences.useMemoryStoreForTesting({
      'app_theme_mode': 2,
      AppConfiguration.customThemeBaseKey: CustomThemeBase.dark.storageIndex,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final settings = await container.read(themeProvider.future);

    expect(settings.customBase, CustomThemeBase.dark);
    expect(settings.materialThemeMode, ThemeMode.dark);
  });
}
