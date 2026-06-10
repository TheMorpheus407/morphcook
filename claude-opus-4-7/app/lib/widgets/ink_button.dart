import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';

/// Primary action button — ink-on-paper or paper-on-ink, no rounded corners.
class InkButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool dense;
  final IconData? icon;
  const InkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = true,
    this.dense = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final bg = primary ? MorphColors.ink : MorphColors.paper;
    final fg = primary ? MorphColors.paper : MorphColors.ink;
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Material(
        color: bg,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: MorphColors.ink, width: 1.2),
            ),
            padding: EdgeInsets.symmetric(
                horizontal: dense ? 14 : 22, vertical: dense ? 8 : 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: 8),
                ],
                Text(
                  label.toUpperCase(),
                  style: MorphType.smallCaps(
                      size: dense ? 10 : 11, color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
