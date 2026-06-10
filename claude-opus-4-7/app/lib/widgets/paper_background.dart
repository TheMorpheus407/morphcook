import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Soft paper-grain background. Uses a CustomPainter that scatters
/// translucent micro-dots so the texture survives any screen size
/// without bundling a bitmap.
class PaperBackground extends StatelessWidget {
  final Widget child;
  final double grainOpacity;
  final bool showVignette;
  const PaperBackground({
    super.key,
    required this.child,
    this.grainOpacity = 0.045,
    this.showVignette = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MorphColors.paper,
      child: CustomPaint(
        painter: _PaperPainter(opacity: grainOpacity, vignette: showVignette),
        child: child,
      ),
    );
  }
}

class _PaperPainter extends CustomPainter {
  final double opacity;
  final bool vignette;
  _PaperPainter({required this.opacity, required this.vignette});

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle warm wash, slightly darker at edges.
    if (vignette) {
      final rect = Offset.zero & size;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            radius: 0.95,
            colors: [
              MorphColors.paper,
              MorphColors.paperDeep.withValues(alpha: 0.55),
            ],
            stops: const [0.4, 1.0],
          ).createShader(rect),
      );
    }

    // Deterministic grain so the texture doesn't shimmer on repaint.
    final rng = math.Random(7);
    final grain = Paint()..color = MorphColors.ink.withValues(alpha: opacity);
    final count = (size.width * size.height / 950).clamp(120, 5000).toInt();
    for (int i = 0; i < count; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 0.7 + 0.15;
      canvas.drawCircle(Offset(dx, dy), r, grain);
    }
  }

  @override
  bool shouldRepaint(covariant _PaperPainter oldDelegate) =>
      oldDelegate.opacity != opacity || oldDelegate.vignette != vignette;
}
