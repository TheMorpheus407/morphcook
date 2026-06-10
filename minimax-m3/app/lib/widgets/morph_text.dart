import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

/// Animates a text change with a brief highlight flash on the new content.
/// Used in the dish detail when the user switches a variant axis — ingredient
/// lines and method text fade-and-flash to draw the eye to what changed.
class MorphText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Color highlightColor;
  final Duration duration;
  final bool reduceMotion;
  final TextAlign? align;
  final int maxLines;

  const MorphText({
    super.key,
    required this.text,
    this.style,
    this.highlightColor = MCColors.coral,
    this.duration = const Duration(milliseconds: 320),
    this.reduceMotion = false,
    this.align,
    this.maxLines = 3,
  });

  @override
  Widget build(BuildContext context) {
    final s = style ?? MCTypography.body();
    final w = Text(text, style: s, textAlign: align, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    if (reduceMotion) return w;
    return Animate(
      key: ValueKey(text),
      effects: [
        FadeEffect(duration: duration, curve: Curves.easeOutCubic),
        TintEffect(color: highlightColor.withValues(alpha: 0.18), duration: duration * 1.4),
      ],
      child: w,
    );
  }
}
