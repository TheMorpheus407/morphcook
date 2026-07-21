import 'package:flutter/material.dart';

import '../core/brand.dart';

class StripePlaceholder extends StatelessWidget {
  const StripePlaceholder({
    super.key,
    required this.color,
    required this.caption,
    this.height = 180,
    this.showStamp = true,
  });

  final Color color;
  final String caption;
  final double height;
  final bool showStamp;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: caption,
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _StripePainter(color)),
          if (showStamp)
            Center(
              child: Transform.rotate(
                angle: -.035,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  color: BrandColors.paper.withValues(alpha: .92),
                  child: Text(
                    caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Caveat',
                      fontSize: 22,
                      height: .95,
                      color: BrandColors.ink,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _StripePainter extends CustomPainter {
  const _StripePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = color.withValues(alpha: .22),
    );
    final stripe = Paint()
      ..color = color
      ..strokeWidth = 10;
    for (var x = -size.height; x < size.width + size.height; x += 24) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        stripe,
      );
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = BrandColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
  }

  @override
  bool shouldRepaint(covariant _StripePainter oldDelegate) =>
      color != oldDelegate.color;
}
