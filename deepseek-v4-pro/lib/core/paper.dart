import 'dart:math';

import 'package:flutter/material.dart';

import 'palette.dart';

/// Deterministic paper-grain painter: a gentle field of speckles
/// over the warm paper background. Seeded, so it never flickers.
class PaperGrainPainter extends CustomPainter {
  PaperGrainPainter({this.seed = 7, this.opacity = 0.05});

  final int seed;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rand = Random(seed);
    final paint = Paint();
    const colors = [Color(0xFF8C7B5F), Color(0xFFB8A98C), Color(0xFF6E675C)];
    for (var i = 0; i < (size.width * size.height) / 900; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final r = 0.4 + rand.nextDouble() * 0.9;
      paint.color =
          colors[rand.nextInt(colors.length)].withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
    // a few soft larger blotches for depth
    for (var i = 0; i < 12; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final r = 6 + rand.nextDouble() * 22;
      paint.color =
          const Color(0xFFA3936F).withValues(alpha: opacity * 0.5);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PaperGrainPainter old) =>
      old.seed != seed || old.opacity != opacity;
}

/// The app's paper background: warm cream + grain.
class PaperBackground extends StatelessWidget {
  const PaperBackground({super.key, required this.child, this.seed = 7});

  final Widget child;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MC.paper,
      child: CustomPaint(
        painter: PaperGrainPainter(seed: seed),
        child: child,
      ),
    );
  }
}

/// Dashed horizontal rule — the tumblr cookbook divider.
class DashedRulePainter extends CustomPainter {
  const DashedRulePainter({this.color = MC.rule, this.dash = 6, this.gap = 5});

  final Color color;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(min(x + dash, size.width), 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant DashedRulePainter old) =>
      old.color != color || old.dash != dash || old.gap != gap;
}

class DashedRule extends StatelessWidget {
  const DashedRule({super.key, this.color = MC.rule, this.padding});

  final Color color;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final rule = CustomPaint(
      painter: DashedRulePainter(color: color),
      size: const Size(double.infinity, 1),
    );
    return padding == null ? rule : Padding(padding: padding!, child: rule);
  }
}

/// A centered ornament: "— & —" flanked by dashed rules.
class DashedOrnament extends StatelessWidget {
  const DashedOrnament({super.key, this.color = MC.rule});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CustomPaint(
            painter: DashedRulePainter(color: color),
            size: const Size(double.infinity, 1),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '&',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontStyle: FontStyle.italic,
              fontSize: 18,
              color: color.withValues(alpha: 0.9),
            ),
          ),
        ),
        Expanded(
          child: CustomPaint(
            painter: DashedRulePainter(color: color),
            size: const Size(double.infinity, 1),
          ),
        ),
      ],
    );
  }
}

/// Vertical dashed line (used in step timelines).
class VerticalDashedLine extends StatelessWidget {
  const VerticalDashedLine({super.key, this.color = MC.rule, this.length});

  final Color color;
  final double? length;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(1, length ?? 40),
      painter: _VerticalDashes(color),
    );
  }
}

class _VerticalDashes extends CustomPainter {
  _VerticalDashes(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, min(y + 6, size.height)), paint);
      y += 11;
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalDashes old) => old.color != color;
}

/// A polaroid-ish paper card with slight rotation.
class Polaroid extends StatelessWidget {
  const Polaroid({
    super.key,
    required this.child,
    this.rotation = 0,
    this.padding = const EdgeInsets.all(10),
    this.color = MC.card,
  });

  final Widget child;
  final double rotation;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation * pi / 180,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3A3428).withValues(alpha: 0.14),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
