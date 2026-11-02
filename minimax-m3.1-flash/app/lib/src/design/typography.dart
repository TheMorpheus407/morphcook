import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'palette.dart';

/// The three voices of MorphCook.
///
///  * [display] — Playfair Display *italic*. Mastheads and dish names.
///  * [label]   — JetBrains Mono, uppercase, wide tracking. Machine facts.
///  * [script]  — Caveat. Marginalia, captions, handwriting.
abstract final class Type {
  const Type._();

  static TextStyle _playfair({
    double size = 16,
    FontWeight weight = FontWeight.w400,
    FontStyle style = FontStyle.normal,
    Color color = MC.ink,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.playfairDisplay(
      textStyle: TextStyle(
        fontSize: size,
        fontWeight: weight,
        fontStyle: style,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      ),
    );
  }

  static TextStyle _mono({
    double size = 11,
    FontWeight weight = FontWeight.w500,
    Color color = MC.inkSoft,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.jetBrainsMono(
      textStyle: TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing ?? 1.1,
        height: height,
      ),
    );
  }

  static TextStyle _caveat({
    double size = 19,
    FontWeight weight = FontWeight.w400,
    Color color = MC.inkSoft,
    double? height,
  }) {
    return GoogleFonts.caveat(
      textStyle: TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      ),
    );
  }

  // ── Display voice ────────────────────────────────────────────────────────

  /// The big italic masthead line.
  static TextStyle display({double size = 31, Color color = MC.ink}) =>
      _playfair(
        size: size,
        style: FontStyle.italic,
        color: color,
        height: 1.12,
        letterSpacing: -0.3,
      );

  /// A dish or recipe title.
  static TextStyle title({double size = 23, Color color = MC.ink}) => _playfair(
    size: size,
    weight: FontWeight.w600,
    color: color,
    height: 1.18,
    letterSpacing: -0.2,
  );

  static TextStyle subtitle({double size = 17, Color color = MC.inkSoft}) =>
      _playfair(size: size, weight: FontWeight.w500, color: color, height: 1.3);

  static TextStyle body({double size = 15.5, Color color = MC.inkSoft}) =>
      _playfair(size: size, color: color, height: 1.62);

  static TextStyle bodyStrong({
    double size = 15.5,
    Color color = MC.ink,
    FontWeight weight = FontWeight.w600,
  }) => _playfair(size: size, color: color, weight: weight, height: 1.55);

  static TextStyle small({double size = 13, Color color = MC.inkFaint}) =>
      _playfair(size: size, color: color, height: 1.5);

  // ── Label voice ──────────────────────────────────────────────────────────

  static TextStyle label({
    double size = 10.5,
    FontWeight weight = FontWeight.w500,
    Color color = MC.inkFaint,
    double letterSpacing = 1.3,
  }) => _mono(size: size, weight: weight, color: color, letterSpacing: letterSpacing);

  static TextStyle labelStrong({
    double size = 10.5,
    Color color = MC.ink,
  }) => _mono(size: size, weight: FontWeight.w700, color: color, letterSpacing: 1.3);

  /// Numbers, timers, macros — anything that should line up in a column.
  static TextStyle mono({
    double size = 13,
    FontWeight weight = FontWeight.w500,
    Color color = MC.ink,
    double letterSpacing = 0.2,
  }) => _mono(
    size: size,
    weight: weight,
    color: color,
    letterSpacing: letterSpacing,
  );

  static TextStyle monoLarge({
    double size = 30,
    Color color = MC.ink,
  }) => _mono(size: size, weight: FontWeight.w700, color: color, letterSpacing: -0.5);

  // ── Script voice ─────────────────────────────────────────────────────────

  static TextStyle script({double size = 20, Color color = MC.inkSoft}) =>
      _caveat(size: size, color: color, height: 1.25);

  static TextStyle scriptSmall({double size = 16, Color color = MC.inkFaint}) =>
      _caveat(size: size, color: color, height: 1.25);

  static TextStyle scriptLarge({double size = 26, Color color = MC.ink}) =>
      _caveat(size: size, color: color, height: 1.2);
}

/// Builds the Material theme that sits underneath the custom widgets.
ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: MC.paper,
    colorScheme: const ColorScheme.light(
      primary: MC.coral,
      onPrimary: MC.card,
      secondary: MC.teal,
      onSecondary: MC.card,
      surface: MC.card,
      onSurface: MC.ink,
      error: MC.danger,
      onError: MC.card,
    ),
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: MC.inkSoft,
      displayColor: MC.ink,
      fontFamily: 'PlayfairDisplay',
    ),
    splashFactory: InkSparkle.splashFactory,
    dividerColor: MC.ruleFaint,
    iconTheme: const IconThemeData(color: MC.inkSoft, size: 20),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: Type.title(size: 19),
      iconTheme: const IconThemeData(color: MC.ink, size: 20),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: MC.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: MC.ink,
      contentTextStyle: Type.body(size: 14, color: MC.card),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: MC.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titleTextStyle: Type.title(size: 18),
      contentTextStyle: Type.body(size: 14.5),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: MC.coral,
      selectionColor: MC.coralSoft,
      selectionHandleColor: MC.coral,
    ),
  );
}
