import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'palette.dart';

/// The three voices of the cookbook: Playfair Display (display, italic),
/// JetBrains Mono (labels, meta, datelines), Caveat (handwritten notes).
class Typography {
  Typography._();

  static TextStyle display(
    double size, {
    bool italic = true,
    FontWeight weight = FontWeight.w600,
    Color color = Palette.ink,
    double? height,
    double letterSpacing = -0.5,
  }) =>
      GoogleFonts.playfairDisplay(
        fontSize: size,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle body(
    double size, {
    Color color = Palette.inkSoft,
    bool italic = false,
    double? height,
  }) =>
      GoogleFonts.playfairDisplay(
        fontSize: size,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        color: color,
        height: height,
      );

  static TextStyle mono(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = Palette.inkSoft,
    double letterSpacing = 1.2,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );

  static TextStyle hand(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = Palette.ink,
  }) =>
      GoogleFonts.caveat(fontSize: size, fontWeight: weight, color: color);
}
