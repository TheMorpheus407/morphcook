import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';

class DashedRule extends StatelessWidget {
  final Color? color;
  final double height;
  final double dashWidth;
  final double dashSpace;
  final double thickness;
  const DashedRule({
    super.key,
    this.color,
    this.height = 14,
    this.dashWidth = 4,
    this.dashSpace = 3,
    this.thickness = 1,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _DashedRulePainter(
          color: color ?? MorphColors.inkFaint,
          dashWidth: dashWidth,
          dashSpace: dashSpace,
          thickness: thickness,
        ),
        size: const Size(double.infinity, double.infinity),
      ),
    );
  }
}

class _DashedRulePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;
  final double thickness;
  _DashedRulePainter({
    required this.color,
    required this.dashWidth,
    required this.dashSpace,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;
    double x = 0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dashWidth, y), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRulePainter o) =>
      o.color != color ||
      o.dashWidth != dashWidth ||
      o.dashSpace != dashSpace ||
      o.thickness != thickness;
}

/// Decorated section heading: small caps, dashed rule underneath, optional
/// handwritten Caveat caption.
class SectionHeader extends StatelessWidget {
  final String label;
  final String? caption;
  final EdgeInsets padding;
  const SectionHeader({
    super.key,
    required this.label,
    this.caption,
    this.padding = const EdgeInsets.fromLTRB(20, 28, 20, 10),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(label.toUpperCase(), style: MorphType.smallCaps(size: 11)),
              const SizedBox(width: 10),
              if (caption != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(caption!,
                      style: MorphType.hand(
                          size: 19, color: MorphColors.coral)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const DashedRule(),
        ],
      ),
    );
  }
}

/// Ampersand-style separator (paper centerpiece).
class AmpersandDivider extends StatelessWidget {
  final String glyph;
  const AmpersandDivider({super.key, this.glyph = '&'});

  @override
  Widget build(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          const Expanded(child: DashedRule()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(glyph,
                style: MorphType.headline(size: 28)
                    .copyWith(color: MorphColors.inkMuted)),
          ),
          const Expanded(child: DashedRule()),
        ],
      ),
    );
  }
}
