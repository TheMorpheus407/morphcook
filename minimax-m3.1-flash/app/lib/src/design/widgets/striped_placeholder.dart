import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../palette.dart';
import '../typography.dart';

/// A striped placeholder — the app's stand-in for photography.
///
/// The real MorphCook ships no food photography; the stripes are part of the
/// design language, not a placeholder for a missing asset. Each dish owns a
/// stripe colour, so the feed reads like a set of labelled index cards.
class StripedPlaceholder extends StatelessWidget {
  const StripedPlaceholder({
    super.key,
    required this.color,
    this.caption,
    this.captionSize = 19,
    this.height,
    this.stripeWidth = 7,
    this.angle = -math.pi / 4,
    this.showCaption = true,
    this.borderColor,
  });

  /// The dish's stripe colour.
  final Color color;

  /// Handwritten caption, usually the dish name.
  final String? caption;

  final double captionSize;
  final double? height;
  final double stripeWidth;
  final double angle;
  final bool showCaption;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final captionText = caption;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: CustomPaint(
        painter: _StripePainter(
          color: color,
          stripeWidth: stripeWidth,
          angle: angle,
        ),
        child: Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(
              color: borderColor ?? MC.ink.withValues(alpha: 0.10),
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: showCaption && captionText != null && captionText.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      captionText,
                      textAlign: TextAlign.center,
                      style: Type.script(
                        size: captionSize,
                        color: MC.ink.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  const _StripePainter({
    required this.color,
    required this.stripeWidth,
    required this.angle,
  });

  final Color color;
  final double stripeWidth;
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Paper-tinted base so the block still reads as paper.
    final base = Color.lerp(MC.paper, color, 0.10)!;
    canvas.drawRect(Offset.zero & size, Paint()..color = base);

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final stripe = Paint()..color = color.withValues(alpha: 0.72);
    final period = stripeWidth * 2;

    // Draw an oversized rotated rectangle grid so the diagonals run edge to
    // edge regardless of the canvas size.
    final diagonal = math.sqrt(size.width * size.width + size.height * size.height);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle);

    final bands = (diagonal / period).ceil() + 2;
    for (var i = -bands; i <= bands; i++) {
      final x = i * period;
      canvas.drawRect(
        Rect.fromLTWH(x, -diagonal, stripeWidth, diagonal * 2),
        stripe,
      );
    }

    canvas.restore();

    // A soft inner shadow keeps the block from floating.
    final vignette = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          MC.ink.withValues(alpha: 0.10),
          MC.ink.withValues(alpha: 0.0),
          MC.ink.withValues(alpha: 0.12),
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(_StripePainter old) =>
      old.color != color ||
      old.stripeWidth != stripeWidth ||
      old.angle != angle;
}
