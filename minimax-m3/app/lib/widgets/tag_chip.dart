import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

/// A small label chip used for variant labels, attributes, dietary tags. Two
/// styles: ghost (default) and solid (selected).
class TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? accent;
  final bool disabled;

  const TagChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.accent,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? MCColors.ink;
    final fg = disabled
        ? MCColors.inkWhisper
        : (selected ? MCColors.cream : color);
    final bg = disabled
        ? MCColors.paper
        : (selected ? color : MCColors.polaroid);
    final border = disabled
        ? MCColors.paperDark
        : (selected ? color : MCColors.paperDark);
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: border, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label.toLowerCase(),
              style: MCTypography.body(size: 12.5, color: fg, weight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class AmpersandDivider extends StatelessWidget {
  const AmpersandDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          '&',
          style: MCTypography.italic(size: 28, color: MCColors.inkFaded),
        ),
      ),
    );
  }
}
