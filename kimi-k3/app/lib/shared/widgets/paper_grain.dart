import 'dart:math';

import 'package:flutter/material.dart';

/// Subtle paper-grain overlay drawn over the paper background.
/// Deterministic seed → stable grain across rebuilds.
class PaperGrain extends StatelessWidget {
  final double opacity;
  final int density;
  const PaperGrain({super.key, this.opacity = 0.05, this.density = 900});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _GrainPainter(opacity: opacity, density: density),
        size: Size.infinite,
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  final double opacity;
  final int density;
  _GrainPainter({required this.opacity, required this.density});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    final paint = Paint()
      ..color = Colors.brown.withValues(alpha: opacity)
      ..strokeWidth = 0.8;
    for (var i = 0; i < density; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      canvas.drawCircle(Offset(dx, dy), rng.nextDouble() * 0.9, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter oldDelegate) => false;
}
