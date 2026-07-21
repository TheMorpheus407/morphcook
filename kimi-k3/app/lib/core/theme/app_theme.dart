import 'package:flutter/material.dart';

/// The tumblr-era cookbook look: warm paper, ink, coral & teal accents,
/// Playfair Display italic display type, JetBrains Mono meta labels,
/// Caveat handwritten notes.
class AppColors {
  static const paper = Color(0xFFF6EFE3);
  static const paperDark = Color(0xFFEDE3D2);
  static const ink = Color(0xFF2B2620);
  static const inkSoft = Color(0xFF6E6459);
  static const coral = Color(0xFFD95F3B);
  static const coralSoft = Color(0xFFF0C9B8);
  static const teal = Color(0xFF3E7C74);
  static const tealSoft = Color(0xFFC9DAD4);
  static const mustard = Color(0xFFD9A441);
  static const polaroid = Color(0xFFFDFBF6);
  static const disabled = Color(0xFFBCB2A4);

  static Color stripe(String hex) {
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return value == null ? coral : Color(0xFF000000 | value);
  }
}

class AppText {
  static const display = 'PlayfairDisplay';
  static const mono = 'JetBrainsMono';
  static const hand = 'Caveat';

  static TextStyle masthead({double size = 42, Color color = AppColors.ink}) =>
      TextStyle(
          fontFamily: display,
          fontSize: size,
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.italic,
          color: color,
          height: 1.05);

  static TextStyle headline({double size = 22, Color color = AppColors.ink}) =>
      TextStyle(
          fontFamily: display,
          fontSize: size,
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.italic,
          color: color,
          height: 1.15);

  static TextStyle body({double size = 15, Color color = AppColors.ink}) =>
      TextStyle(
          fontFamily: display,
          fontSize: size,
          fontWeight: FontWeight.w400,
          color: color,
          height: 1.45);

  static TextStyle monoLabel(
          {double size = 11, Color color = AppColors.inkSoft}) =>
      TextStyle(
          fontFamily: mono,
          fontSize: size,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.4,
          color: color);

  static TextStyle handwritten(
          {double size = 20, Color color = AppColors.inkSoft}) =>
      TextStyle(
          fontFamily: hand,
          fontSize: size,
          fontWeight: FontWeight.w400,
          color: color,
          height: 1.1);
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.paper,
      colorScheme: const ColorScheme.light(
        primary: AppColors.coral,
        secondary: AppColors.teal,
        surface: AppColors.paper,
        onSurface: AppColors.ink,
        error: AppColors.coral,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
      ),
      dividerColor: AppColors.inkSoft.withValues(alpha: 0.3),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
        fontFamily: AppText.display,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.paperDark,
        selectedColor: AppColors.tealSoft,
        labelStyle: AppText.monoLabel(size: 11, color: AppColors.ink),
        side: const BorderSide(color: AppColors.inkSoft, width: 0.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: TextStyle(fontFamily: AppText.mono, fontSize: 12),
      ),
    );
  }
}
