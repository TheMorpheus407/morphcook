import 'dart:math' as math;

import 'package:flutter/material.dart';

class MorphColors {
  const MorphColors._();

  static const paper = Color(0xfff7f0e4);
  static const paperDeep = Color(0xffeee2d0);
  static const ink = Color(0xff2b2924);
  static const mutedInk = Color(0xff726a5e);
  static const coral = Color(0xffcf6c60);
  static const teal = Color(0xff377b78);
  static const mustard = Color(0xffd3a846);
  static const olive = Color(0xff828b6d);
  static const night = Color(0xff1c211f);
  static const nightPaper = Color(0xffd9d0c1);
}

ThemeData morphTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: MorphColors.teal,
      brightness: Brightness.light,
      surface: MorphColors.paper,
    ),
  );
  return base.copyWith(
    scaffoldBackgroundColor: MorphColors.paper,
    textTheme: base.textTheme.copyWith(
      displayLarge: const TextStyle(
        fontFamily: 'Georgia',
        fontSize: 50,
        height: .94,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic,
        color: MorphColors.ink,
      ),
      displayMedium: const TextStyle(
        fontFamily: 'Georgia',
        fontSize: 35,
        height: 1,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic,
        color: MorphColors.ink,
      ),
      headlineSmall: const TextStyle(
        fontFamily: 'Georgia',
        fontSize: 25,
        height: 1.05,
        fontWeight: FontWeight.w700,
        color: MorphColors.ink,
      ),
      titleLarge: const TextStyle(
        fontFamily: 'Georgia',
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: MorphColors.ink,
      ),
      bodyLarge: const TextStyle(
        fontFamily: 'Georgia',
        fontSize: 17,
        height: 1.35,
        color: MorphColors.ink,
      ),
      bodyMedium: const TextStyle(
        fontFamily: 'Georgia',
        fontSize: 15,
        height: 1.35,
        color: MorphColors.ink,
      ),
      labelLarge: const TextStyle(
        fontFamily: 'Courier',
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: .5,
        color: MorphColors.ink,
      ),
      labelMedium: const TextStyle(
        fontFamily: 'Courier',
        fontSize: 10,
        letterSpacing: .7,
        color: MorphColors.mutedInk,
      ),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: MorphColors.ink,
      centerTitle: false,
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xffb8a995),
      thickness: .8,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: .52),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: Color(0xff8e8272)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: Color(0xffa79b89)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: MorphColors.teal, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      labelStyle: const TextStyle(
        fontFamily: 'Courier',
        color: MorphColors.mutedInk,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      side: const BorderSide(color: Color(0xff928574)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      labelStyle: const TextStyle(fontFamily: 'Courier', fontSize: 11),
      backgroundColor: Colors.transparent,
    ),
  );
}

Color stripeColor(String hex) {
  final source = hex.replaceAll('#', '');
  final value = int.tryParse(source, radix: 16) ?? 0xffbc8069;
  return Color(0xff000000 | value);
}

class PaperGrain extends StatelessWidget {
  const PaperGrain({
    super.key,
    required this.child,
    this.color = MorphColors.paper,
  });

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _PaperPainter(color), child: child);
}

class _PaperPainter extends CustomPainter {
  const _PaperPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
    final fleck = Paint()
      ..color = const Color(0xff675b4b).withValues(alpha: .055);
    final rng = math.Random(29);
    final count = (size.width * size.height / 1200).ceil();
    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final radius = .18 + rng.nextDouble() * .7;
      canvas.drawCircle(Offset(x, y), radius, fleck);
    }
  }

  @override
  bool shouldRepaint(covariant _PaperPainter oldDelegate) =>
      oldDelegate.color != color;
}
