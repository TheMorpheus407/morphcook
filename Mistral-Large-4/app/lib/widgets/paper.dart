import 'dart:math' as math;

import 'package:flutter/material.dart' hide Typography;

import '../core/theme/palette.dart';
import '../core/theme/typography.dart';

/// Paper grain: faint ink dots on a 7px grid plus horizontal fibers every
/// 26px. Fixed, pointer-transparent, above content but below chrome.
class GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()
      ..color = Palette.inkFaint.withValues(alpha: 0.05)
      ..strokeWidth = 0.6;
    for (double x = 0; x < size.width; x += 7) {
      for (double y = 0; y < size.height; y += 7) {
        canvas.drawCircle(Offset(x, y), 0.6, dot);
      }
    }
    final fiber = Paint()
      ..color = Palette.inkFaint.withValues(alpha: 0.03)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 26) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), fiber);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Full-screen paper background with grain.
class PaperBackground extends StatelessWidget {
  final Widget child;

  const PaperBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Container(color: Palette.paper),
          Positioned.fill(
            child: CustomPaint(painter: GrainPainter(), child: const SizedBox.expand()),
          ),
          child,
        ],
      );
}

/// Scaffold with the paper look: grain, paper color, no app-bar chrome.
class PaperScaffold extends StatelessWidget {
  final Widget body;
  final Widget? bottomNavigationBar;
  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;

  const PaperScaffold({
    super.key,
    required this.body,
    this.bottomNavigationBar,
    this.appBar,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: backgroundColor ?? Colors.transparent,
        appBar: appBar,
        bottomNavigationBar: bottomNavigationBar,
        body: PaperBackground(child: body),
      );
}

/// Dashed hairline rule — the cookbook's dashed separator.
class DashedRule extends StatelessWidget {
  final EdgeInsets padding;

  const DashedRule({super.key, this.padding = const EdgeInsets.symmetric(vertical: 4)});

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: CustomPaint(
          painter: _DashedLinePainter(),
          size: const Size(double.infinity, 1),
        ),
      );
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Palette.line
      ..strokeWidth = 1;
    const dash = 5.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0.5), Offset(math.min(x + dash, size.width), 0.5), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Mono uppercase section label ("tonight's lead story").
class SectionLabel extends StatelessWidget {
  final String text;
  final Color? color;
  final EdgeInsets padding;

  const SectionLabel(this.text, {super.key, this.color, this.padding = const EdgeInsets.symmetric(vertical: 10)});

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Text(
          text.toUpperCase(),
          style: Typography.mono(10, weight: FontWeight.w700, letterSpacing: 2.4, color: color ?? Palette.inkSoft),
        ),
      );
}

/// Mono small label with wide tracking.
class MonoLabel extends StatelessWidget {
  final String text;
  final Color? color;
  final double size;

  const MonoLabel(this.text, {super.key, this.color, this.size = 10.5});

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Typography.mono(size, color: color ?? Palette.inkFaint));
}

/// Handwritten (Caveat) note.
class HandNote extends StatelessWidget {
  final String text;
  final double size;
  final Color? color;

  const HandNote(this.text, {super.key, this.size = 20, this.color});

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Typography.hand(size, color: color ?? Palette.inkSoft));
}
