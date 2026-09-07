import 'package:flutter/material.dart';

import 'palette.dart';

/// Three voices: Playfair Display (the cookbook), JetBrains Mono (the
/// labels and numbers), Caveat (the handwriting in the margins).
class Fonts {
  Fonts._();
  static const String serif = 'Playfair Display';
  static const String mono = 'JetBrains Mono';
  static const String hand = 'Caveat';
}

class AppText {
  AppText._();

  static TextStyle display({Color color = Palette.ink, double size = 34}) => TextStyle(
        fontFamily: Fonts.serif,
        fontStyle: FontStyle.italic,
        fontSize: size,
        height: 1.1,
        letterSpacing: -0.6,
        color: color,
        fontWeight: FontWeight.w500,
      );

  static TextStyle title({Color color = Palette.ink, double size = 22, bool italic = false}) => TextStyle(
        fontFamily: Fonts.serif,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        fontSize: size,
        height: 1.2,
        letterSpacing: -0.2,
        color: color,
        fontWeight: FontWeight.w600,
      );

  static TextStyle body({Color color = Palette.ink, double size = 15.5}) => TextStyle(
        fontFamily: Fonts.serif,
        fontSize: size,
        height: 1.55,
        color: color,
        fontWeight: FontWeight.w400,
      );

  static TextStyle bodyItalic({Color color = Palette.inkSoft, double size = 15.5}) =>
      body(color: color, size: size).copyWith(fontStyle: FontStyle.italic);

  static TextStyle mono({Color color = Palette.inkSoft, double size = 12, FontWeight weight = FontWeight.w500}) =>
      TextStyle(
        fontFamily: Fonts.mono,
        fontSize: size,
        height: 1.4,
        letterSpacing: 0.4,
        color: color,
        fontWeight: weight,
      );

  static TextStyle monoLabel({Color color = Palette.inkFaint, double size = 11}) =>
      mono(color: color, size: size).copyWith(letterSpacing: 1.1);

  static TextStyle hand({Color color = Palette.inkSoft, double size = 20}) => TextStyle(
        fontFamily: Fonts.hand,
        fontSize: size,
        height: 1.15,
        color: color,
        fontWeight: FontWeight.w500,
      );
}
