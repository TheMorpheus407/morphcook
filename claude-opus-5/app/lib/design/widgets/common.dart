import 'package:flutter/material.dart';

import '../motion.dart';
import '../palette.dart';
import '../typography.dart';
import 'paper.dart';

/// Small caps eyebrow above a block of content.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color, this.trailing});

  final String text;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final style = MorphType.eyebrow(color ?? context.colors.inkFaint);
    if (trailing == null) return Text(text.toUpperCase(), style: style);
    return Row(
      children: [
        Expanded(child: Text(text.toUpperCase(), style: style)),
        trailing!,
      ],
    );
  }
}

/// A margin note in Caveat, indented like a hand-written aside.
class HandNote extends StatelessWidget {
  const HandNote(
    this.text, {
    super.key,
    this.color,
    this.size = 21,
    this.align,
  });

  final String text;
  final Color? color;
  final double size;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      textAlign: align,
      style: MorphType.hand(color ?? context.colors.accent, size: size),
    );
  }
}

/// Section header with a rule that runs into the label.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.subtitle});

  final String title;
  final Widget? action;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                title.toLowerCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.displaySmall,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 8),
                  child: DashedRule(color: colors.edge),
                ),
              ),
            ),
            if (action != null) ...[const SizedBox(width: 10), action!],
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

/// The app's only "button-ish" chip. Used for tags, filters and the variant
/// switcher, with three states: idle, selected, unavailable.
class InkChip extends StatelessWidget {
  const InkChip({
    super.key,
    required this.label,
    this.selected = false,
    this.enabled = true,
    this.onTap,
    this.leading,
    this.trailing,
    this.tone,
    this.dense = false,
    this.tooltip,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;
  final Color? tone;
  final bool dense;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = tone ?? colors.accent;
    final background = selected
        ? accent
        : enabled
        ? colors.paperRaised
        : colors.paperSunk;
    final foreground = selected
        ? colors.paper
        : enabled
        ? colors.ink
        : colors.inkFaint;

    final chip = AnimatedContainer(
      duration: Motion.duration(context, MorphDurations.quick),
      curve: Curves2.standard,
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 9 : 12,
        vertical: dense ? 5 : 8,
      ),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(
          color: selected ? accent : colors.edge,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            IconTheme(
              data: IconThemeData(color: foreground, size: dense ? 12 : 14),
              child: leading!,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  MorphType.numeric(
                    foreground,
                    size: dense ? 11 : 12,
                    weight: selected ? FontWeight.w700 : FontWeight.w500,
                  ).copyWith(
                    decoration: enabled ? null : TextDecoration.lineThrough,
                    decorationColor: colors.inkFaint,
                  ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            IconTheme(
              data: IconThemeData(color: foreground, size: dense ? 12 : 14),
              child: trailing!,
            ),
          ],
        ],
      ),
    );

    final tappable = Semantics(
      button: onTap != null,
      selected: selected,
      enabled: enabled,
      label: label,
      child: InkWell(onTap: enabled ? onTap : null, child: chip),
    );

    if (tooltip == null) return tappable;
    return Tooltip(message: tooltip!, child: tappable);
  }
}

/// Empty states are part of the voice, not an afterthought.
class EmptyNote extends StatelessWidget {
  const EmptyNote({
    super.key,
    required this.headline,
    required this.body,
    this.hand,
    this.action,
    this.icon,
  });

  final String headline;
  final String body;
  final String? hand;
  final Widget? action;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 26, color: colors.inkFaint),
                const SizedBox(height: 16),
              ],
              Text(
                headline.toLowerCase(),
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall,
              ),
              const SizedBox(height: 10),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              if (hand != null) ...[
                const SizedBox(height: 14),
                HandNote(hand!, align: TextAlign.center),
              ],
              if (action != null) ...[const SizedBox(height: 22), action!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton row shown while a page is being fetched. Deliberately quiet — a
/// shimmering pulse would fight everything else in this design.
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({super.key, this.width, this.height = 12});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: context.colors.paperSunk,
      border: Border.all(color: context.colors.edge.withValues(alpha: 0.4)),
    ),
  );
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.height = 120});

  final double height;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonLine(width: 84, height: height * 0.6),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonLine(width: 160, height: 16),
              const SizedBox(height: 10),
              SkeletonLine(width: double.infinity, height: 10),
              const SizedBox(height: 6),
              const SkeletonLine(width: 120, height: 10),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Footer for a paginated list: spinner, "that's everything", or the number of
/// items dropped to honour the render cap.
class PaginationFooter extends StatelessWidget {
  const PaginationFooter({
    super.key,
    required this.loading,
    required this.hasMore,
    required this.endLabel,
    this.droppedFromHead = 0,
    this.droppedLabel,
    this.error,
    this.onRetry,
    this.retryLabel = 'Retry',
  });

  final bool loading;
  final bool hasMore;
  final String endLabel;
  final int droppedFromHead;
  final String? droppedLabel;
  final Object? error;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Column(
          children: [
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      );
    }
    if (loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: colors.inkFaint,
            ),
          ),
        ),
      );
    }
    if (hasMore) return const SizedBox(height: 40);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Column(
        children: [
          DashedRule(
            label: Text('✻', style: TextStyle(color: colors.inkFaint)),
          ),
          const SizedBox(height: 8),
          Text(endLabel, style: Theme.of(context).textTheme.labelSmall),
          if (droppedFromHead > 0 && droppedLabel != null) ...[
            const SizedBox(height: 4),
            Text(droppedLabel!, style: Theme.of(context).textTheme.labelSmall),
          ],
        ],
      ),
    );
  }
}

/// Two numbers side by side, mono, with a hairline between them.
class StatPair extends StatelessWidget {
  const StatPair({
    super.key,
    required this.label,
    required this.value,
    this.tone,
  });

  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: MorphType.numeric(
            tone ?? colors.ink,
            size: 20,
            weight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(label.toUpperCase(), style: MorphType.eyebrow(colors.inkFaint)),
      ],
    );
  }
}
