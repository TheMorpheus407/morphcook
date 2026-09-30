import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/theme/palette.dart';

/// Faint deterministic speckle that makes flat colour read as paper.
class PaperGrainPainter extends CustomPainter {
  const PaperGrainPainter({this.seed = 11, this.density = 0.0035, this.opacity = 0.07});

  final int seed;

  /// Specks per square pixel.
  final double density;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final random = math.Random(seed);
    final count = (size.width * size.height * density).round().clamp(120, 5000);
    final dark = Float32List(count * 2);
    final light = Float32List(count * 2);
    for (var i = 0; i < count; i++) {
      dark[i * 2] = random.nextDouble() * size.width;
      dark[i * 2 + 1] = random.nextDouble() * size.height;
      light[i * 2] = random.nextDouble() * size.width;
      light[i * 2 + 1] = random.nextDouble() * size.height;
    }
    canvas.drawRawPoints(
      ui.PointMode.points,
      dark,
      Paint()
        ..color = Palette.ink.withValues(alpha: opacity)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawRawPoints(
      ui.PointMode.points,
      light,
      Paint()
        ..color = Colors.white.withValues(alpha: opacity * 2.2)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    // A whisper of aging towards the corners.
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(rect.center, rect.longestSide * 0.75, [
          Colors.transparent,
          Palette.paperEdge.withValues(alpha: 0.22),
        ]),
    );
  }

  @override
  bool shouldRepaint(PaperGrainPainter oldDelegate) => false;
}

/// Paper-coloured page with grain. Every screen sits on one of these.
class PaperBackground extends StatelessWidget {
  const PaperBackground({super.key, required this.child, this.color = Palette.paper});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const IgnorePointer(
            child: RepaintBoundary(child: CustomPaint(painter: PaperGrainPainter())),
          ),
          child,
        ],
      ),
    );
  }
}

/// `Scaffold` on paper. Use it for every screen.
class PaperScaffold extends StatelessWidget {
  const PaperScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.paper,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: PaperBackground(child: body),
    );
  }
}

/// A dashed horizontal rule.
class DashedRule extends StatelessWidget {
  const DashedRule({super.key, this.color = Palette.rule, this.dash = 5, this.gap = 4, this.thickness = 1});

  final Color color;
  final double dash;
  final double gap;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: thickness,
      width: double.infinity,
      child: CustomPaint(
        painter: _DashedLinePainter(color: color, dash: dash, gap: gap, thickness: thickness),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color, required this.dash, required this.gap, required this.thickness});

  final Color color;
  final double dash;
  final double gap;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + dash, size.width), y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) =>
      old.color != color || old.dash != dash || old.gap != gap || old.thickness != thickness;
}

/// Newspaper double rule: one heavy line, one hairline.
class DoubleRule extends StatelessWidget {
  const DoubleRule({super.key, this.color = Palette.ink});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 2.4, color: color),
        const SizedBox(height: 3),
        Container(height: 0.8, color: color),
      ],
    );
  }
}

/// A rounded dashed outline, used on quiet buttons and disabled chips.
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({
    this.color = Palette.inkFaint,
    this.radius = 3,
    this.dash = 4,
    this.gap = 3,
    this.strokeWidth = 1,
  });

  final Color color;
  final double radius;
  final double dash;
  final double gap;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, math.min(distance + dash, metric.length)), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) => old.color != color || old.radius != radius;
}

/// A strip of washi tape holding a card to the page.
class TapeStrip extends StatelessWidget {
  const TapeStrip({super.key, this.color = Palette.mustard, this.width = 58, this.height = 18, this.angle = -0.05});

  final Color color;
  final double width;
  final double height;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: _TapePainter(color)),
      ),
    );
  }
}

class _TapePainter extends CustomPainter {
  const _TapePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, 0);
    const teeth = 5;
    final step = size.height / teeth;
    for (var i = 0; i < teeth; i++) {
      path.lineTo(i.isEven ? 2.2 : 0, step * (i + 0.5));
      path.lineTo(0, step * (i + 1));
    }
    path.lineTo(size.width, size.height);
    for (var i = teeth; i > 0; i--) {
      path.lineTo(i.isEven ? size.width - 2.2 : size.width, step * (i - 0.5));
      path.lineTo(size.width, step * (i - 1));
    }
    path.close();
    canvas.drawShadow(path, Palette.ink.withValues(alpha: 0.35), 1.5, false);
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.62));
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    for (var x = 6.0; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, 2), Offset(x - 3, size.height - 2), line);
    }
  }

  @override
  bool shouldRepaint(_TapePainter old) => old.color != color;
}
