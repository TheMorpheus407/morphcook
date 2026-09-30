import 'package:flutter/painting.dart';

/// The MorphCook palette: aged paper, sepia ink, and a few faded pigments.
class Palette {
  const Palette._();

  // Paper
  static const Color paper = Color(0xFFF4EBDD);
  static const Color paperDeep = Color(0xFFEADCC4);
  static const Color paperLight = Color(0xFFFBF6EC);
  static const Color paperEdge = Color(0xFFDCCBAE);

  // Ink
  static const Color ink = Color(0xFF33291F);
  static const Color inkSoft = Color(0xFF665A4D);
  static const Color inkFaint = Color(0xFF706353);
  static const Color rule = Color(0xFFC4B393);

  // Pigments
  static const Color coral = Color(0xFFCC573A);
  static const Color coralDeep = Color(0xFF9F4230);
  static const Color teal = Color(0xFF3F8F86);
  static const Color tealDeep = Color(0xFF2C6E67);
  static const Color mustard = Color(0xFFE0B04C);
  static const Color sage = Color(0xFF9DB08F);
  static const Color dustyBlue = Color(0xFF8AA4B5);
  static const Color rose = Color(0xFFD9A3A0);

  // Cook mode (dark, full bleed)
  static const Color night = Color(0xFF1F1A16);
  static const Color nightSurface = Color(0xFF2B241F);
  static const Color nightRaised = Color(0xFF382F28);
  static const Color nightInk = Color(0xFFF3E9D8);
  static const Color nightSoft = Color(0xFFB7A995);
  static const Color nightRule = Color(0xFF5A4E42);

  /// Parses `#rrggbb`.
  static Color fromHex(String hex, {Color fallback = const Color(0xFFC9A27A)}) {
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null || cleaned.length != 6) return fallback;
    return Color(0xFF000000 | value);
  }
}
