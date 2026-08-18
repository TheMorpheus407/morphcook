import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography for the tumblr-cookbook aesthetic (SPEC): Playfair Display
/// italic display, JetBrains Mono labels, Caveat handwritten accents.
///
/// Google Fonts are used per the SPEC. In widget tests (no network) call
/// [disableGoogleFonts] to fall back to system serif / monospace / cursive
/// so tests never attempt HTTP fetches. For a fully bundled offline build,
/// drop the .ttf files into `assets/fonts/` and register them in pubspec —
/// this wrapper keeps that a one-file change.
class AppFonts {
  AppFonts._();

  /// Tests set this to false before pumping widgets.
  static bool googleFontsEnabled = true;

  static TextStyle _g(
    TextStyle Function() google,
    TextStyle fallback,
  ) =>
      googleFontsEnabled ? google() : fallback;

  /// Big italic display — masthead, dish titles.
  static TextStyle display({
    double size = 34,
    Color? color,
    FontWeight weight = FontWeight.w600,
    double? height,
  }) =>
      _g(
        () => GoogleFonts.playfairDisplay(
          fontSize: size,
          fontStyle: FontStyle.italic,
          fontWeight: weight,
          color: color,
          height: height,
        ),
        TextStyle(
          fontSize: size,
          fontStyle: FontStyle.italic,
          fontWeight: weight,
          color: color,
          height: height,
          fontFamily: 'serif',
        ),
      );

  /// Upright Playfair for section headlines and body serif.
  static TextStyle serif({
    double size = 16,
    Color? color,
    FontWeight weight = FontWeight.w500,
    double? height,
  }) =>
      _g(
        () => GoogleFonts.playfairDisplay(
          fontSize: size,
          fontWeight: weight,
          color: color,
          height: height,
        ),
        TextStyle(
          fontSize: size,
          fontWeight: weight,
          color: color,
          height: height,
          fontFamily: 'serif',
        ),
      );

  /// Mono labels, tags, captions, timestamps.
  static TextStyle mono({
    double size = 11,
    Color? color,
    FontWeight weight = FontWeight.w400,
    double? letterSpacing,
  }) =>
      _g(
        () => GoogleFonts.jetBrainsMono(
          fontSize: size,
          fontWeight: weight,
          color: color,
          letterSpacing: letterSpacing,
        ),
        TextStyle(
          fontSize: size,
          fontWeight: weight,
          color: color,
          letterSpacing: letterSpacing,
          fontFamily: 'monospace',
        ),
      );

  /// Handwritten accents — greetings, margin notes, the "guten appetit".
  static TextStyle hand({
    double size = 22,
    Color? color,
    FontWeight weight = FontWeight.w400,
    double? height,
  }) =>
      _g(
        () => GoogleFonts.caveat(
          fontSize: size,
          fontWeight: weight,
          color: color,
          height: height,
        ),
        TextStyle(
          fontSize: size,
          fontWeight: weight,
          color: color,
          height: height,
          fontFamily: 'cursive',
        ),
      );
}
