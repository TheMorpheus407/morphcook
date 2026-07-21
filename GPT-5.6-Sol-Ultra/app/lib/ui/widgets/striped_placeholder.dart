import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/morph_theme.dart';

class StripedPlaceholder extends StatelessWidget {
  const StripedPlaceholder({
    required this.caption,
    super.key,
    this.color,
    this.height = 190,
    this.aspectRatio,
    this.semanticLabel,
    this.icon,
  });

  final String caption;
  final Color? color;
  final double height;
  final double? aspectRatio;
  final String? semanticLabel;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.morph;
    final body = SizedBox(
      height: aspectRatio == null ? height : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _StripePainter(
              stripe: color ?? palette.teal,
              ground: palette.paperDeep,
            ),
          ),
          Center(
            child: Transform.rotate(
              angle: -.035,
              child: Icon(
                icon ?? Icons.restaurant_menu_rounded,
                size: 48,
                color: palette.paper.withValues(alpha: .92),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              color: palette.ink.withValues(alpha: .86),
              child: Text(
                caption.toLowerCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.paper,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      image: true,
      label: semanticLabel ?? caption,
      child: ExcludeSemantics(
        child: aspectRatio == null
            ? body
            : AspectRatio(aspectRatio: aspectRatio!, child: body),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  const _StripePainter({required this.stripe, required this.ground});

  final Color stripe;
  final Color ground;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ground);
    final paint = Paint()
      ..color = stripe.withValues(alpha: .82)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.square;
    const gap = 23.0;
    for (var x = -size.height; x < size.width + size.height; x += gap) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
    final wash = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: .12),
          Colors.black.withValues(alpha: .07),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wash);

    final scratch = Paint()
      ..color = ground.withValues(alpha: .22)
      ..strokeWidth = .7;
    for (var i = 1; i < 17; i++) {
      final y = math.sin(i * 2.1) * 2 + size.height * i / 18;
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 1.2), scratch);
    }
  }

  @override
  bool shouldRepaint(covariant _StripePainter oldDelegate) =>
      oldDelegate.stripe != stripe || oldDelegate.ground != ground;
}
