import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

/// A handwritten margin note — short, slightly rotated Caveat-style ink.
/// Used sparingly: a single line on a polaroid, a footnote in cook mode,
/// the "every body." tagline.
class HandwrittenNote extends StatelessWidget {
  final String text;
  final double rotationTurns;
  final Color color;
  final double size;
  final TextAlign align;

  const HandwrittenNote({
    super.key,
    required this.text,
    this.rotationTurns = -0.01,
    this.color = MCColors.coral,
    this.size = 22,
    this.align = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotationTurns * 2 * 3.1415926,
      child: Text(
        text,
        textAlign: align,
        style: MCTypography.handwritten(size: size, color: color),
      ),
    );
  }
}
