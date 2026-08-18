import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_fonts.dart';
import 'app_theme.dart';

/// A deterministic small rotation derived from a string id — each polaroid
/// leans a little differently, like photos on a kitchen table.
double polaroidTilt(String id) {
  var hash = 0;
  for (final code in id.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  final unit = (hash % 1000) / 1000; // 0..1
  return (unit - 0.5) * 0.06; // ± ~1.7°
}

/// The polaroid-ish recipe card: paper card, slight rotation, striped
/// photo placeholder, handwritten-ish caption strip.
class PolaroidCard extends StatelessWidget {
  const PolaroidCard({
    super.key,
    required this.id,
    required this.stripeColor,
    required this.caption,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final String id;
  final Color stripeColor;
  final String caption;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: polaroidTilt(id),
      child: Material(
        color: AppColors.paperCard,
        elevation: 0.5,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.ink.withOpacity(0.35)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withOpacity(0.10),
                  blurRadius: 6,
                  offset: const Offset(2, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StripedThumb(color: stripeColor, caption: caption, seed: id.hashCode),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.display(size: 17, color: AppColors.ink),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.mono(size: 10, color: AppColors.inkSoft),
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small striped thumbnail used inside polaroids.
class StripedThumb extends StatelessWidget {
  const StripedThumb({super.key, required this.color, required this.caption, required this.seed});

  final Color color;
  final String caption;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.25,
      child: CustomPaint(
        painter: PolaroidStripes(color: color, seed: seed),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class PolaroidStripes extends CustomPainter {
  PolaroidStripes({required this.color, required this.seed});

  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = AppColors.paper);
    final paint = Paint()..color = color.withOpacity(0.5);
    const step = 16.0;
    final diagonal = size.width + size.height;
    for (var d = -size.height; d < diagonal; d += step) {
      final path = Path()
        ..moveTo(d, 0)
        ..lineTo(d + 7, 0)
        ..lineTo(d + 7 + size.height, size.height)
        ..lineTo(d + size.height, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }
    final rng = math.Random(seed);
    final dots = Paint()..color = AppColors.ink.withOpacity(0.07);
    for (var i = 0; i < 24; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        0.7,
        dots,
      );
    }
    canvas.drawRect(
      rect.deflate(2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = AppColors.ink.withOpacity(0.5),
    );
  }

  @override
  bool shouldRepaint(covariant PolaroidStripes oldDelegate) =>
      oldDelegate.color != color || oldDelegate.seed != seed;
}
