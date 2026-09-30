import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'paper.dart';

/// Small typewriter label, lower-case, spaced.
class MonoLabel extends StatelessWidget {
  const MonoLabel(this.text, {super.key, this.color = MC.inkSoft, this.size = 11, this.weight = FontWeight.w400});
  final String text;
  final Color color;
  final double size;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) => Text(
    text.toLowerCase(),
    style: MT.mono(size, color: color, weight: weight),
  );
}

/// A section heading in lowercase display italic; an ampersand in the title
/// is set larger in coral, the way old cookbooks loved to.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.size = 26, this.padding});
  final String title;
  final Widget? trailing;
  final double size;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final parts = title.split('&');
    final spans = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      spans.add(TextSpan(text: parts[i]));
      if (i < parts.length - 1) {
        spans.add(
          TextSpan(
            text: '&',
            style: MT.display(size * 1.25, color: MC.coral),
          ),
        );
      }
    }
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(20, 28, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text.rich(TextSpan(children: spans), style: MT.display(size)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 8),
          const DashedRule(),
        ],
      ),
    );
  }
}

/// Handwritten margin note, slightly tilted.
class HandNote extends StatelessWidget {
  const HandNote(this.text, {super.key, this.size = 21, this.color = MC.coralDeep, this.angle = -0.025});
  final String text;
  final double size;
  final Color color;
  final double angle;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle,
    child: Text(text, style: MT.hand(size, color: color)),
  );
}

enum ChipTone { normal, selected, disabled }

/// Outlined chip; selected = inked, disabled = faded with a strike.
class InkChip extends StatelessWidget {
  const InkChip({
    super.key,
    required this.label,
    this.selected = false,
    this.enabled = true,
    this.onTap,
    this.icon,
    this.dense = false,
    this.semanticsHint,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool dense;
  final String? semanticsHint;

  @override
  Widget build(BuildContext context) {
    final fg = !enabled ? MC.inkFaint : (selected ? MC.card : MC.ink);
    final bg = selected ? MC.ink : (enabled ? MC.card : Colors.transparent);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      hint: semanticsHint,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(40),
          side: BorderSide(color: enabled ? (selected ? MC.ink : MC.rule) : MC.rule.withValues(alpha: 0.6)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 14, vertical: dense ? 5 : 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 5)],
                if (selected && icon == null) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(color: MC.coral, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: MT
                      .mono(dense ? 11 : 12, color: fg)
                      .copyWith(decoration: enabled ? null : TextDecoration.lineThrough, decorationColor: MC.inkFaint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Primary button: ink on paper, mono caps-free label.
class InkButton extends StatelessWidget {
  const InkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = MC.ink,
    this.expand = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final btn = FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: MC.card,
        disabledBackgroundColor: MC.rule,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
          Flexible(
            child: Text(
              label,
              style: MT.mono(13, color: MC.card, weight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// Secondary button: outlined, transparent.
class PaperButton extends StatelessWidget {
  const PaperButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = MC.ink,
    this.dense = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: onPressed == null ? MC.rule : color.withValues(alpha: 0.7)),
      padding: EdgeInsets.symmetric(horizontal: dense ? 12 : 16, vertical: dense ? 8 : 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: dense ? 15 : 17), const SizedBox(width: 6)],
        Flexible(
          child: Text(label, style: MT.mono(dense ? 11 : 12, color: onPressed == null ? MC.inkFaint : color)),
        ),
      ],
    ),
  );
}

/// Underlined inline link, used for contextual help ("why these recipes?").
class TextLink extends StatelessWidget {
  const TextLink(this.label, {super.key, required this.onTap, this.color = MC.tealDeep, this.size = 12, this.icon});
  final String label;
  final VoidCallback onTap;
  final Color color;
  final double size;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? Icons.help_outline, size: size + 2, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: MT
                  .mono(size, color: color)
                  .copyWith(
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                    decorationColor: color,
                  ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Calm empty state with a big italic ampersand.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.body, this.action, this.glyph = '&'});
  final String title;
  final String body;
  final Widget? action;
  final String glyph;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(glyph, style: MT.display(84, color: MC.coral.withValues(alpha: 0.55))),
        const SizedBox(height: 4),
        Text(title, textAlign: TextAlign.center, style: MT.display(24)),
        const SizedBox(height: 10),
        Text(
          body,
          textAlign: TextAlign.center,
          style: MT.serif(15, color: MC.inkSoft),
        ),
        if (action != null) ...[const SizedBox(height: 18), action!],
      ],
    ),
  );
}

/// Pulsing paper block for skeleton loaders (static under reduced motion).
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.height = 16, this.width, this.radius = 2});
  final double height;
  final double? width;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotionOf(context)) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
    return _buildBox();
  }

  Widget _buildBox() => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: Color.lerp(MC.paperDeep, MC.card, _c.value),
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    ),
  );
}

/// Deterministic small tilt for polaroids, from an id.
double tiltFor(String id, {double maxDegrees = 2.2}) {
  var h = 0;
  for (final c in id.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  final unit = (h % 1000) / 1000.0 * 2 - 1;
  return unit * maxDegrees * pi / 180;
}

/// A white-bordered photo print with a handwritten caption strip.
class Polaroid extends StatelessWidget {
  const Polaroid({
    super.key,
    required this.image,
    required this.caption,
    this.tilt = 0,
    this.onTap,
    this.aspectRatio = 1,
    this.footer,
    this.semanticLabel,
  });

  final Widget image;
  final Widget caption;
  final double tilt;
  final VoidCallback? onTap;
  final double aspectRatio;
  final Widget? footer;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: MC.card,
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(color: MC.ink.withValues(alpha: 0.10), blurRadius: 10, offset: const Offset(0, 4)),
          BoxShadow(color: MC.ink.withValues(alpha: 0.06), blurRadius: 1, offset: const Offset(0, 1)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(9, 9, 9, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: aspectRatio,
            child: ClipRect(child: image),
          ),
          const SizedBox(height: 7),
          caption,
          if (footer != null) ...[const SizedBox(height: 4), footer!],
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: Transform.rotate(
        angle: tilt,
        child: GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: card),
      ),
    );
  }
}

/// A strip of washi tape across a card's top edge.
class Tape extends StatelessWidget {
  const Tape({super.key, this.color = MC.mustard, this.width = 64, this.angle = -0.08});
  final Color color;
  final double width;
  final double angle;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle,
    child: Container(width: width, height: 18, color: color.withValues(alpha: 0.45)),
  );
}
