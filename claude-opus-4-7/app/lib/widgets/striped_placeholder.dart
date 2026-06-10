import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';

/// The signature striped placeholder. No real photos in v1 — the stripes
/// stay. Caption sits over the stripes in JetBrains Mono small caps.
class StripedPlaceholder extends StatelessWidget {
  final Color stripeColor;
  final String? caption;
  final double width;
  final double height;
  final double rotation;
  final BorderRadius? radius;
  final bool dense;

  const StripedPlaceholder({
    super.key,
    required this.stripeColor,
    this.caption,
    this.width = double.infinity,
    this.height = 220,
    this.rotation = 0,
    this.radius,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: ClipRRect(
        borderRadius: radius ?? BorderRadius.zero,
        child: SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: _StripePainter(color: stripeColor, dense: dense),
            child: caption == null
                ? const SizedBox()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        caption!.toLowerCase(),
                        style: MorphType.smallCaps(
                          size: 11,
                          color: MorphColors.paper,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  final Color color;
  final bool dense;
  _StripePainter({required this.color, this.dense = false});

  @override
  void paint(Canvas canvas, Size size) {
    // base wash
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = color.withValues(alpha: 0.92),
    );
    // diagonal stripes
    final stripe = Paint()
      ..color = MorphColors.paper.withValues(alpha: dense ? 0.18 : 0.22)
      ..strokeWidth = dense ? 6 : 10
      ..style = PaintingStyle.stroke;
    final gap = dense ? 14.0 : 22.0;
    final diag = size.width + size.height;
    for (double x = -size.height; x < diag; x += gap) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        stripe,
      );
    }
    // soft top vignette for caption legibility
    canvas.drawRect(
      Offset(0, size.height * 0.6) & Size(size.width, size.height * 0.4),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.0),
            color.withValues(alpha: 0.55),
          ],
        ).createShader(Offset(0, size.height * 0.6) &
            Size(size.width, size.height * 0.4)),
    );
  }

  @override
  bool shouldRepaint(covariant _StripePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dense != dense;
}

/// Small inline placeholder, used in chips and previews.
class StripedSwatch extends StatelessWidget {
  final Color color;
  final double size;
  const StripedSwatch({super.key, required this.color, this.size = 28});

  @override
  Widget build(BuildContext ctx) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _StripePainter(color: color, dense: true)),
    );
  }
}

/// Deterministic stripe colors based on a string key.
Color stripeFor(String key) {
  final palette = MorphColors.stripeColors;
  int h = 0;
  for (final c in key.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return palette[h % palette.length];
}

double rotationFor(String key, {double max = 0.025}) {
  int h = 0;
  for (final c in key.codeUnits) {
    h = (h * 17 + c) & 0x7fffffff;
  }
  final r = (h % 1000) / 1000.0;
  return (r - 0.5) * 2 * max;
}

double _smudge(String key) {
  int h = 0;
  for (final c in key.codeUnits) {
    h = (h * 41 + c) & 0x7fffffff;
  }
  return (h % 1000) / 1000.0;
}

double smudgeFor(String key) => _smudge(key);
double smudgeRotation(String key, {double max = 0.06}) =>
    (smudgeFor(key) - 0.5) * 2 * max;
