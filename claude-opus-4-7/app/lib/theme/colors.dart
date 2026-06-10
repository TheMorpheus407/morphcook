import 'package:flutter/material.dart';

/// Nostalgic calm palette — tumblr-era cookbook on aged paper.
/// All colors lean warm; ink is a soft sepia-brown, never pure black.
class MorphColors {
  // Paper
  static const paper = Color(0xFFF6EFE0);
  static const paperDeep = Color(0xFFEDE3CE);
  static const paperShadow = Color(0xFFDBCFB4);

  // Ink
  static const ink = Color(0xFF2A2520);
  static const inkSoft = Color(0xFF4F463E);
  static const inkMuted = Color(0xFF8A7E6C);
  static const inkFaint = Color(0xFFB6A98F);

  // Accents (used sparingly — visual alert, polaroid tape, stripe placeholders)
  static const coral = Color(0xFFD86F5A);
  static const teal = Color(0xFF5A8B8B);
  static const mustard = Color(0xFFD9A85A);
  static const sage = Color(0xFF8FA177);
  static const plum = Color(0xFF8B5C7A);
  static const dust = Color(0xFFB48C5C);

  // Tape (polaroid)
  static const tape = Color(0x66F4D88A);

  // Status
  static const disabled = Color(0xFFB6A98F);

  /// Used by striped SVG placeholders, dish stripe color is parsed from data.
  static const List<Color> stripeColors = [
    coral,
    teal,
    mustard,
    sage,
    plum,
    dust,
  ];

  static Color parseHex(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}
