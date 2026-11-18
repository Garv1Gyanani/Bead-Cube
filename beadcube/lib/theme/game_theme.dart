import 'package:flutter/material.dart';

import '../services/progress_store.dart';

const String kGameFontFamily = 'Fredoka';

/// Builds a rounded game [TextStyle] using the bundled variable `Fredoka` font
/// with exact OpenType `'wght'` axis control (`300..700`).
TextStyle gameStyle({
  double size = 14,
  double weight = 600,
  Color? color,
  double? letterSpacing,
  double? height,
}) {
  final clampedWeight = weight.clamp(300.0, 700.0);
  return TextStyle(
    fontFamily: kGameFontFamily,
    fontSize: size,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    fontVariations: [FontVariation('wght', clampedWeight)],
  );
}

/// Builds a complete, uniform [ThemeData] driven by [cubeTheme] so every
/// dialog, bottom sheet, button, chip, snackbar, and text widget shares the
/// exact same palette and game typography.
ThemeData buildGameThemeData(CubeTheme cubeTheme) {
  final scheme = ColorScheme.fromSeed(
    seedColor: cubeTheme.primary,
    brightness: Brightness.light,
    primary: cubeTheme.primary,
    onPrimary: Colors.white,
    secondary: cubeTheme.textSecondary,
    surface: cubeTheme.surface,
    onSurface: cubeTheme.textPrimary,
  );

  final baseText = TextTheme(
    headlineSmall: gameStyle(size: 20, weight: 700, color: cubeTheme.textPrimary),
    titleLarge: gameStyle(size: 18, weight: 700, color: cubeTheme.textPrimary),
    titleMedium: gameStyle(size: 15, weight: 650, color: cubeTheme.textPrimary),
    titleSmall: gameStyle(size: 13, weight: 600, color: cubeTheme.textPrimary),
    bodyLarge: gameStyle(size: 14, weight: 500, color: cubeTheme.textPrimary),
    bodyMedium: gameStyle(size: 13, weight: 500, color: cubeTheme.textPrimary),
    bodySmall: gameStyle(size: 11.5, weight: 500, color: cubeTheme.textSecondary),
    labelLarge: gameStyle(size: 13, weight: 650, color: cubeTheme.textPrimary),
    labelMedium: gameStyle(size: 11.5, weight: 600, color: cubeTheme.textSecondary),
    labelSmall: gameStyle(size: 10, weight: 650, color: cubeTheme.textSecondary),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: kGameFontFamily,
    colorScheme: scheme,
    textTheme: baseText,
    scaffoldBackgroundColor: cubeTheme.gradient.last,
    dialogTheme: DialogThemeData(
      backgroundColor: cubeTheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: cubeTheme.border, width: 1.5),
      ),
      titleTextStyle: gameStyle(
        size: 18,
        weight: 700,
        color: cubeTheme.textPrimary,
      ),
      contentTextStyle: gameStyle(
        size: 13.5,
        weight: 500,
        color: cubeTheme.textSecondary,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cubeTheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        side: BorderSide(color: cubeTheme.border, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: cubeTheme.primarySoft,
      checkmarkColor: cubeTheme.primary,
      side: BorderSide(color: cubeTheme.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      labelStyle: gameStyle(
        size: 12,
        weight: 600,
        color: cubeTheme.textPrimary,
      ),
      secondaryLabelStyle: gameStyle(
        size: 12,
        weight: 700,
        color: cubeTheme.primary,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: cubeTheme.primary,
        foregroundColor: Colors.white,
        textStyle: gameStyle(size: 13, weight: 650),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: cubeTheme.primary,
        textStyle: gameStyle(size: 13.5, weight: 650),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(gameStyle(size: 12.5, weight: 650)),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return cubeTheme.primarySoft;
          }
          return Colors.white;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return cubeTheme.primary;
          }
          return cubeTheme.textSecondary;
        }),
        side: WidgetStatePropertyAll(BorderSide(color: cubeTheme.border)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      contentTextStyle: gameStyle(
        size: 13,
        weight: 600,
        color: cubeTheme.textPrimary,
      ),
    ),
  );
}

