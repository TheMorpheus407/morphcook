import 'package:flutter/material.dart' hide Typography;

import '../core/theme/palette.dart';
import '../core/theme/typography.dart';

/// The striped placeholder — the art direction for v1. Diagonal stripes in the
/// dish's color over a tinted base, with a paper caption band. Real photos are
/// explicitly out of scope; the stripes stay.
class StripedPlate extends StatelessWidget {
  final Color color;
  final String? caption;
  final double height;
  final double tiltDeg;
  final BorderRadius? borderRadius;

  const StripedPlate({
    super.key,
    required this.color,
    this.caption,
    this.height = 120,
    this.tiltDeg = 0,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final plate = ClipRRect(
      borderRadius: borderRadius ?? const BorderRadius.all(Radius.circular(4)),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _StripePainter(color),
          child: caption == null
              ? null
              : Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    color: Palette.paper.withValues(alpha: 0.93),
                    child: Text(
                      caption!,
                      style: Typography.body(15, italic: true),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
        ),
      ),
    );
    if (tiltDeg == 0) return plate;
    return Transform.rotate(angle: tiltDeg * 3.14159 / 180.0, child: plate);
  }
}

/// Stripe pattern: period 141px along a ~115° axis (CSS convention), bands of
/// the dish color at two opacities over a tinted base. `darkEvery 4`-ish
/// rhythm: two strong bands, three soft bands per period.
class _StripePainter extends CustomPainter {
  final Color color;

  _StripePainter(this.color);

  static const double period = 141;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = color.withValues(alpha: 0.13);
    canvas.drawRect(Offset.zero & size, base);

    // Band layout within one period: (width, color).
    final bands = <(double, Color)>[
      (26, Colors.transparent),
      (11, color.withValues(alpha: 0.80)),
      (15, Colors.transparent),
      (11, color.withValues(alpha: 0.47)),
      (15, Colors.transparent),
      (11, color.withValues(alpha: 0.47)),
      (15, Colors.transparent),
      (11, color.withValues(alpha: 0.47)),
      (15, Colors.transparent),
      (11, color.withValues(alpha: 0.80)),
    ];
    final colors = <Color>[];
    final stops = <double>[];
    var acc = 0.0;
    for (final (w, c) in bands) {
      colors.add(c);
      stops.add(acc / period);
      acc += w;
      colors.add(c);
      stops.add(acc / period);
    }
    // CSS 115deg: axis points right-and-slightly-down in screen coordinates.
    final gradient = LinearGradient(
      begin: const Alignment(-0.906, -0.423),
      end: const Alignment(0.906, 0.423),
      colors: colors,
      stops: stops,
      tileMode: TileMode.repeated,
    );
    final paint = Paint()..shader = gradient.createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _StripePainter oldDelegate) => oldDelegate.color != color;
}
