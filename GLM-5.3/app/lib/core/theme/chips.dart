import 'package:flutter/material.dart';

import 'app_fonts.dart';
import 'app_theme.dart';

/// A small mono tag chip (vegan · 40 min · ~640 kcal).
class TagChip extends StatelessWidget {
  const TagChip({super.key, this.label, this.color, this.selected = false});

  final String? label;
  final Color? color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (label == null) return const SizedBox.shrink();
    final c = color ?? AppColors.teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: selected ? c : AppColors.inkFaint),
        color: selected ? c.withOpacity(0.14) : Colors.transparent,
      ),
      child: Text(
        label!,
        style: AppFonts.mono(size: 10, color: selected ? c : AppColors.inkSoft),
      ),
    );
  }
}

/// A selectable pill used in the variant switcher rows, filter bars and
/// onboarding. Disabled pills render struck-through with a "not yet" note.
class SelectablePill extends StatelessWidget {
  const SelectablePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.note,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool enabled;
  final String? note;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = selected && enabled ? AppColors.teal : AppColors.inkSoft;
    final disabled = !enabled;
    return Tooltip(
      message: disabled ? (note ?? '') : '',
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: InkWell(
          onTap: disabled ? null : onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 4 : 6),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected && enabled ? AppColors.teal : AppColors.inkFaint,
                width: selected && enabled ? 1.6 : 1,
              ),
              color: selected && enabled
                  ? AppColors.teal.withOpacity(0.12)
                  : Colors.transparent,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppFonts.mono(
                    size: compact ? 11 : 12,
                    color: color,
                    weight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (selected && enabled) ...[
                  const SizedBox(width: 5),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
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

/// A quiet text button with mono type — used for contextual links
/// ("why?", "learn more", "view all").
class QuietLink extends StatelessWidget {
  const QuietLink({super.key, required this.label, required this.onTap, this.color});

  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          label,
          style: AppFonts.mono(
            size: 11,
            color: color ?? AppColors.coral,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Section headline for feed sections: mono eyebrow + italic serif title
/// (lowercase display, ampersands welcome).
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.action,
  });

  final String eyebrow;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: AppFonts.mono(size: 10, color: AppColors.coral, letterSpacing: 1.4),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: AppFonts.display(size: 24, color: AppColors.ink),
                ),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
