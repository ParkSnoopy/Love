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

  test('provides the four named theme palettes', () {
    final lightOrange = buildLightOrangeTheme('NotoSerifCJK');
    final lightGreen = buildLightGreenTheme('NotoSerifCJK');
    final darkOrange = buildDarkOrangeTheme('NotoSerifCJK');
    final darkPurple = buildDarkPurpleTheme('NotoSerifCJK');

    expect(lightOrange.brightness, Brightness.light);
    expect(lightOrange.colorScheme.primary, const Color(0xFFCC785C));
    expect(lightGreen.brightness, Brightness.light);
    expect(lightGreen.colorScheme.primary, const Color(0xFF228B22));
    expect(
      lightGreen.scaffoldBackgroundColor,
      lightOrange.scaffoldBackgroundColor,
    );
    expect(darkOrange.brightness, Brightness.dark);
    expect(darkOrange.colorScheme.primary, lightOrange.colorScheme.primary);
    expect(darkPurple.brightness, Brightness.dark);
    expect(
      darkPurple.colorScheme.primary,
      ThemeData.dark().colorScheme.primary,
    );
  });

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

  test('cycles named themes while preserving stored theme values', () async {
    AppPreferences.useMemoryStoreForTesting({
      AppConfiguration.appThemeModeKey: ThemeMode.dark.index,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      (await container.read(themeModeProvider.future)).mode,
      AppThemeMode.darkPurple,
    );

    const expected = [
      AppThemeMode.system,
      AppThemeMode.lightOrange,
      AppThemeMode.lightGreen,
      AppThemeMode.darkOrange,
      AppThemeMode.darkPurple,
    ];
    for (final theme in expected) {
      await container.read(themeModeProvider.notifier).cycle();
      expect(container.read(themeModeProvider).value?.mode, theme);
    }
  });

  test('persists custom base and primary color together', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(themeModeProvider.future);

    await container
        .read(themeModeProvider.notifier)
        .setCustomTheme(base: CustomThemeBase.dark, primaryValue: 0xFF1565C0);

    final settings = container.read(themeModeProvider).requireValue;
    expect(settings.mode, AppThemeMode.custom);
    expect(settings.customBase, CustomThemeBase.dark);
    expect(settings.customPrimaryValue, 0xFF1565C0);
    expect(settings.materialThemeMode, ThemeMode.dark);

    final preferences = await AppPreferences.getInstance();
    expect(
      preferences.getInt(AppConfiguration.appThemeModeKey),
      AppThemeMode.custom.storageIndex,
    );
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
      AppConfiguration.appThemeModeKey: AppThemeMode.custom.storageIndex,
      AppConfiguration.customThemeBaseKey: 99,
      AppConfiguration.customThemePrimaryKey: -1,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final settings = await container.read(themeModeProvider.future);

    expect(settings.mode, AppThemeMode.custom);
    expect(settings.customBase, CustomThemeBase.light);
    expect(
      settings.customPrimaryValue,
      AppConfiguration.customThemePrimaryDefault,
    );
  });
}
