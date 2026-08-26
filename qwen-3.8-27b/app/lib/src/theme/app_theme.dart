import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The nostalgic-calm palette: warm paper, soft clay &amp; sage,
/// ink that is never quite black.
class PaperColors {
  const PaperColors({
    required this.paper50,
    required this.paper100,
    required this.paper200,
    required this.paper300,
    required this.card,
    required this.line,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.clay,
    required this.claySoft,
    required this.sage,
    required this.sageSoft,
    required this.teal,
    required this.coral,
    required this.mustard,
    required this.cream,
  });

  final Color paper50;
  final Color paper100;
  final Color paper200;
  final Color paper300;
  final Color card;
  final Color line;
  final Color ink;
  final Color inkSoft;
  final Color inkFaint;
  final Color clay;
  final Color claySoft;
  final Color sage;
  final Color sageSoft;
  final Color teal;
  final Color coral;
  final Color mustard;
  final Color cream;

  Color stripePair(int seed) => _stripePool[seed.abs() % _stripePool.length];

  static const List<Color> _stripePool = [
    Color(0xFFF0E2D2),
    Color(0xFFEADDC9),
    Color(0xFFEBE3D2),
    Color(0xFFE7E9DA),
    Color(0xFFE4EADF),
    Color(0xFFE8DED0),
    Color(0xFFE3DBD3),
    Color(0xFFE9E2D9),
    Color(0xFFE5E0EE),
    Color(0xFFE6DFE4),
  ];
}

const PaperColors paper = PaperColors(
  paper50: Color(0xFFF7F1E8),
  paper100: Color(0xFFF2EADE),
  paper200: Color(0xFFEAE0CF),
  paper300: Color(0xFFDED1BC),
  card: Color(0xFFFDFBF7),
  line: Color(0xFFD9CDB8),
  ink: Color(0xFF2B2A26),
  inkSoft: Color(0xFF5C584E),
  inkFaint: Color(0xFF8A8474),
  clay: Color(0xFFC2764B),
  claySoft: Color(0xFFE8CDB6),
  sage: Color(0xFF7E8C67),
  sageSoft: Color(0xFFD4DCC5),
  teal: Color(0xFF5F8B84),
  coral: Color(0xFFCE7B5B),
  mustard: Color(0xFFC79A44),
  cream: Color(0xFFF4ECDC),
);

int _hash(String s) {
  var h = 2166136261;
  for (final c in s.codeUnits) {
    h = (h ^ c) * 16777619;
  }
  return h & 0x7fffffff;
}

/// Subtle paper-grain speckle overlay, stable per [seed].
class GrainBox extends SingleChildRenderObjectWidget {
  const GrainBox({
    super.key,
    required this.child,
    this.seed = 'paper',
    this.dotColor = const Color(0xFF2B2A26),
    this.alpha = 0.05,
    this.density = 2400,
  });

  final Widget child;
  final String seed;
  final Color dotColor;
  final double alpha;
  final double density;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderGrainBox(seed: seed, dotColor: dotColor, alpha: alpha, density: density);
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderGrainBox)
      ..seed = seed
      ..dotColor = dotColor
      ..alpha = alpha
      ..density = density;
  }
}

class _RenderGrainBox extends RenderProxyBox {
  _RenderGrainBox({
    required String seed,
    required Color dotColor,
    required double alpha,
    required double density,
  })  : _seed = seed,
        _dotColor = dotColor,
        _alpha = alpha,
        _density = density;

  String _seed;
  Color _dotColor;
  double _alpha;
  double _density;

  set seed(String v) => _seed = v;
  set dotColor(Color v) => _dotColor = v;
  set alpha(double v) => _alpha = v;
  set density(double v) => _density = v;

  @override
  void paint(PaintingContext pc, Offset offset) {
    super.paint(pc, offset);
    if (size == Size.zero) return;
    final canvas = pc.canvas;
    final rng = math.Random(_hash(_seed));
    final count = (size.width * size.height / density).clamp(40, 1200).toInt();
    final paint = Paint()
      ..color = _dotColor.withValues(alpha: _alpha)
      ..strokeWidth = 1.1;
    for (var i = 0; i < count; i++) {
      canvas.drawCircle(
        offset + Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        0.5 + rng.nextDouble() * 0.8,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RenderGrainBox old) =>
      old._seed != _seed || old._dotColor != _dotColor || old._alpha != _alpha;
}

/// Builds the app theme.
ThemeData appTheme({required bool dark}) {
  final base = dark ? ThemeData.dark() : ThemeData.light();
  final c = paper;
  final textTheme = const TextTheme();
  return base.copyWith(
    scaffoldBackgroundColor: c.paper100,
    canvasColor: c.card,
    cardColor: c.card,
    colorScheme: base.colorScheme.copyWith(
      primary: c.clay,
      onPrimary: c.paper50,
      secondary: c.sage,
      onSecondary: c.paper50,
      surface: c.card,
      onSurface: c.ink,
      outline: c.line,
    ),
    textTheme: textTheme.apply(bodyColor: c.ink, displayColor: c.ink),
    dividerColor: c.line,
    splashColor: c.claySoft.withValues(alpha: 0.5),
    highlightColor: c.claySoft.withValues(alpha: 0.3),
  );
}

/// House typography.
class TypeStyle {
  static const String serif = 'Playfair Display';
  static const String mono = 'JetBrains Mono';
  static const String hand = 'Caveat';

  static TextStyle masthead({double size = 34, Color? color}) => TextStyle(
        fontFamily: serif,
        fontStyle: FontStyle.italic,
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.12,
        letterSpacing: -0.5,
        color: color,
      );

  static TextStyle sectionTitle({double size = 21, Color? color}) => TextStyle(
        fontFamily: serif,
        fontStyle: FontStyle.italic,
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: color,
      );

  static TextStyle mono({
    double size = 12,
    Color? color,
    FontWeight weight = FontWeight.w500,
    double height = 1.5,
  }) =>
      TextStyle(
        fontFamily: mono,
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: 0.4,
        color: color,
      );

  static TextStyle hand({double size = 19, Color? color}) => TextStyle(
        fontFamily: hand,
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.15,
        color: color,
      );

  static TextStyle body({double size = 14.5, Color? color}) => TextStyle(
        fontSize: size,
        height: 1.55,
        color: color,
      );
}
