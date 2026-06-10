import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Thin dashed horizontal rule — the kind that lives at the top of every
/// recipe column. Quiet, tonal, page-furniture.
class DashedRule extends StatelessWidget {
  final double dashWidth;
  final double dashGap;
  final double thickness;
  final Color color;

  const DashedRule({
    super.key,
    this.dashWidth = 4,
    this.dashGap = 4,
    this.thickness = 0.8,
    this.color = MCColors.inkWhisper,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: thickness,
      child: CustomPaint(
        painter: _DashedPainter(
          dashWidth: dashWidth,
          dashGap: dashGap,
          thickness: thickness,
          color: color,
        ),
        size: Size.fromHeight(thickness),
      ),
    );
  }
}

class _DashedPainter extends CustomPainter {
  final double dashWidth;
  final double dashGap;
  final double thickness;
  final Color color;

  _DashedPainter({
    required this.dashWidth,
    required this.dashGap,
    required this.thickness,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPainter old) => false;
}
