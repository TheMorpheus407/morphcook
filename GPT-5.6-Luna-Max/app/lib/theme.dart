import 'package:flutter/material.dart';

const Color paper = Color(0xFFF6F0E5);
const Color paperDeep = Color(0xFFEDE2D2);
const Color ink = Color(0xFF243536);
const Color inkMuted = Color(0xFF667271);
const Color sea = Color(0xFF8FB7AE);
const Color seaDeep = Color(0xFF527F78);
const Color coral = Color(0xFFE78A73);
const Color mustard = Color(0xFFE6BF6E);
const Color blush = Color(0xFFF2D1C3);
const Color night = Color(0xFF182627);
const Color nightSoft = Color(0xFF263938);
const Color whiteInk = Color(0xFFF8F3E9);

ThemeData buildMorphTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: paper,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seaDeep,
      brightness: Brightness.light,
      surface: paper,
      onSurface: ink,
      primary: seaDeep,
      secondary: coral,
    ),
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: ink,
      elevation: 0,
      centerTitle: false,
    ),
    textTheme: base.textTheme.copyWith(
      displayLarge: const TextStyle(
        fontFamily: 'serif',
        fontSize: 44,
        height: 0.98,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        color: ink,
      ),
      displayMedium: const TextStyle(
        fontFamily: 'serif',
        fontSize: 34,
        height: 1.04,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: ink,
      ),
      headlineSmall: const TextStyle(
        fontFamily: 'serif',
        fontSize: 26,
        height: 1.1,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleLarge: const TextStyle(
        fontFamily: 'serif',
        fontSize: 21,
        height: 1.15,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleMedium: const TextStyle(
        fontFamily: 'serif',
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      bodyLarge: const TextStyle(
        fontFamily: 'serif',
        fontSize: 17,
        height: 1.45,
        color: ink,
      ),
      bodyMedium: const TextStyle(
        fontFamily: 'serif',
        fontSize: 15,
        height: 1.35,
        color: ink,
      ),
      bodySmall: const TextStyle(
        fontFamily: 'serif',
        fontSize: 13,
        height: 1.3,
        color: inkMuted,
      ),
      labelLarge: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 11,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      labelMedium: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w700,
        color: inkMuted,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF9F5ED),
      hintStyle: const TextStyle(
        fontFamily: 'serif',
        fontSize: 16,
        color: inkMuted,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFFD7CABC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFFD7CABC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: seaDeep, width: 1.5),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: const Color(0xFFECE6DA),
      selectedColor: sea,
      labelStyle: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 11,
        color: ink,
      ),
      side: const BorderSide(color: Color(0xFFD7CABC)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFCDBEAD),
      thickness: 0.8,
      space: 1,
    ),
  );
}

TextStyle displayStyle({
  double size = 34,
  Color color = ink,
  FontStyle style = FontStyle.normal,
  FontWeight weight = FontWeight.w700,
}) {
  return TextStyle(
    fontFamily: 'serif',
    fontSize: size,
    height: 1.02,
    letterSpacing: -0.7,
    color: color,
    fontStyle: style,
    fontWeight: weight,
  );
}

TextStyle monoStyle({
  double size = 10,
  Color color = inkMuted,
  FontWeight weight = FontWeight.w700,
  double letterSpacing = 1.1,
}) {
  return TextStyle(
    fontFamily: 'monospace',
    fontSize: size,
    color: color,
    letterSpacing: letterSpacing,
    fontWeight: weight,
  );
}

TextStyle handStyle({double size = 26, Color color = coral}) {
  return TextStyle(
    fontFamily: 'cursive',
    fontSize: size,
    height: 1,
    color: color,
    fontStyle: FontStyle.italic,
  );
}
