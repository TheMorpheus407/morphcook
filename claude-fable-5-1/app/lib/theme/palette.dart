import 'package:flutter/material.dart';

/// Warm paper and soft ink. Nothing in here is saturated on purpose.
class Palette {
  Palette._();

  static const Color paper = Color(0xFFF4EDE1);
  static const Color paperDeep = Color(0xFFEADFCC);
  static const Color paperLight = Color(0xFFFBF7EF);
  static const Color paperShadow = Color(0x1F2A2420);

  static const Color ink = Color(0xFF2A2420);
  static const Color inkSoft = Color(0xFF5C534B);
  static const Color inkFaint = Color(0xFF8C8177);
  static const Color rule = Color(0xFFC9BDAA);
  static const Color ruleStrong = Color(0xFFA89C88);

  static const Color rose = Color(0xFFD39B8F);
  static const Color sage = Color(0xFF8FA58F);
  static const Color mustard = Color(0xFFD6B15E);
  static const Color terracotta = Color(0xFFC27C5A);
  static const Color slate = Color(0xFF7E8AA0);
  static const Color plum = Color(0xFF9C6B7D);

  static const Color flashCoral = Color(0xFFE07A5F);
  static const Color flashTeal = Color(0xFF5F9EA0);

  static const Color night = Color(0xFF1A1816);
  static const Color nightSurface = Color(0xFF26221F);
  static const Color nightInk = Color(0xFFF1E9DC);
  static const Color nightInkSoft = Color(0xFFBFB5A8);
  static const Color nightInkFaint = Color(0xFF8A8074);
  static const Color nightRule = Color(0xFF3B3631);

  /// Tints a stripe colour towards paper for the alternate stripe.
  static Color tint(Color c, [double amount = 0.55]) => Color.lerp(c, paperLight, amount)!;

  /// Deepens a colour for text on tinted surfaces.
  static Color shade(Color c, [double amount = 0.35]) => Color.lerp(c, ink, amount)!;
}
