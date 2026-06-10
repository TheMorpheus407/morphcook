import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// A subtle "paper grain" background painted procedurally — no asset PNG
/// required. The grain is deterministic per-size and runs at quiet opacity so
/// it never competes with content. Perfect for the cream-card aesthetic.
class PaperBackground extends StatelessWidget {
  final Widget child;
  final Color color;
  final double grainOpacity;

  const PaperBackground({
    super.key,
    required this.child,
    this.color = MCColors.cream,
    this.grainOpacity = 0.05,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: CustomPaint(
        painter: _GrainPainter(opacity: grainOpacity, seed: color.toARGB32()),
        child: child,
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  final double opacity;
  final int seed;

  _GrainPainter({required this.opacity, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final paint = Paint();
    // sparse pepper of dark dots
    final dots = (size.width * size.height / 220).round().clamp(120, 1800);
    for (var i = 0; i < dots; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      final radius = rng.nextDouble() * 0.7 + 0.15;
      final a = (rng.nextDouble() * 0.6 + 0.4) * opacity;
      paint.color = MCColors.ink.withValues(alpha: a);
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
    // a few warm specks
    final specks = (dots / 8).round();
    for (var i = 0; i < specks; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      final radius = rng.nextDouble() * 1.2 + 0.6;
      paint.color = MCColors.coral.withValues(alpha: opacity * 0.35);
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter old) =>
      old.opacity != opacity || old.seed != seed;
}
