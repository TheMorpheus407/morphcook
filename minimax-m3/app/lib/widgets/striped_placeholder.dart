import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// A striped placeholder, drawn procedurally. Pulls the color from the dish
/// metadata (`stripe_color`) so each placeholder feels like part of the dish.
///
/// Stripes are diagonal (≈ 30°) and fairly chunky — the goal is a quiet, 1980s
/// printed-cookbook feel, not a glossy gradient.
class StripedPlaceholder extends StatelessWidget {
  final Color stripeColor;
  final String? caption;
  final double aspectRatio;
  final double rotationTurns;

  const StripedPlaceholder({
    super.key,
    required this.stripeColor,
    this.caption,
    this.aspectRatio = 4 / 3,
    this.rotationTurns = 0,
  });

  @override
  Widget build(BuildContext context) {
    final inner = AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _StripesPainter(color: stripeColor),
              ),
            ),
            if (caption != null)
              Positioned(
                left: 12,
                bottom: 8,
                right: 12,
                child: Text(
                  caption!.toLowerCase(),
                  style: TextStyle(
                    color: MCColors.cream,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(
                        color: MCColors.ink.withValues(alpha: 0.5),
                        blurRadius: 1,
                        offset: const Offset(0.4, 0.4),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (rotationTurns == 0) return inner;
    return Transform.rotate(angle: rotationTurns * 2 * math.pi, child: inner);
  }
}

class _StripesPainter extends CustomPainter {
  final Color color;

  _StripesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas.drawRect(Offset.zero & size, paint);

    final stripe = Paint()..color = _darken(color, 0.18);
    const stripeWidth = 14.0;
    const gap = 14.0;
    final diagonal = size.width + size.height;
    canvas.save();
    canvas.translate(0, 0);
    canvas.rotate(-math.pi / 6);
    for (double x = -size.height; x < diagonal + size.height; x += stripeWidth + gap) {
      canvas.drawRect(
        Rect.fromLTWH(x, -size.height, stripeWidth, diagonal + size.height * 2),
        stripe,
      );
    }
    canvas.restore();

    // soft vignette
    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          MCColors.ink.withValues(alpha: 0.16),
        ],
        stops: const [0.6, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    final l = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(l).toColor();
  }

  @override
  bool shouldRepaint(covariant _StripesPainter old) => old.color != color;
}
