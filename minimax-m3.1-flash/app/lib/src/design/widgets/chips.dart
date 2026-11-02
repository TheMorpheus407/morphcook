import 'package:flutter/material.dart';

import '../palette.dart';
import '../typography.dart';

/// A selectable chip used by the variant switcher on the dish page.
///
/// Three states:
///  * **selected** — filled with the accent colour,
///  * **available** — outlined, tappable,
///  * **disabled** — greyed out and not tappable, because no recipe exists
///    for this combination. Disabled chips stay visible on purpose: the user
///    should know the combination exists conceptually but is not written yet.
class VariantChip extends StatelessWidget {
  const VariantChip({
    required this.label,
    required this.selected,
    super.key,
    this.enabled = true,
    this.onTap,
    this.accent = MC.coral,
    this.note,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  final Color accent;

  /// Optional explanation shown beneath the chip row when disabled.
  final String? note;

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final Color border;
    final Color background;
    final Color foreground;
    final Color borderColor;

    if (!enabled) {
      background = MC.paperDeep.withValues(alpha: 0.55);
      foreground = MC.inkGhost;
      border = MC.inkGhost.withValues(alpha: 0.45);
      borderColor = border;
    } else if (selected) {
      background = accent;
      foreground = MC.card;
      border = accent;
      borderColor = accent;
    } else {
      background = Colors.transparent;
      foreground = MC.inkSoft;
      border = MC.rule;
      borderColor = MC.rule;
    }

    final chip = Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 9 : 12,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (selected) ...<Widget>[
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.only(right: 6),
              decoration: const BoxDecoration(
                color: MC.card,
                shape: BoxShape.circle,
              ),
            ),
          ],
          Text(
            label,
            style: Type.label(
              size: dense ? 9.5 : 10.5,
              color: foreground,
              weight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    final widget = Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: note == null ? label : '$label. $note',
      child: Opacity(
        opacity: enabled ? 1 : 0.75,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(2),
            splashColor: accent.withValues(alpha: 0.12),
            highlightColor: accent.withValues(alpha: 0.06),
            child: chip,
          ),
        ),
      ),
    );

    if (note == null) return widget;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        widget,
        const SizedBox(height: 6),
        Text(
          note!,
          style: Type.scriptSmall(size: 13, color: MC.inkFaint),
        ),
      ],
    );
  }
}

/// A tiny monospace tag, e.g. `vegan` or `≤30 min`.
class TagChip extends StatelessWidget {
  const TagChip(
    this.label, {
    super.key,
    this.color = MC.inkFaint,
    this.filled = false,
    this.background,
  });

  final String label;
  final Color color;
  final bool filled;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.12) : (background ?? Colors.transparent),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: Type.label(size: 9, color: color, letterSpacing: 0.9),
      ),
    );
  }
}

/// A row of [TagChip]s that wraps when it runs out of room.
class TagRow extends StatelessWidget {
  const TagRow(this.tags, {super.key, this.color = MC.inkFaint, this.spacing = 5});

  final List<String> tags;
  final Color color;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: <Widget>[
        for (final tag in tags) TagChip(tag, color: color),
      ],
    );
  }
}
