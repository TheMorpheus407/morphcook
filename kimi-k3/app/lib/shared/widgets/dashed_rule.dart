import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Hand-drawn style dashed horizontal rule.
class DashedRule extends StatelessWidget {
  final double thickness;
  final Color color;
  const DashedRule(
      {super.key,
      this.thickness = 1,
      this.color = AppColors.inkSoft});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashPainter(thickness: thickness, color: color),
      size: const Size(double.infinity, 4),
    );
  }
}

class _DashPainter extends CustomPainter {
  final double thickness;
  final Color color;
  _DashPainter({required this.thickness, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = thickness;
    const dash = 6.0, gap = 5.0;
    double x = 0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter oldDelegate) => false;
}

/// A mono section label flanked by dashed rules:
/// `— for you ————————`
class SectionRule extends StatelessWidget {
  final String label;
  final Widget? trailing;
  const SectionRule({super.key, required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label.toLowerCase(), style: AppText.monoLabel()),
        const SizedBox(width: 10),
        const Expanded(child: DashedRule()),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}
