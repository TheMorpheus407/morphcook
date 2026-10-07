import 'package:flutter/material.dart' hide Typography;

import '../core/theme/palette.dart';
import '../core/theme/typography.dart';

/// Mono chip for filters and variant options. Sharp corners, hairline border.
class PaperChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const PaperChip({
    super.key,
    required this.label,
    this.selected = false,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg;
    final Color border;
    final Color bg;
    if (!enabled) {
      fg = Palette.inkFaint.withValues(alpha: 0.6);
      border = Palette.line;
      bg = Palette.paper;
    } else if (selected) {
      fg = Palette.paper;
      border = Palette.teal;
      bg = Palette.teal;
    } else {
      fg = Palette.inkSoft;
      border = Palette.line;
      bg = Palette.paper;
    }
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: 1.3),
        ),
        child: Text(label, style: Typography.mono(10.5, letterSpacing: 1.2, color: fg)),
      ),
    );
  }
}

/// Ink button — the cookbook's primary action. Variants: solid ink, ghost
/// (outlined), sage.
class InkButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool outlined;
  final bool sage;
  final IconData? icon;

  const InkButton(
    this.label, {
    super.key,
    this.onTap,
    this.outlined = false,
    this.sage = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (sage) {
      bg = Palette.sage;
      fg = Palette.paper;
    } else if (outlined) {
      bg = Palette.paper;
      fg = Palette.ink;
    } else {
      bg = Palette.ink;
      fg = Palette.paper;
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          border: outlined ? Border.all(color: Palette.ink, width: 1.4) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 8),
            ],
            Text(
              label.toUpperCase(),
              style: Typography.mono(11, weight: FontWeight.w700, letterSpacing: 1.8, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mono pill: "time: 50 min" meta chips on the dish page.
class MetaPill extends StatelessWidget {
  final String label;
  final String value;

  const MetaPill({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(border: Border.all(color: Palette.line)),
        child: Text(
          '$label: $value',
          style: Typography.mono(9.5, color: Palette.inkSoft),
        ),
      );
}
