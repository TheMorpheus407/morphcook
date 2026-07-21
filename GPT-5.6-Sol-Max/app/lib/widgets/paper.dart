import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/brand.dart';

class PaperBackground extends StatelessWidget {
  const PaperBackground({
    super.key,
    required this.child,
    this.dark = false,
    this.color,
  });

  final Widget child;
  final bool dark;
  final Color? color;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: color ?? (dark ? BrandColors.cookInk : BrandColors.paper),
    child: CustomPaint(
      painter: PaperGrainPainter(dark: dark),
      child: child,
    ),
  );
}

class PaperGrainPainter extends CustomPainter {
  const PaperGrainPainter({this.dark = false});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(1978);
    final paint = Paint()
      ..color = (dark ? Colors.white : BrandColors.ink).withValues(
        alpha: dark ? .025 : .035,
      );
    final count = (size.width * size.height / 1250).round().clamp(50, 900);
    for (var i = 0; i < count; i++) {
      final point = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      canvas.drawCircle(point, random.nextDouble() * .7 + .2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PaperGrainPainter oldDelegate) =>
      dark != oldDelegate.dark;
}

class DashedRule extends StatelessWidget {
  const DashedRule({super.key, this.color = BrandColors.ink, this.height = 1});
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: height,
    child: CustomPaint(painter: _DashedPainter(color)),
  );
}

class _DashedPainter extends CustomPainter {
  const _DashedPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 6.0;
    const gap = 5.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(math.min(x + dash, size.width), 0),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPainter oldDelegate) =>
      color != oldDelegate.color;
}
