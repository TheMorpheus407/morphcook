import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A dashed hairline rule, optionally broken by a centred ampersand — the kind
/// of typographic flourish the prototype leans on.
class DashedRule extends StatelessWidget {
  const DashedRule({super.key, this.color, this.withAmpersand = false});
  final Color? color;
  final bool withAmpersand;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.inkFaint;
    final line = CustomPaint(painter: _DashedLinePainter(c), size: const Size(double.infinity, 1));
    if (!withAmpersand) return line;
    return Row(
      children: [
        Expanded(child: line),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('&', style: TextStyle(fontFamily: Fonts.display, fontStyle: FontStyle.italic, fontSize: 22, color: c)),
        ),
        Expanded(child: line),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 5.0, gap = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(min(x + dash, size.width), 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter old) => old.color != color;
}

/// A slightly-rotated, paper-white card with a soft shadow — the polaroid feel
/// the recipe cards use.
class PolaroidCard extends StatelessWidget {
  const PolaroidCard({
    super.key,
    required this.child,
    this.rotation = -0.012,
    this.padding = const EdgeInsets.all(10),
    this.onTap,
  });
  final Widget child;
  final double rotation;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: Material(
        color: const Color(0xFFFBF6EC),
        elevation: 0,
        borderRadius: BorderRadius.circular(3),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(3),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: AppColors.inkFaint.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.10),
                  blurRadius: 10,
                  offset: const Offset(2, 5),
                ),
              ],
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A mono-spaced, letter-spaced uppercase label — used for dimension names,
/// metadata, section kickers.
class MonoLabel extends StatelessWidget {
  const MonoLabel(this.text, {super.key, this.color, this.size = 11, this.spacing = 1.6});
  final String text;
  final Color? color;
  final double size;
  final double spacing;
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: Fonts.mono,
          fontSize: size,
          letterSpacing: spacing,
          color: color ?? AppColors.inkSoft,
          fontWeight: FontWeight.w500,
        ),
      );
}

/// A handwritten accent line (Caveat).
class HandNote extends StatelessWidget {
  const HandNote(this.text, {super.key, this.size = 20, this.color});
  final String text;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(fontFamily: Fonts.hand, fontSize: size, color: color ?? AppColors.clay, height: 1.05),
      );
}
