import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_fonts.dart';
import 'app_theme.dart';

/// The striped SVG-style photo placeholder with mono caption — part of the
/// design language (SPEC: "Real photos — striped placeholders stay, they're
/// part of the design"). Draws diagonal stripes in the dish's stripe color
/// over paper, with a hand-drawn frame and the caption beneath.
class StripedPlaceholder extends StatelessWidget {
  const StripedPlaceholder({
    super.key,
    required this.stripeColor,
    required this.caption,
    this.height = 180,
    this.aspect,
    this.seed = 3,
  });

  final Color stripeColor;
  final String caption;

  /// Fixed height (used when [aspect] is null).
  final double height;

  /// Optional width/height aspect ratio (e.g. 1.4 for polaroids).
  final double? aspect;

  final int seed;

  @override
  Widget build(BuildContext context) {
    final frame = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: aspect ?? 1.6,
          child: CustomPaint(
            painter: _StripesPainter(stripeColor: stripeColor, seed: seed),
            child: const SizedBox.expand(),
          ),
        ),
        Container(
          color: AppColors.paperCard,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppFonts.mono(size: 10, color: AppColors.inkSoft),
          ),
        ),
      ],
    );
    return frame;
  }
}

class _StripesPainter extends CustomPainter {
  _StripesPainter({required this.stripeColor, required this.seed});

  final Color stripeColor;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = AppColors.paperCard);

    // Diagonal stripes.
    final stripePaint = Paint()
      ..color = stripeColor.withOpacity(0.55)
      ..isAntiAlias = true;
    const stripeWidth = 14.0;
    const gap = 9.0;
    final step = stripeWidth + gap;
    final diagonal = size.width + size.height;
    for (var d = -size.height; d < diagonal; d += step) {
      final path = Path()
        ..moveTo(d, 0)
        ..lineTo(d + stripeWidth, 0)
        ..lineTo(d + stripeWidth + size.height, size.height)
        ..lineTo(d + size.height, size.height)
        ..close();
      canvas.drawPath(path, stripePaint);
    }

    // Second, softer stripe layer offset for a woven feel.
    final weave = Paint()..color = stripeColor.withOpacity(0.25);
    for (var d = -size.height + step / 2; d < diagonal; d += step * 3) {
      final path = Path()
        ..moveTo(d, 0)
        ..lineTo(d + stripeWidth / 2, 0)
        ..lineTo(d + stripeWidth / 2 + size.height, size.height)
        ..lineTo(d + size.height, size.height)
        ..close();
      canvas.drawPath(path, weave);
    }

    // A few deterministic "grain" dots for texture.
    final rng = math.Random(seed);
    final dots = Paint()..color = AppColors.ink.withOpacity(0.06);
    for (var i = 0; i < 40; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        0.8,
        dots,
      );
    }

    // Ink frame.
    canvas.drawRect(
      rect.deflate(3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AppColors.ink.withOpacity(0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _StripesPainter oldDelegate) =>
      oldDelegate.stripeColor != stripeColor || oldDelegate.seed != seed;
}
