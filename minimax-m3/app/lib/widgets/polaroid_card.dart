import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';
import 'striped_placeholder.dart';

/// A polaroid-style card with a striped placeholder on top, a title in italic
/// Playfair, an optional handwritten Caveat caption, and a faint typed
/// eyebrow above. Slight random rotation gives the wall-of-photos vibe.
class PolaroidCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? handwritten;
  final String? eyebrow;
  final Color stripeColor;
  final String? placeholderCaption;
  final double rotationTurns;
  final VoidCallback? onTap;
  final double width;
  final EdgeInsets margin;
  final bool compact;

  const PolaroidCard({
    super.key,
    required this.title,
    this.subtitle,
    this.handwritten,
    this.eyebrow,
    required this.stripeColor,
    this.placeholderCaption,
    this.rotationTurns = 0,
    this.onTap,
    this.width = 220,
    this.margin = const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotationTurns * 2 * math.pi,
      child: Padding(
        padding: margin,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(2),
          child: Container(
            width: width,
            padding: EdgeInsets.fromLTRB(12, 12, 12, compact ? 14 : 22),
            decoration: BoxDecoration(
              color: MCColors.polaroid,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: MCColors.polaroidShadow,
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(color: MCColors.paperDark, width: 0.6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StripedPlaceholder(
                  stripeColor: stripeColor,
                  caption: placeholderCaption,
                  aspectRatio: 4 / 3,
                ),
                const SizedBox(height: 14),
                if (eyebrow != null) ...[
                  Text(eyebrow!.toUpperCase(), style: MCTypography.eyebrow()),
                  const SizedBox(height: 6),
                ],
                Text(
                  title,
                  style: MCTypography.title(size: compact ? 17 : 20),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: MCTypography.italic(size: 13.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (handwritten != null) ...[
                  const SizedBox(height: 10),
                  Transform.rotate(
                    angle: -0.02,
                    child: Text(
                      handwritten!,
                      style: MCTypography.handwritten(size: 18),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
