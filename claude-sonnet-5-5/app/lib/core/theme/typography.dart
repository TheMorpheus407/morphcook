import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'palette.dart';

/// Three voices: Playfair Display italic for headlines, JetBrains Mono for
/// labels and numbers, Caveat for handwritten margin notes. Playfair regular
/// carries the reading text.
///
/// Only the bundled weights are used (see `assets/google_fonts`): Playfair
/// 400/400i/500i/700/700i, JetBrains Mono 400/500/700, Caveat 400/700.
class AppText {
  const AppText._();

  /// Big lowercase italic headlines.
  static TextStyle display({double size = 40, Color color = Palette.ink, FontWeight weight = FontWeight.w400}) {
    return GoogleFonts.playfairDisplay(
      fontSize: size,
      fontStyle: FontStyle.italic,
      fontWeight: weight,
      height: 1.08,
      letterSpacing: size > 30 ? -0.6 : -0.2,
      color: color,
    );
  }

  /// Reading text and titles in upright Playfair.
  static TextStyle serif({
    double size = 16,
    Color color = Palette.ink,
    FontWeight weight = FontWeight.w400,
    double height = 1.5,
  }) {
    return GoogleFonts.playfairDisplay(fontSize: size, fontWeight: weight, height: height, color: color);
  }

  static TextStyle serifItalic({
    double size = 16,
    Color color = Palette.ink,
    FontWeight weight = FontWeight.w400,
    double height = 1.4,
  }) {
    return GoogleFonts.playfairDisplay(
      fontSize: size,
      fontStyle: FontStyle.italic,
      fontWeight: weight,
      height: height,
      color: color,
    );
  }

  /// Small labels, numbers and captions.
  static TextStyle mono({
    double size = 12,
    Color color = Palette.inkSoft,
    FontWeight weight = FontWeight.w400,
    double letterSpacing = 0.4,
    double height = 1.35,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
    );
  }

  /// Uppercase tracking used for tiny section labels.
  static TextStyle label({double size = 10.5, Color color = Palette.inkSoft, FontWeight weight = FontWeight.w500}) {
    return mono(size: size, color: color, weight: weight, letterSpacing: 1.4);
  }

  /// Handwritten notes in the margin.
  static TextStyle hand({double size = 22, Color color = Palette.coralDeep, FontWeight weight = FontWeight.w400}) {
    return GoogleFonts.caveat(fontSize: size, fontWeight: weight, height: 1.1, color: color);
  }
}
