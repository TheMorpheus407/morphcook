/// The tumblr-era cookbook look: warm paper, ink, coral/teal accents,
/// Playfair Display italic display, JetBrains Mono data, Caveat handwriting.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n.dart';

class AppTheme {
  // paper & ink
  static const paper = Color(0xFFF6F1E5);
  static const paperDeep = Color(0xFFEFE7D4);
  static const ink = Color(0xFF2B2620);
  static const inkSoft = Color(0xFF6B6156);
  static const inkFaint = Color(0xFFA69B8C);
  static const line = Color(0xFFD8CDB8);

  // accents
  static const coral = Color(0xFFC1543C);
  static const teal = Color(0xFF3E7C7B);
  static const mustard = Color(0xFFE9B44C);
  static const sage = Color(0xFF8F9E4F);

  // cook mode (dark full-bleed)
  static const cookBg = Color(0xFF191511);
  static const cookPanel = Color(0xFF241E18);
  static const cookPaper = Color(0xFFEFE7D4);

  static const display = 'Playfair Display';
  static const mono = 'JetBrains Mono';
  static const hand = 'Caveat';

  static const fontFamilyFallback = <String>['Playfair Display', 'serif'];

  static ThemeData light(Lang lang) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: ink,
        secondary: coral,
        surface: paper,
        onSurface: ink,
        error: coral,
      ),
      scaffoldBackgroundColor: paper,
      splashFactory: InkRipple.splashFactory,
    );
    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      dividerTheme: const DividerThemeData(color: line, thickness: 1),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? teal : Colors.transparent),
        side: const BorderSide(color: inkSoft, width: 1.4),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(3))),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? paper : inkFaint),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? teal : line),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: TextStyle(
            fontFamily: mono, fontSize: 12, color: paper, letterSpacing: .4),
        behavior: SnackBarBehavior.floating,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    return base
        .copyWith(
          displayLarge: const TextStyle(
              fontFamily: display,
              fontStyle: FontStyle.italic,
              fontSize: 44,
              height: 1.05,
              color: ink,
              fontWeight: FontWeight.w500),
          displayMedium: const TextStyle(
              fontFamily: display,
              fontStyle: FontStyle.italic,
              fontSize: 32,
              height: 1.1,
              color: ink),
          displaySmall: const TextStyle(
              fontFamily: display,
              fontStyle: FontStyle.italic,
              fontSize: 24,
              height: 1.15,
              color: ink),
          headlineSmall: const TextStyle(
              fontFamily: display,
              fontSize: 20,
              height: 1.2,
              color: ink,
              fontWeight: FontWeight.w600),
          titleLarge: const TextStyle(
              fontFamily: display,
              fontSize: 18,
              height: 1.25,
              color: ink,
              fontWeight: FontWeight.w600),
          titleMedium: const TextStyle(
              fontFamily: mono,
              fontSize: 12,
              letterSpacing: 1.2,
              color: inkSoft,
              fontWeight: FontWeight.w700),
          bodyLarge: const TextStyle(
              fontFamily: display, fontSize: 17, height: 1.5, color: ink),
          bodyMedium: const TextStyle(
              fontFamily: display, fontSize: 15, height: 1.5, color: ink),
          bodySmall: const TextStyle(
              fontFamily: mono, fontSize: 11, height: 1.5, color: inkSoft),
          labelLarge: const TextStyle(
              fontFamily: mono,
              fontSize: 12,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
              color: ink),
          labelMedium: const TextStyle(
              fontFamily: mono, fontSize: 10, letterSpacing: 1.1, color: inkFaint),
          labelSmall: const TextStyle(
              fontFamily: hand, fontSize: 17, height: 1.1, color: inkSoft),
        )
        .apply(bodyColor: ink, displayColor: ink);
  }
}

/// Extension: map reduceMotion (profile or system) to animation durations.
class Motion {
  final bool reduced;
  const Motion(this.reduced);

  Duration get fast => reduced ? const Duration(milliseconds: 60) : const Duration(milliseconds: 220);
  Duration get medium => reduced ? const Duration(milliseconds: 90) : const Duration(milliseconds: 350);
  Duration get slow => reduced ? const Duration(milliseconds: 120) : const Duration(milliseconds: 600);
  Duration get morph => reduced ? const Duration(milliseconds: 100) : const Duration(milliseconds: 450);
}
