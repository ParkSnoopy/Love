import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Love/app/app_configuration.dart';
import 'package:Love/app/app_preferences.dart';
import 'package:Love/app/font_controller.dart';
import 'package:Love/app/reader_settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(AppPreferences.useMemoryStoreForTesting);
  tearDown(AppPreferences.clearMemoryStoreForTesting);

  test('exposes the actual Super OTC styles for each font family', () {
    expect(ReaderFontWeight.valuesFor(FontType.sans), [
      ReaderFontWeight.thin,
      ReaderFontWeight.light,
      ReaderFontWeight.demiLight,
      ReaderFontWeight.normal,
      ReaderFontWeight.medium,
      ReaderFontWeight.bold,
      ReaderFontWeight.black,
    ]);
    expect(ReaderFontWeight.valuesFor(FontType.serif), [
      ReaderFontWeight.extraLight,
      ReaderFontWeight.light,
      ReaderFontWeight.normal,
      ReaderFontWeight.medium,
      ReaderFontWeight.semiBold,
      ReaderFontWeight.bold,
      ReaderFontWeight.black,
    ]);
  });

  test('selects a distinct Super OTC face for every serif style', () {
    final styles = ReaderFontWeight.valuesFor(FontType.serif);

    expect(
      styles
          .map(
            (style) =>
                (style.fontFamilyFor(FontType.serif), style.flutterWeight),
          )
          .toSet(),
      hasLength(styles.length),
    );
    expect(styles.map((style) => style.flutterWeight), [
      FontWeight.w200,
      FontWeight.w300,
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w900,
    ]);
    expect(styles.map((style) => style.faceIndexFor(FontType.serif)), [
      1,
      6,
      11,
      16,
      21,
      26,
      31,
    ]);
  });

  test('selects every actual sans face from its Super OTC', () {
    final styles = ReaderFontWeight.valuesFor(FontType.sans);

    expect(styles.map((style) => style.faceIndexFor(FontType.sans)), [
      1,
      6,
      11,
      26,
      16,
      36,
      21,
    ]);
  });

  test('migrates a legacy numeric font weight to the enum name', () async {
    AppPreferences.useMemoryStoreForTesting({
      AppConfiguration.readerFontWeightKey: FontWeight.values.indexOf(
        FontWeight.normal,
      ),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final settings = await container.read(readerSettingsProvider.future);

    expect(settings.fontWeight, ReaderFontWeight.normal);
    final preferences = await AppPreferences.getInstance();
    expect(
      preferences.getString(AppConfiguration.readerFontWeightKey),
      ReaderFontWeight.normal.name,
    );
  });

  test('persists a selected Super OTC font style by enum name', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(readerSettingsProvider.future);

    await container
        .read(readerSettingsProvider.notifier)
        .setFontWeight(ReaderFontWeight.semiBold);

    expect(
      container.read(readerSettingsProvider).value?.fontWeight,
      ReaderFontWeight.semiBold,
    );
    final preferences = await AppPreferences.getInstance();
    expect(
      preferences.getString(AppConfiguration.readerFontWeightKey),
      ReaderFontWeight.semiBold.name,
    );
  });
}
