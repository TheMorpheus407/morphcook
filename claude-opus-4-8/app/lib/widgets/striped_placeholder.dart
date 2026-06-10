import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The recipe "photo" that isn't a photo: diagonal stripes in the dish's colour
/// with a handwritten caption. Real photos are explicitly out for v1 — these
/// striped cards are part of the identity.
class StripedPlaceholder extends StatelessWidget {
  const StripedPlaceholder({
    super.key,
    required this.color,
    this.caption,
    this.height = 180,
    this.borderRadius = 4,
  });

  final Color color;
  final String? caption;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _StripePainter(color),
          child: caption == null
              ? null
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      color: AppColors.paper.withValues(alpha: 0.82),
                      child: Text(
                        caption!,
                        style: const TextStyle(
                          fontFamily: Fonts.hand,
                          fontSize: 22,
                          color: AppColors.ink,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  _StripePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = color.withValues(alpha: 0.16);
    canvas.drawRect(Offset.zero & size, bg);

    final stripe = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 9
      ..style = PaintingStyle.stroke;
    const gap = 22.0;
    for (double x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), stripe);
    }
  }

  @override
  bool shouldRepaint(covariant _StripePainter old) => old.color != color;
}

/// Parse a `#RRGGBB` string into a Color, with a muted fallback.
Color hexColor(String hex) {
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final value = int.tryParse(h, radix: 16);
  return value == null ? AppColors.clay : Color(value);
}
