import 'package:flutter/material.dart' hide Typography;

import '../core/theme/palette.dart';
import '../core/theme/typography.dart';
import 'stripe_plate.dart';

/// Polaroid-ish recipe card: paper frame, striped plate, handwritten name,
/// slight rotation. Alternating tilt, straightens on hover/press.
class PolaroidCard extends StatelessWidget {
  final Color stripeColor;
  final String? caption;
  final String name;
  final String subtitle;
  final String meta;
  final String? tag;
  final Color? tagColor;
  final VoidCallback? onTap;
  final int index;

  const PolaroidCard({
    super.key,
    required this.stripeColor,
    this.caption,
    required this.name,
    required this.subtitle,
    required this.meta,
    this.tag,
    this.tagColor,
    this.onTap,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final tilt = index.isEven ? -0.7 : 0.8;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.identity()..rotateZ(tilt * 3.14159 / 180.0),
        decoration: BoxDecoration(
          color: Palette.paper,
          border: Border.all(color: Palette.line),
          borderRadius: const BorderRadius.all(Radius.circular(2)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A2B2620),
              blurRadius: 10,
              offset: Offset(2, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StripedPlate(color: stripeColor, height: 110),
            const SizedBox(height: 8),
            Text(name, style: Typography.hand(21), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Typography.body(13, italic: true),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(meta, style: Typography.mono(10)),
            if (tag != null) ...[
              const SizedBox(height: 8),
              _TagChip(tag!, tagColor ?? stripeColor),
            ],
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String text;
  final Color color;

  const _TagChip(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 1.2),
        ),
        child: Text(
          text.toUpperCase(),
          style: Typography.mono(9, weight: FontWeight.w700, letterSpacing: 1.6, color: color),
        ),
      );
}
