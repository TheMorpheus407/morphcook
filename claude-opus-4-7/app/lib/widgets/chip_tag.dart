import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';

/// Ink-stamped chip used everywhere selections happen.
/// Selected = ink fill, unselected = paper background with ink outline.
class ChipTag extends StatelessWidget {
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;
  final IconData? icon;
  final String? counterRight;
  const ChipTag({
    super.key,
    required this.label,
    required this.selected,
    this.disabled = false,
    this.onTap,
    this.icon,
    this.counterRight,
  });

  @override
  Widget build(BuildContext context) {
    final fg = disabled
        ? MorphColors.inkFaint
        : selected
            ? MorphColors.paper
            : MorphColors.ink;
    final bg = disabled
        ? MorphColors.paperDeep.withValues(alpha: 0.6)
        : selected
            ? MorphColors.ink
            : MorphColors.paper;
    return Material(
      color: bg,
      child: InkWell(
        onTap: disabled ? null : onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
                color: disabled
                    ? MorphColors.inkFaint
                    : MorphColors.ink,
                width: 1),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label.toLowerCase(),
                style: MorphType.mono(size: 11, color: fg),
              ),
              if (counterRight != null) ...[
                const SizedBox(width: 8),
                Text(counterRight!,
                    style: MorphType.smallCaps(
                        size: 9, color: fg.withValues(alpha: 0.7))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
