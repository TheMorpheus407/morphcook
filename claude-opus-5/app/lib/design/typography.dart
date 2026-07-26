import 'package:flutter/material.dart';

/// Three faces, each with one job.
///
///  * **Playfair Display** — display and headings, italic wherever the page
///    needs to sound like a person rather than a database.
///  * **JetBrains Mono** — labels, quantities, timers. Anything numeric or
///    structural, set in small caps-ish tracking.
///  * **Caveat** — the handwritten margin note. Never used for anything the
///    user must be able to read to cook.
///
/// All three are bundled as static TTFs (see pubspec). Nothing is fetched at
/// runtime; the app makes no network requests at all.
class Faces {
  Faces._();

  static const String display = 'Playfair Display';
  static const String mono = 'JetBrains Mono';
  static const String hand = 'Caveat';
}

class MorphType {
  MorphType._();

  static TextTheme textTheme(Color ink, Color inkSoft) => TextTheme(
    // Masthead
    displayLarge: TextStyle(
      fontFamily: Faces.display,
      fontSize: 44,
      height: 1.02,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.2,
      color: ink,
    ),
    displayMedium: TextStyle(
      fontFamily: Faces.display,
      fontSize: 34,
      height: 1.08,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.6,
      color: ink,
    ),
    displaySmall: TextStyle(
      fontFamily: Faces.display,
      fontSize: 27,
      height: 1.14,
      fontWeight: FontWeight.w600,
      fontStyle: FontStyle.italic,
      letterSpacing: -0.3,
      color: ink,
    ),
    headlineMedium: TextStyle(
      fontFamily: Faces.display,
      fontSize: 22,
      height: 1.22,
      fontWeight: FontWeight.w600,
      color: ink,
    ),
    headlineSmall: TextStyle(
      fontFamily: Faces.display,
      fontSize: 19,
      height: 1.3,
      fontWeight: FontWeight.w600,
      fontStyle: FontStyle.italic,
      color: ink,
    ),
    titleMedium: TextStyle(
      fontFamily: Faces.display,
      fontSize: 17,
      height: 1.34,
      fontWeight: FontWeight.w600,
      color: ink,
    ),
    titleSmall: TextStyle(
      fontFamily: Faces.mono,
      fontSize: 11,
      height: 1.4,
      fontWeight: FontWeight.w500,
      letterSpacing: 1.6,
      color: inkSoft,
    ),
    bodyLarge: TextStyle(
      fontFamily: Faces.display,
      fontSize: 17,
      height: 1.62,
      color: ink,
    ),
    bodyMedium: TextStyle(
      fontFamily: Faces.display,
      fontSize: 15.5,
      height: 1.62,
      color: ink,
    ),
    bodySmall: TextStyle(
      fontFamily: Faces.mono,
      fontSize: 12,
      height: 1.5,
      color: inkSoft,
    ),
    labelLarge: TextStyle(
      fontFamily: Faces.mono,
      fontSize: 12.5,
      height: 1.3,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.6,
      color: ink,
    ),
    labelMedium: TextStyle(
      fontFamily: Faces.mono,
      fontSize: 11.5,
      height: 1.3,
      letterSpacing: 0.4,
      color: inkSoft,
    ),
    labelSmall: TextStyle(
      fontFamily: Faces.mono,
      fontSize: 10,
      height: 1.3,
      letterSpacing: 1.4,
      color: inkSoft,
    ),
  );

  /// Margin note. Larger than it looks because Caveat runs small.
  static TextStyle hand(Color color, {double size = 21}) => TextStyle(
    fontFamily: Faces.hand,
    fontSize: size,
    height: 1.24,
    color: color,
  );

  /// Section eyebrow: mono, wide tracking, upper-case at call sites.
  static TextStyle eyebrow(Color color) => TextStyle(
    fontFamily: Faces.mono,
    fontSize: 10.5,
    height: 1.3,
    fontWeight: FontWeight.w500,
    letterSpacing: 2.2,
    color: color,
  );

  /// Numerals in a recipe: quantities, timers, calories.
  static TextStyle numeric(
    Color color, {
    double size = 14,
    FontWeight? weight,
  }) => TextStyle(
    fontFamily: Faces.mono,
    fontSize: size,
    height: 1.3,
    fontWeight: weight ?? FontWeight.w500,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
