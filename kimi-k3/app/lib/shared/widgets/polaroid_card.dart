import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Polaroid-ish recipe card with a slight rotation and soft shadow.
class PolaroidCard extends StatelessWidget {
  final Widget child;
  final double rotation; // radians, e.g. -0.02
  final EdgeInsets padding;
  final VoidCallback? onTap;

  const PolaroidCard({
    super.key,
    required this.child,
    this.rotation = 0.0,
    this.padding = const EdgeInsets.all(10),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: Material(
        color: AppColors.polaroid,
        elevation: 3,
        shadowColor: AppColors.ink.withValues(alpha: 0.35),
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
