import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/morph_theme.dart';

class PaperSurface extends StatelessWidget {
  const PaperSurface({
    required this.child,
    super.key,
    this.padding,
    this.color,
    this.grainOpacity = .13,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final double grainOpacity;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color ?? context.morph.paper,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Padding(padding: padding ?? EdgeInsets.zero, child: child),
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: CustomPaint(
                  painter: _PaperGrainPainter(
                    color: context.morph.ink,
                    opacity: grainOpacity,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaperGrainPainter extends CustomPainter {
  const _PaperGrainPainter({required this.color, required this.opacity});

  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final fleck = Paint()
      ..color = color.withValues(alpha: opacity * .18)
      ..strokeWidth = .55;
    final fibre = Paint()
      ..color = color.withValues(alpha: opacity * .1)
      ..strokeWidth = .45;

    final count = math.max(20, (size.width * size.height / 1150).round());
    for (var i = 0; i < count; i++) {
      final x = ((i * 47 + i * i * 13) % 997) / 997 * size.width;
      final y = ((i * 89 + i * i * 7) % 991) / 991 * size.height;
      canvas.drawCircle(Offset(x, y), i.isEven ? .55 : .3, fleck);
      if (i % 4 == 0) {
        canvas.drawLine(
          Offset(x - 2.5, y),
          Offset(x + 3.5, y + ((i % 3) - 1) * .4),
          fibre,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PaperGrainPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.opacity != opacity;
}
