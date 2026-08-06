import 'package:flutter/material.dart';

/// MorphCook's look: a nostalgic cookbook / vintage recipe zine.
///
///  - cream paper, sepia ink
///  - PlayfairDisplay for cookbook headlines (serif)
///  - JetBrainsMono for "press" chrome, indexes and captions
///  - Caveat for handwritten annotations
///  - dish stripe colors for polaroid cards
abstract final class AppColors {
  static const paper = Color(0xFFFAF6EC);
  static const paperDark = Color(0xFFF2EADA);
  static const paperBright = Color(0xFFFFFDF7);
  static const ink = Color(0xFF3A2E22);
  static const inkSoft = Color(0xFF6B5D4C);
  static const inkFaint = Color(0xFF9C8D78);
  static const accent = Color(0xFFC9703E);
  static const accentSoft = Color(0xFFE2A97F);
  static const line = Color(0xFFE3D8C3);
  static const lineDotted = Color(0xFFC9B89E);
  static const success = Color(0xFF7A8B5E);
  static const error = Color(0xFFB0493C);
  static const highlight = Color(0xFFFFF3C4);

  /// Staggered pastel backgrounds for zebra rows, derived from dish stripes.
  static const zebraB = [
    Color(0xFFFFF9EC),
    Color(0xFFF7F1E4),
    Color(0xFFFBF1EC),
    Color(0xFFF0F3E8),
    Color(0xFFEDF0F4),
    Color(0xFFF7EBEC),
    Color(0xFFF6F0E2),
  ];
}

abstract final class AppText {
  static TextStyle serif(BuildContext context,
          {double size = 20, Color color = AppColors.ink, FontWeight weight = FontWeight.w600, double? height}) =>
      TextStyle(
        fontFamily: 'PlayfairDisplay',
        fontSize: size,
        color: color,
        fontWeight: weight,
        height: height,
      );

  static TextStyle mono(BuildContext context,
          {double size = 12, Color color = AppColors.inkSoft, double? height}) =>
      TextStyle(
        fontFamily: 'JetBrainsMono',
        fontSize: size,
        color: color,
        height: height,
      );

  static TextStyle script(BuildContext context,
          {double size = 20, Color color = AppColors.ink, FontStyle style = FontStyle.normal, bool italic = true}) =>
      TextStyle(
        fontFamily: 'Caveat',
        fontSize: size,
        color: color,
        fontStyle: italic ? FontStyle.italic : style,
      );
}

ThemeData buildTheme(Brightness mode) {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: mode,
  ).copyWith(
    primary: AppColors.accent,
    onPrimary: Colors.white,
    surface: AppColors.paperBright,
    onSurface: AppColors.ink,
    error: AppColors.error,
    onError: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.paper,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: false,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
    textTheme: TextTheme(
      displayLarge: TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontSize: 40,
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
          height: 1.1),
      displaySmall: TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontSize: 26,
          color: AppColors.ink,
          fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontSize: 22,
          color: AppColors.ink,
          fontWeight: FontWeight.w600),
      titleLarge: TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontSize: 18,
          color: AppColors.ink,
          fontWeight: FontWeight.w600),
      titleMedium: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 13,
          color: AppColors.inkSoft,
          fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontSize: 16,
          color: AppColors.ink,
          height: 1.45),
      bodySmall: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 12,
          color: AppColors.inkSoft,
          height: 1.4),
      labelLarge: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 12,
          color: AppColors.ink,
          letterSpacing: 0.5),
    ),
    cardTheme: CardThemeData(
      color: AppColors.paperBright,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.line, width: 1)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.paperBright,
      hintStyle:
          const TextStyle(fontFamily: 'JetBrainsMono', color: AppColors.inkFaint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.lineDotted),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.paperBright,
      side: const BorderSide(color: AppColors.lineDotted),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      labelStyle: const TextStyle(
          fontFamily: 'JetBrainsMono', fontSize: 11, color: AppColors.ink),
    ),
  );
}