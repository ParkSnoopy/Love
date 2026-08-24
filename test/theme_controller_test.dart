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

  test('cycles named themes while preserving stored legacy modes', () async {
    AppPreferences.useMemoryStoreForTesting({
      AppConfiguration.appThemeModeKey: ThemeMode.dark.index,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      await container.read(themeModeProvider.future),
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
      expect(container.read(themeModeProvider).value, theme);
    }
  });
}
