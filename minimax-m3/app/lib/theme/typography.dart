import 'package:flutter/material.dart';

import 'colors.dart';

/// Three faces — display (Playfair italic), body (Inter), mono (JetBrains
/// Mono) — plus a handwritten accent (Caveat).
///
/// All fonts are bundled as `assets/fonts/*.ttf` and declared in `pubspec.yaml`
/// — no network fetch, no `google_fonts` at runtime. The app works fully
/// offline on a fresh install.
class MCTypography {
  const MCTypography._();

  static TextStyle display({
    double size = 44,
    FontStyle? style,
    Color? color,
    double height = 1.05,
  }) =>
      TextStyle(
        fontFamily: 'Playfair Display',
        fontSize: size,
        fontStyle: style ?? FontStyle.italic,
        fontWeight: FontWeight.w600,
        color: color ?? MCColors.ink,
        height: height,
        letterSpacing: -0.5,
      );

  static TextStyle title({
    double size = 28,
    Color? color,
    FontWeight weight = FontWeight.w600,
  }) =>
      TextStyle(
        fontFamily: 'Playfair Display',
        fontSize: size,
        fontWeight: weight,
        color: color ?? MCColors.ink,
        height: 1.15,
        letterSpacing: -0.3,
      );

  static TextStyle italic({double size = 18, Color? color}) =>
      TextStyle(
        fontFamily: 'Playfair Display',
        fontSize: size,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w500,
        color: color ?? MCColors.inkSoft,
        height: 1.3,
      );

  static TextStyle body({
    double size = 14.5,
    Color? color,
    FontWeight weight = FontWeight.w400,
    double height = 1.5,
  }) =>
      TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        fontWeight: weight,
        color: color ?? MCColors.ink,
        height: height,
      );

  static TextStyle small({
    double size = 12,
    Color? color,
    FontWeight weight = FontWeight.w400,
  }) =>
      TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        fontWeight: weight,
        color: color ?? MCColors.inkFaded,
        letterSpacing: 0.2,
      );

  static TextStyle mono({
    double size = 12,
    Color? color,
    FontWeight weight = FontWeight.w400,
  }) =>
      TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: size,
        fontWeight: weight,
        color: color ?? MCColors.inkFaded,
        letterSpacing: 0.4,
      );

  static TextStyle handwritten({double size = 22, Color? color, double turns = 0}) =>
      TextStyle(
        fontFamily: 'Caveat',
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color ?? MCColors.coral,
        height: 1.2,
      );

  static TextStyle masthead({Color? color}) => TextStyle(
        fontFamily: 'Playfair Display',
        fontSize: 40,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w700,
        color: color ?? MCColors.ink,
        letterSpacing: -0.6,
      );

  static TextStyle caption({Color? color}) => TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: color ?? MCColors.inkFaded,
        letterSpacing: 1.2,
      );

  static TextStyle eyebrow({Color? color}) => TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: 10.5,
        fontWeight: FontWeight.w500,
        color: color ?? MCColors.inkWhisper,
        letterSpacing: 2.5,
      );
}
