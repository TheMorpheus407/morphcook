import 'package:flutter/material.dart';

/// The nostalgic-calm palette.
///
/// Everything sits on warm, slightly yellowed paper. Nothing is pure white and
/// nothing is pure black — the highest contrast pair in the light theme is ink
/// on paper, which lands around 12:1, comfortably past AA without the glare of
/// #000 on #FFF. Accents are muted and earthy: a faded coral, a dusty teal, a
/// mustard that has been in the sun.
class Paper {
  Paper._();

  // --- light ---------------------------------------------------------------
  static const Color base = Color(0xFFF7F1E4); // aged paper
  static const Color raised = Color(0xFFFDF9F0); // a fresher sheet on top
  static const Color sunk = Color(0xFFEFE7D6); // pressed / inset
  static const Color edge = Color(0xFFDDD1BA); // rule and hairline
  static const Color ink = Color(0xFF2E2A24); // body text
  static const Color inkSoft = Color(0xFF6A6154); // secondary text
  static const Color inkFaint = Color(0xFF9A9184); // captions, disabled

  // --- dark ----------------------------------------------------------------
  static const Color baseDark = Color(0xFF1C1A17);
  static const Color raisedDark = Color(0xFF262320);
  static const Color sunkDark = Color(0xFF141210);
  static const Color edgeDark = Color(0xFF3B362F);
  static const Color inkDark = Color(0xFFEFE7D8);
  static const Color inkSoftDark = Color(0xFFB6AC9A);
  static const Color inkFaintDark = Color(0xFF7E756A);

  // --- accents (shared) ----------------------------------------------------
  static const Color coral = Color(0xFFC96F53); // primary accent
  static const Color coralSoft = Color(0xFFE9C4B6);
  static const Color teal = Color(0xFF4E7F7B); // secondary accent
  static const Color tealSoft = Color(0xFFBBD2CF);
  static const Color mustard = Color(0xFFC79A3C);
  static const Color olive = Color(0xFF7A8352);
  static const Color plum = Color(0xFF7A5468);

  /// Cook-mode surface: not black, just a very dark room.
  static const Color night = Color(0xFF14120F);
  static const Color nightRaised = Color(0xFF1E1B17);
}

@immutable
class MorphColors extends ThemeExtension<MorphColors> {
  const MorphColors({
    required this.paper,
    required this.paperRaised,
    required this.paperSunk,
    required this.edge,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.accent,
    required this.accentSoft,
    required this.secondary,
    required this.secondarySoft,
    required this.mustard,
    required this.grainOpacity,
  });

  static const MorphColors light = MorphColors(
    paper: Paper.base,
    paperRaised: Paper.raised,
    paperSunk: Paper.sunk,
    edge: Paper.edge,
    ink: Paper.ink,
    inkSoft: Paper.inkSoft,
    inkFaint: Paper.inkFaint,
    accent: Paper.coral,
    accentSoft: Paper.coralSoft,
    secondary: Paper.teal,
    secondarySoft: Paper.tealSoft,
    mustard: Paper.mustard,
    grainOpacity: 0.05,
  );

  static const MorphColors dark = MorphColors(
    paper: Paper.baseDark,
    paperRaised: Paper.raisedDark,
    paperSunk: Paper.sunkDark,
    edge: Paper.edgeDark,
    ink: Paper.inkDark,
    inkSoft: Paper.inkSoftDark,
    inkFaint: Paper.inkFaintDark,
    accent: Color(0xFFDD8A6E),
    accentSoft: Color(0xFF56352C),
    secondary: Color(0xFF7FB0AB),
    secondarySoft: Color(0xFF27403E),
    mustard: Color(0xFFD9B25C),
    grainOpacity: 0.035,
  );

  final Color paper;
  final Color paperRaised;
  final Color paperSunk;
  final Color edge;
  final Color ink;
  final Color inkSoft;
  final Color inkFaint;
  final Color accent;
  final Color accentSoft;
  final Color secondary;
  final Color secondarySoft;
  final Color mustard;
  final double grainOpacity;

  @override
  MorphColors copyWith({
    Color? paper,
    Color? paperRaised,
    Color? paperSunk,
    Color? edge,
    Color? ink,
    Color? inkSoft,
    Color? inkFaint,
    Color? accent,
    Color? accentSoft,
    Color? secondary,
    Color? secondarySoft,
    Color? mustard,
    double? grainOpacity,
  }) => MorphColors(
    paper: paper ?? this.paper,
    paperRaised: paperRaised ?? this.paperRaised,
    paperSunk: paperSunk ?? this.paperSunk,
    edge: edge ?? this.edge,
    ink: ink ?? this.ink,
    inkSoft: inkSoft ?? this.inkSoft,
    inkFaint: inkFaint ?? this.inkFaint,
    accent: accent ?? this.accent,
    accentSoft: accentSoft ?? this.accentSoft,
    secondary: secondary ?? this.secondary,
    secondarySoft: secondarySoft ?? this.secondarySoft,
    mustard: mustard ?? this.mustard,
    grainOpacity: grainOpacity ?? this.grainOpacity,
  );

  @override
  MorphColors lerp(ThemeExtension<MorphColors>? other, double t) {
    if (other is! MorphColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return MorphColors(
      paper: c(paper, other.paper),
      paperRaised: c(paperRaised, other.paperRaised),
      paperSunk: c(paperSunk, other.paperSunk),
      edge: c(edge, other.edge),
      ink: c(ink, other.ink),
      inkSoft: c(inkSoft, other.inkSoft),
      inkFaint: c(inkFaint, other.inkFaint),
      accent: c(accent, other.accent),
      accentSoft: c(accentSoft, other.accentSoft),
      secondary: c(secondary, other.secondary),
      secondarySoft: c(secondarySoft, other.secondarySoft),
      mustard: c(mustard, other.mustard),
      grainOpacity: grainOpacity + (other.grainOpacity - grainOpacity) * t,
    );
  }
}

extension MorphColorsX on BuildContext {
  MorphColors get colors =>
      Theme.of(this).extension<MorphColors>() ?? MorphColors.light;
}
