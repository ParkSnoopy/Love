import 'package:flutter/material.dart';

const _defaultPrimary = Color(0xFFCC785C);

const _customLightColors = ColorScheme.light(
  primary: _defaultPrimary,
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFEFE9DE),
  onPrimaryContainer: Color(0xFF141413),
  secondary: Color(0xFF5DB8A6),
  onSecondary: Color(0xFF141413),
  secondaryContainer: Color(0xFFF5F0E8),
  onSecondaryContainer: Color(0xFF252523),
  tertiary: Color(0xFFE8A55A),
  onTertiary: Color(0xFF141413),
  error: Color(0xFFC64545),
  onError: Color(0xFFFFFFFF),
  surface: Color(0xFFFAF9F5),
  onSurface: Color(0xFF141413),
  onSurfaceVariant: Color(0xFF6C6A64),
  outline: Color(0xFF8E8B82),
  outlineVariant: Color(0xFFE6DFD8),
  shadow: Color(0xFF141413),
  scrim: Color(0xFF141413),
  inverseSurface: Color(0xFF181715),
  onInverseSurface: Color(0xFFFAF9F5),
  inversePrimary: Color(0xFFE8A55A),
  surfaceTint: _defaultPrimary,
  surfaceContainerLowest: Color(0xFFFAF9F5),
  surfaceContainerLow: Color(0xFFF5F0E8),
  surfaceContainer: Color(0xFFEFE9DE),
  surfaceContainerHigh: Color(0xFFE8E0D2),
  surfaceContainerHighest: Color(0xFFE6DFD8),
);

ThemeData _buildLightTheme(String fontFamily, ColorScheme colors) {
  final base = ThemeData.light();
  return base.copyWith(
    colorScheme: colors,
    scaffoldBackgroundColor: colors.surface,
    canvasColor: colors.surface,
    cardColor: colors.surfaceContainerLow,
    dividerColor: colors.outlineVariant,
    textTheme: base.textTheme.apply(
      fontFamily: fontFamily,
      bodyColor: colors.onSurface,
      displayColor: colors.onSurface,
    ),
  );
}

ThemeData buildCustomTheme(
  String fontFamily, {
  required Brightness brightness,
  required Color primary,
}) {
  final generated = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: brightness,
  );
  final onPrimary =
      ThemeData.estimateBrightnessForColor(primary) == Brightness.dark
      ? Colors.white
      : Colors.black;
  if (brightness == Brightness.light) {
    return _buildLightTheme(
      fontFamily,
      _customLightColors.copyWith(
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: generated.primaryContainer,
        onPrimaryContainer: generated.onPrimaryContainer,
        inversePrimary: generated.inversePrimary,
        surfaceTint: primary,
      ),
    );
  }

  final base = ThemeData.dark();
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: generated.primaryContainer,
      onPrimaryContainer: generated.onPrimaryContainer,
      inversePrimary: generated.inversePrimary,
      surfaceTint: primary,
    ),
    textTheme: base.textTheme.apply(fontFamily: fontFamily),
  );
}
