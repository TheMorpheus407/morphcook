import 'package:flutter/material.dart';

abstract final class BrandColors {
  static const paper = Color(0xFFF3ECDD);
  static const paperDeep = Color(0xFFE7DCC7);
  static const ink = Color(0xFF282521);
  static const fadedInk = Color(0xFF6E675E);
  static const coral = Color(0xFFD66B5C);
  static const coralLight = Color(0xFFF2C2B8);
  static const teal = Color(0xFF4E8A84);
  static const tealLight = Color(0xFFB9D4CE);
  static const mustard = Color(0xFFC99B42);
  static const plum = Color(0xFF745869);
  static const cookInk = Color(0xFF171918);
  static const cookPaper = Color(0xFFF2EBDD);
}

abstract final class BrandTheme {
  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: BrandColors.coral,
          brightness: Brightness.light,
          surface: BrandColors.paper,
        ).copyWith(
          primary: BrandColors.coral,
          onPrimary: Colors.white,
          secondary: BrandColors.teal,
          onSecondary: Colors.white,
          surface: BrandColors.paper,
          onSurface: BrandColors.ink,
          outline: BrandColors.ink,
        );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: BrandColors.paper,
      splashFactory: InkSparkle.splashFactory,
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: const TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
          fontSize: 47,
          height: .95,
          letterSpacing: -1.8,
          color: BrandColors.ink,
        ),
        displayMedium: const TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
          fontSize: 36,
          height: 1,
          letterSpacing: -1.2,
          color: BrandColors.ink,
        ),
        headlineLarge: const TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontWeight: FontWeight.w700,
          fontSize: 30,
          height: 1.05,
          color: BrandColors.ink,
        ),
        headlineMedium: const TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
          fontSize: 25,
          height: 1.08,
          color: BrandColors.ink,
        ),
        titleLarge: const TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontWeight: FontWeight.w700,
          fontSize: 21,
          height: 1.15,
          color: BrandColors.ink,
        ),
        titleMedium: const TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontWeight: FontWeight.w600,
          fontSize: 17,
          color: BrandColors.ink,
        ),
        bodyLarge: const TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontSize: 17,
          height: 1.42,
          color: BrandColors.ink,
        ),
        bodyMedium: const TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontSize: 15,
          height: 1.42,
          color: BrandColors.ink,
        ),
        labelLarge: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 1.1,
          color: BrandColors.ink,
        ),
        labelMedium: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontWeight: FontWeight.w600,
          fontSize: 10,
          letterSpacing: .8,
          color: BrandColors.ink,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: BrandColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w700,
          fontSize: 27,
          color: BrandColors.ink,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: Color(0xFFF9F5EA),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: BrandColors.ink, width: 1.2),
          borderRadius: BorderRadius.zero,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF9F5EA),
        labelStyle: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
        hintStyle: const TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontStyle: FontStyle.italic,
          color: BrandColors.fadedInk,
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: BrandColors.ink, width: 1.2),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: BrandColors.ink, width: 1.2),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: BrandColors.coral, width: 2),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.transparent,
        selectedColor: BrandColors.coralLight,
        disabledColor: BrandColors.paperDeep.withValues(alpha: .6),
        shape: const StadiumBorder(
          side: BorderSide(color: BrandColors.ink, width: 1),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BrandColors.ink,
          foregroundColor: BrandColors.paper,
          minimumSize: const Size(48, 48),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BrandColors.ink,
          minimumSize: const Size(48, 48),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          side: const BorderSide(color: BrandColors.ink, width: 1.2),
          textStyle: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: .8,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: BrandColors.ink,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFF8F2E6),
        selectedItemColor: BrandColors.coral,
        unselectedItemColor: BrandColors.fadedInk,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 9,
        ),
      ),
    );
  }
}
