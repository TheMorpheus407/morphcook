import 'package:flutter/material.dart';

import 'motion.dart';
import 'palette.dart';
import 'paper.dart';
import 'typography.dart';

/// Small lowercase mono label, e.g. "— tonight —" or "vol. i".
class MonoLabel extends StatelessWidget {
  const MonoLabel(this.text, {super.key, this.color = Palette.inkFaint, this.size = 11, this.align = TextAlign.start});
  final String text;
  final Color color;
  final double size;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => Text(text.toLowerCase(), textAlign: align, style: AppText.monoLabel(color: color, size: size));
}

/// Handwritten aside in the margin.
class HandNote extends StatelessWidget {
  const HandNote(this.text, {super.key, this.color = Palette.inkSoft, this.size = 20, this.align = TextAlign.start, this.maxLines});
  final String text;
  final Color color;
  final double size;
  final TextAlign align;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: align,
        maxLines: maxLines,
        overflow: maxLines == null ? TextOverflow.visible : TextOverflow.ellipsis,
        style: AppText.hand(color: color, size: size),
      );
}

Widget? _kickerLabel(String? kicker) => kicker == null
    ? null
    : Padding(padding: const EdgeInsets.only(bottom: 4), child: MonoLabel('— $kicker —'));

/// "— section —" label + italic Playfair title, with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.kicker, this.trailing, this.padding = const EdgeInsets.fromLTRB(20, 26, 20, 12)});
  final String title;
  final String? kicker;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ?_kickerLabel(kicker),
                  Text(title.toLowerCase(), style: AppText.title(size: 24, italic: true)),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      );
}

/// A chip that looks stamped rather than pilled.
class PaperChip extends StatelessWidget {
  const PaperChip({
    super.key,
    required this.label,
    this.selected = false,
    this.disabled = false,
    this.muted = false,
    this.onTap,
    this.leading,
    this.trailing,
    this.tone,
  });

  final String label;
  final bool selected;
  final bool disabled;

  /// Exists but the profile frowns on it: drawn with a dotted outline.
  final bool muted;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? Palette.paper
        : disabled
            ? Palette.inkFaint.withValues(alpha: 0.7)
            : Palette.ink;
    final bg = selected ? (tone ?? Palette.ink) : Palette.paperLight.withValues(alpha: disabled ? 0.4 : 1);
    final border = selected
        ? (tone ?? Palette.ink)
        : disabled
            ? Palette.rule
            : muted
                ? Palette.mustard
                : Palette.ruleStrong;
    final child = AnimatedContainer(
      duration: Motion.duration(context, const Duration(milliseconds: 160)),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border, width: muted && !selected ? 1.2 : 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Text(
            label.toLowerCase(),
            style: AppText.mono(color: fg, size: 12, weight: selected ? FontWeight.w600 : FontWeight.w500)
                .copyWith(decoration: disabled ? TextDecoration.lineThrough : null, decorationColor: Palette.inkFaint),
          ),
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
        ],
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      enabled: !disabled,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: child,
      ),
    );
  }
}

enum PaperButtonKind { primary, secondary, quiet }

/// Buttons: ink-filled primary, outlined secondary, text-only quiet.
class PaperButton extends StatelessWidget {
  const PaperButton({
    super.key,
    required this.label,
    this.onPressed,
    this.kind = PaperButtonKind.primary,
    this.icon,
    this.expand = false,
    this.dark = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final PaperButtonKind kind;
  final IconData? icon;
  final bool expand;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final ink = dark ? Palette.nightInk : Palette.ink;
    final paper = dark ? Palette.night : Palette.paper;
    final Color fg;
    final Color bg;
    final Color border;
    switch (kind) {
      case PaperButtonKind.primary:
        fg = paper;
        bg = enabled ? ink : ink.withValues(alpha: 0.35);
        border = bg;
      case PaperButtonKind.secondary:
        fg = enabled ? ink : ink.withValues(alpha: 0.4);
        bg = Colors.transparent;
        border = enabled ? ink : ink.withValues(alpha: 0.3);
      case PaperButtonKind.quiet:
        fg = enabled ? ink : ink.withValues(alpha: 0.4);
        bg = Colors.transparent;
        border = Colors.transparent;
    }
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 8)],
        Text(label.toLowerCase(), style: AppText.mono(color: fg, size: 13, weight: FontWeight.w600)),
      ],
    );
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: border)),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: kind == PaperButtonKind.quiet ? 8 : 16, vertical: 12),
          child: content,
        ),
      ),
    );
  }
}

/// A calm empty state with a handwritten note and an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.note, this.action, this.icon = Icons.local_florist_outlined});
  final String title;
  final String note;
  final Widget? action;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: Palette.inkFaint),
              const SizedBox(height: 14),
              Text(title.toLowerCase(), textAlign: TextAlign.center, style: AppText.title(size: 22, italic: true)),
              const SizedBox(height: 8),
              HandNote(note, align: TextAlign.center, size: 19),
              if (action != null) ...[const SizedBox(height: 18), action!],
            ],
          ),
        ),
      );
}

/// Skeleton block for loading states; a gentle sheen unless motion is reduced.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.height = 16, this.width, this.radius = 3});
  final double height;
  final double? width;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: Color.lerp(Palette.paperDeep, Palette.rule, _c.value * 0.6),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      );
}

/// A boxed paragraph with a mono kicker — for notes like the halal/kosher
/// wording, or "why don't I see…".
class PaperNote extends StatelessWidget {
  const PaperNote({super.key, required this.text, this.kicker, this.tone = Palette.mustard, this.trailing});
  final String text;
  final String? kicker;
  final Color tone;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Palette.paperLight.withValues(alpha: 0.7),
          border: Border(left: BorderSide(color: tone, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (kicker != null) ...[MonoLabel(kicker!), const SizedBox(height: 4)],
            Text(text, style: AppText.body(size: 14, color: Palette.inkSoft)),
            if (trailing != null) ...[const SizedBox(height: 8), trailing!],
          ],
        ),
      );
}

/// Row of small metadata bits separated by middots: "easy · 30 min · ~520 kcal".
class MetaLine extends StatelessWidget {
  const MetaLine(this.parts, {super.key, this.color = Palette.inkFaint, this.size = 11.5});
  final List<String> parts;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
        parts.where((p) => p.isNotEmpty).join(' · ').toLowerCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.mono(color: color, size: size),
      );
}

/// A horizontal rule with a centred ampersand or glyph, newspaper style.
class OrnamentRule extends StatelessWidget {
  const OrnamentRule({super.key, this.glyph = '&', this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 18)});
  final String glyph;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Row(
          children: [
            const Expanded(child: DashedRule()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(glyph, style: AppText.display(size: 20, color: Palette.inkFaint)),
            ),
            const Expanded(child: DashedRule()),
          ],
        ),
      );
}
