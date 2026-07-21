import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The signature striped placeholder: diagonal stripes in the dish's stripe
/// color over paper, with a handwritten caption underneath.
class StripedImage extends StatelessWidget {
  final String stripeColor; // #RRGGBB
  final String caption;
  final double height;
  final bool showCaption;

  const StripedImage({
    super.key,
    required this.stripeColor,
    this.caption = '',
    this.height = 180,
    this.showCaption = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.stripe(stripeColor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.ink, width: 1.2),
          ),
          child: CustomPaint(
            painter: _StripePainter(color: color),
          ),
        ),
        if (showCaption && caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              caption,
              textAlign: TextAlign.center,
              style: AppText.handwritten(size: 18),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

class _StripePainter extends CustomPainter {
  final Color color;
  _StripePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = AppColors.paperDark);
    final stripe = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..strokeWidth = 10;
    const gap = 26.0;
    for (double x = -size.height; x < size.width + size.height; x += gap) {
      canvas.drawLine(
          Offset(x, size.height), Offset(x + size.height, 0), stripe);
    }
  }

  @override
  bool shouldRepaint(covariant _StripePainter oldDelegate) =>
      oldDelegate.color != color;
}
