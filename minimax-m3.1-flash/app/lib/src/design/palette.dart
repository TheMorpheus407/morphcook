import 'package:flutter/material.dart';

/// The MorphCook palette.
///
/// Warm paper, soft ink, and four muted accents (coral, teal, mustard, plum).
/// Everything is low-saturation on purpose: the app should feel like a
/// photocopied cookbook page, not a modern SaaS dashboard.
abstract final class MC {
  // ── Paper ────────────────────────────────────────────────────────────────
  static const Color paper = Color(0xFFF4EEE2);
  static const Color paperWarm = Color(0xFFEFE7D7);
  static const Color paperDeep = Color(0xFFE7DEC9);
  static const Color paperEdge = Color(0xFFDCD1B8);
  static const Color card = Color(0xFFFBF7EE);
  static const Color cardAlt = Color(0xFFF7F1E4);

  // ── Ink ──────────────────────────────────────────────────────────────────
  static const Color ink = Color(0xFF2C2823);
  static const Color inkSoft = Color(0xFF5F584C);
  static const Color inkFaint = Color(0xFF938B7C);
  static const Color inkGhost = Color(0xFFB5AC9A);
  static const Color rule = Color(0xFFC7BCA4);
  static const Color ruleFaint = Color(0xFFDDD4C0);

  // ── Accents ──────────────────────────────────────────────────────────────
  static const Color coral = Color(0xFFC4694D);
  static const Color coralSoft = Color(0xFFE7B6A2);
  static const Color teal = Color(0xFF5B8F81);
  static const Color tealSoft = Color(0xFFA9C6BC);
  static const Color mustard = Color(0xFFC29A42);
  static const Color mustardSoft = Color(0xFFE4CE9B);
  static const Color plum = Color(0xFF87687F);
  static const Color plumSoft = Color(0xFFCBB4C5);
  static const Color sage = Color(0xFF8FA486);
  static const Color inkBlue = Color(0xFF67849F);
  static const Color inkBlueSoft = Color(0xFFAFC2D2);

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF6D8F62);
  static const Color warning = Color(0xFFC08A3E);
  static const Color danger = Color(0xFFB5533F);

  /// A calm, slow vignette that keeps the paper from feeling flat.
  static const List<Color> paperVignette = <Color>[
    Color(0x00000000),
    Color(0x0A2C2823),
  ];

  /// Deterministic rotation for polaroid cards, so a given recipe always
  /// sits at the same jaunty angle across sessions.
  static double polaroidTilt(String seed) {
    var hash = 0;
    for (var i = 0; i < seed.length; i++) {
      hash = (hash * 31 + seed.codeUnitAt(i)) & 0x7fffffff;
    }
    final t = (hash % 1000) / 1000.0; // 0..1
    return -0.028 + t * 0.056; // ≈ ±1.6°
  }

  /// Stable pseudo-random in 0..1 for a string seed.
  static double unitRandom(String seed) {
    var hash = 0;
    for (var i = 0; i < seed.length; i++) {
      hash = (hash * 31 + seed.codeUnitAt(i)) & 0x7fffffff;
    }
    return (hash % 100000) / 100000.0;
  }
}
