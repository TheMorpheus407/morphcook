import 'package:flutter/material.dart';

/// MorphCook's tumblr-era cookbook look: warm paper, ink, terracotta &
/// teal accents, Playfair italic display, JetBrains Mono labels, Caveat
/// handwriting. Calm, nostalgic, analog.
abstract final class MorphColors {
  static const paper = Color(0xFFF7F1E6);
  static const paperDeep = Color(0xFFEFE6D4);
  static const card = Color(0xFFFCF8F0);
  static const ink = Color(0xFF2C261E);
  static const inkSoft = Color(0xFF6E6354);
  static const inkFaint = Color(0xFFA89A86);
  static const terracotta = Color(0xFFC2603C);
  static const teal = Color(0xFF50837B);
  static const butter = Color(0xFFE9C46A);
  static const coral = Color(0xFFE76F51);
  static const line = Color(0xFFD8CCB8);

  // Cook mode (dark full-bleed)
  static const night = Color(0xFF191511);
  static const nightCard = Color(0xFF241F19);
  static const cream = Color(0xFFF3EBDD);
}

abstract final class MorphText {
  static const display = TextStyle(
    fontFamily: 'Playfair Display',
    fontStyle: FontStyle.italic,
    color: MorphColors.ink,
    height: 1.1,
  );

  static const serif = TextStyle(
    fontFamily: 'Playfair Display',
    color: MorphColors.ink,
    height: 1.25,
  );

  static const mono = TextStyle(
    fontFamily: 'JetBrains Mono',
    color: MorphColors.ink,
    height: 1.5,
  );

  static const hand = TextStyle(
    fontFamily: 'Caveat',
    color: MorphColors.inkSoft,
    height: 1.1,
  );

  /// Small uppercase mono label with wide tracking — the "typewritten" voice.
  static TextStyle label({Color color = MorphColors.inkSoft, double size = 11}) =>
      mono.copyWith(fontSize: size, letterSpacing: 1.6, color: color);
}

ThemeData morphTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: MorphColors.paper,
    colorScheme: ColorScheme.fromSeed(
      seedColor: MorphColors.terracotta,
      surface: MorphColors.paper,
      primary: MorphColors.terracotta,
      secondary: MorphColors.teal,
    ),
    splashFactory: InkRipple.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: MorphColors.ink,
      displayColor: MorphColors.ink,
      fontFamily: 'JetBrains Mono',
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: MorphColors.ink,
      elevation: 0,
      centerTitle: true,
    ),
    dividerColor: MorphColors.line,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: MorphColors.ink,
      contentTextStyle: MorphText.mono
          .copyWith(color: MorphColors.cream, fontSize: 12),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
    ),
  );
}

/// Animation durations honoring the reduceMotion preference
/// (null falls back to the platform setting).
Duration motionDuration(
  BuildContext context,
  bool? reduceMotionPref, {
  Duration normal = const Duration(milliseconds: 350),
}) {
  final disable =
      reduceMotionPref ?? MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return disable ? Duration.zero : normal;
}

/// Subtle paper grain: scattered specks + faint horizontal fibre lines.
class PaperGrainPainter extends CustomPainter {
  final Color speck;
  const PaperGrainPainter({this.speck = const Color(0x0E5B4A33)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = speck;
    // Deterministic pseudo-random scatter (no dart:math Random in paint).
    var seed = 9176;
    double next() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed / 0x7fffffff;
    }

    final speckCount = (size.width * size.height / 900).clamp(80, 1400).toInt();
    for (var i = 0; i < speckCount; i++) {
      final x = next() * size.width;
      final y = next() * size.height;
      final r = 0.4 + next() * 0.9;
      canvas.drawCircle(Offset(x, y), r, paint);
    }

    final linePaint = Paint()
      ..color = speck.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 7) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant PaperGrainPainter oldDelegate) => false;
}

/// Scaffold background that lays paper grain behind [child].
class PaperBackground extends StatelessWidget {
  final Widget child;
  final Color color;

  const PaperBackground(
      {super.key, required this.child, this.color = MorphColors.paper});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      child: CustomPaint(
        foregroundPainter: const PaperGrainPainter(),
        child: child,
      ),
    );
  }
}
