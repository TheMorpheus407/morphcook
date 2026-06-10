import 'package:flutter/material.dart';

/// The MorphCook palette and type system. The whole feeling is a tumblr-era
/// cookbook left in the sun: warm paper, faded ink, dusty pigments, nothing
/// shouts. Calm and nostalgic by construction.
class AppColors {
  // paper & ink
  static const paper = Color(0xFFF3EADb); // aged cream
  static const paperDeep = Color(0xFFEADFC8); // a shade darker, for cards' edges
  static const ink = Color(0xFF3A2E26); // soft sepia-brown text
  static const inkSoft = Color(0xFF6E6053); // muted secondary ink
  static const inkFaint = Color(0xFFA89A86); // captions, hairlines

  // dusty pigments (muted, never saturated)
  static const terracotta = Color(0xFFC97B5A);
  static const sage = Color(0xFF8A9A78);
  static const teal = Color(0xFF5E8B86);
  static const mustard = Color(0xFFC9A24B);
  static const clay = Color(0xFFB07B62);
  static const dustyBlue = Color(0xFF7E94A6);

  // cook-mode dark
  static const cookBg = Color(0xFF221E1A);
  static const cookInk = Color(0xFFEDE3D2);

  // accessibility flash colors (coral / teal)
  static const flashCoral = Color(0xFFE08A6E);
  static const flashTeal = Color(0xFF5E8B86);
}

/// Bundled font families (registered in pubspec). No runtime fetching — the app
/// is fully offline.
class Fonts {
  static const display = 'PlayfairDisplay'; // serif, often italic + lowercase
  static const mono = 'JetBrainsMono'; // labels, metadata, captions
  static const hand = 'Caveat'; // handwritten accents
}

class AppTheme {
  static ThemeData light() {
    const seed = AppColors.terracotta;
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        primary: AppColors.terracotta,
        secondary: AppColors.teal,
        surface: AppColors.paper,
        brightness: Brightness.light,
      ).copyWith(surfaceTint: Colors.transparent),
      splashFactory: InkRipple.splashFactory,
    );

    TextStyle display(double size, {FontStyle style = FontStyle.italic, FontWeight w = FontWeight.w500}) =>
        TextStyle(fontFamily: Fonts.display, fontSize: size, fontStyle: style, fontWeight: w, color: AppColors.ink, height: 1.05);
    TextStyle mono(double size, {Color? color, double spacing = 0.5, FontWeight w = FontWeight.w400}) =>
        TextStyle(fontFamily: Fonts.mono, fontSize: size, letterSpacing: spacing, color: color ?? AppColors.inkSoft, fontWeight: w);

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: display(46),
        displayMedium: display(36),
        headlineLarge: display(30),
        headlineMedium: display(24),
        titleLarge: display(20, style: FontStyle.normal, w: FontWeight.w600),
        bodyLarge: TextStyle(fontFamily: Fonts.display, fontStyle: FontStyle.normal, fontSize: 17, color: AppColors.ink, height: 1.45),
        bodyMedium: TextStyle(fontFamily: Fonts.display, fontStyle: FontStyle.normal, fontSize: 15, color: AppColors.ink, height: 1.4),
        labelLarge: mono(13, spacing: 1.2, w: FontWeight.w500),
        labelMedium: mono(11, spacing: 1.4, color: AppColors.inkSoft),
        labelSmall: mono(10, spacing: 1.6, color: AppColors.inkFaint),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.ink,
        centerTitle: false,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.inkFaint, thickness: 1, space: 1),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.paperDeep,
        labelStyle: mono(12, color: AppColors.ink),
        side: const BorderSide(color: AppColors.inkFaint),
        shape: const StadiumBorder(),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: TextStyle(fontFamily: Fonts.mono, color: AppColors.paper, fontSize: 13),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData cookDark() {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true, scaffoldBackgroundColor: AppColors.cookBg);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(primary: AppColors.flashCoral, secondary: AppColors.flashTeal),
    );
  }
}
