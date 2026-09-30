import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/palette.dart';
import '../core/theme/typography.dart';

/// Diagonal-stripe vector placeholder. Real photos are out of scope for v1, so
/// the stripes are part of the design: a tinted band pattern plus a caption.
class StripePainter extends CustomPainter {
  const StripePainter({required this.color, this.stripeWidth = 11, this.angle = -math.pi / 4});

  final Color color;
  final double stripeWidth;
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = Color.alphaBlend(color.withValues(alpha: 0.28), Palette.paperLight));
    canvas.save();
    canvas.clipRect(rect);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle);
    final diagonal = math.sqrt(size.width * size.width + size.height * size.height);
    final paint = Paint()..color = color.withValues(alpha: 0.5);
    for (var x = -diagonal; x < diagonal; x += stripeWidth * 2) {
      canvas.drawRect(Rect.fromLTWH(x, -diagonal, stripeWidth, diagonal * 2), paint);
    }
    canvas.restore();
    // A soft light falling from the top left, so the stripes feel printed on card.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.16), Colors.transparent, Palette.ink.withValues(alpha: 0.08)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(StripePainter old) => old.color != color || old.stripeWidth != stripeWidth || old.angle != angle;
}

/// A striped placeholder with a mono caption in the corner ("photo: ...").
class StripePlaceholder extends StatelessWidget {
  const StripePlaceholder({
    super.key,
    required this.color,
    this.caption,
    this.aspectRatio = 4 / 3,
    this.stripeWidth = 11,
    this.captionInset = 8,
    this.border = true,
  });

  final Color color;
  final String? caption;
  final double? aspectRatio;
  final double stripeWidth;
  final double captionInset;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final content = DecoratedBox(
      decoration: BoxDecoration(border: border ? Border.all(color: Palette.paperEdge) : null),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: StripePainter(color: color, stripeWidth: stripeWidth),
          ),
          if (caption != null && caption!.isNotEmpty)
            Positioned(
              left: captionInset,
              right: captionInset,
              bottom: captionInset,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  color: Palette.paperLight.withValues(alpha: 0.92),
                  child: Text(
                    caption!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.mono(size: 9.5, color: Palette.inkSoft, letterSpacing: 0.2, height: 1.25),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return ExcludeSemantics(
      child: aspectRatio == null ? content : AspectRatio(aspectRatio: aspectRatio!, child: content),
    );
  }
}
