import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Cream paper with a fine, deterministic grain and faint fibres.
class PaperBackground extends StatelessWidget {
  const PaperBackground({super.key, required this.child, this.color = MC.paper, this.dark = false});

  final Widget child;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: color),
        RepaintBoundary(
          child: IgnorePointer(
            child: CustomPaint(painter: _GrainPainter(dark: dark)),
          ),
        ),
        child,
      ],
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter({required this.dark});
  final bool dark;

  static final Map<String, ui.Picture> _cache = {};

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final key = '${size.width.round()}x${size.height.round()}|$dark';
    final picture = _cache[key] ??= _record(size);
    canvas.drawPicture(picture);
  }

  ui.Picture _record(Size size) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final rnd = Random(7);
    final speck = Paint()..strokeCap = StrokeCap.round;
    final count = (size.width * size.height / 90).clamp(0, 16000).toInt();
    final points = <Offset>[];
    final lights = <Offset>[];
    for (var i = 0; i < count; i++) {
      final o = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      (rnd.nextBool() ? points : lights).add(o);
    }
    speck
      ..color = (dark ? Colors.white : const Color(0xFF5A4A36)).withValues(alpha: dark ? 0.035 : 0.06)
      ..strokeWidth = 1.1;
    c.drawPoints(ui.PointMode.points, points, speck);
    speck
      ..color = (dark ? Colors.black : Colors.white).withValues(alpha: dark ? 0.12 : 0.35)
      ..strokeWidth = 1.3;
    c.drawPoints(ui.PointMode.points, lights, speck);
    // a few long, faint fibres
    final fibre = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = (dark ? Colors.white : const Color(0xFF8A7458)).withValues(alpha: dark ? 0.03 : 0.07);
    for (var i = 0; i < (size.height / 40).clamp(4, 60); i++) {
      final start = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      final path = Path()..moveTo(start.dx, start.dy);
      path.relativeQuadraticBezierTo(
        rnd.nextDouble() * 30 - 15,
        rnd.nextDouble() * 12 - 6,
        rnd.nextDouble() * 60 - 30,
        rnd.nextDouble() * 20 - 10,
      );
      c.drawPath(path, fibre);
    }
    return rec.endRecording();
  }

  @override
  bool shouldRepaint(covariant _GrainPainter old) => old.dark != dark;
}

/// A dashed horizontal rule, the cookbook's favourite divider.
class DashedRule extends StatelessWidget {
  const DashedRule({super.key, this.color = MC.rule, this.dash = 4, this.gap = 3, this.thickness = 1});

  final Color color;
  final double dash;
  final double gap;
  final double thickness;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: thickness,
    width: double.infinity,
    child: CustomPaint(painter: _DashPainter(color, dash, gap, thickness)),
  );
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color, this.dash, this.gap, this.thickness);
  final Color color;
  final double dash, gap, thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = thickness;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(min(x + dash, size.width), y), p);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => old.color != color || old.dash != dash || old.gap != gap;
}

/// Dashed rectangular outline (empty meal-plan slots, drop targets).
class DashedBorderBox extends StatelessWidget {
  const DashedBorderBox({super.key, required this.child, this.color = MC.rule, this.radius = 3});

  final Widget child;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _DashedRectPainter(color, radius), child: child);
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter(this.color, this.radius);
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect.deflate(0.5));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
        d += 7;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter old) => old.color != color;
}

/// Double rule used by the newspaper masthead.
class DoubleRule extends StatelessWidget {
  const DoubleRule({super.key, this.color = MC.ink});
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(height: 2, color: color),
      const SizedBox(height: 2),
      Container(height: 0.8, color: color),
    ],
  );
}
