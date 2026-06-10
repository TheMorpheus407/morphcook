import 'package:flutter/material.dart';

/// Paper-and-ink palette for the tumblr-era cookbook look. Warm, low-saturation,
/// quiet. Two accents (coral + teal) used sparingly for the variant switcher
/// and the cook-mode flash; everything else lives in the cream-to-ink range.
class MCColors {
  const MCColors._();

  // Paper tones — backgrounds, polaroid frames, dividers.
  static const cream = Color(0xFFF6EFE2);
  static const paper = Color(0xFFEFE5D2);
  static const paperDark = Color(0xFFD9CDB4);
  static const polaroid = Color(0xFFFBF6EB);
  static const polaroidShadow = Color(0x33453B2A);

  // Ink tones — text, rules, hairlines.
  static const ink = Color(0xFF2A2422);
  static const inkSoft = Color(0xFF4A413C);
  static const inkFaded = Color(0xFF7A6F66);
  static const inkWhisper = Color(0xFFA59989);

  // Accents — limited to important UI moments.
  static const coral = Color(0xFFC26B5C); // primary accent
  static const teal = Color(0xFF4F8584); // secondary accent
  static const olive = Color(0xFF8C9166); // tertiary accent
  static const mustard = Color(0xFFC9A65B);

  // Cook mode (dark scheme).
  static const cookInk = Color(0xFF1B1715);
  static const cookCream = Color(0xFFEBE3D2);

  // Stripe color fallback for placeholders.
  static const stripeFallback = Color(0xFFB8956A);
}
