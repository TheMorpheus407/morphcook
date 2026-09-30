import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// The photo stand-in: soft diagonal stripes in the dish colour with a
/// typed caption label, like a placeholder in a proof print.
class StripedPlaceholder extends StatelessWidget {
  const StripedPlaceholder({
    super.key,
    required this.color,
    this.caption,
    this.angle = -pi / 4,
    this.stripeWidth = 9,
    this.captionSize = 10,
    this.showCaption = true,
  });

  final Color color;
  final String? caption;
  final double angle;
  final double stripeWidth;
  final double captionSize;
  final bool showCaption;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _StripePainter(color, angle, stripeWidth)),
        if (showCaption && caption != null && caption!.isNotEmpty)
          Positioned(
            left: 10,
            bottom: 10,
            right: 10,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                color: MC.card.withValues(alpha: 0.9),
                child: Text(
                  caption!,
                  style: MT.mono(captionSize, color: MC.inkSoft),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StripePainter extends CustomPainter {
  _StripePainter(this.color, this.angle, this.width);
  final Color color;
  final double angle;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final light = Color.lerp(color, MC.card, 0.72)!;
    final dark = Color.lerp(color, MC.card, 0.45)!;
    canvas.drawRect(Offset.zero & size, Paint()..color = light);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle);
    final diag = sqrt(size.width * size.width + size.height * size.height);
    final paint = Paint()..color = dark;
    for (var x = -diag; x < diag; x += width * 2) {
      canvas.drawRect(Rect.fromLTWH(x, -diag, width, diag * 2), paint);
    }
    canvas.restore();
    // soft vignette so it feels printed, not flat
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.transparent, MC.ink.withValues(alpha: 0.08)],
          stops: const [0.6, 1],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _StripePainter old) => old.color != color || old.angle != angle || old.width != width;
}
