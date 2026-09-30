import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../core/theme/palette.dart';
import '../core/theme/typography.dart';
import 'paper.dart';

enum PaperButtonStyle {
  /// Ink block with a coral misprint shadow: the main action.
  filled,

  /// Dashed outline.
  outline,

  /// Underlined text.
  quiet,
}

/// Button in the stamped-paper style: mono capitals, square corners.
class PaperButton extends StatefulWidget {
  const PaperButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = PaperButtonStyle.filled,
    this.expand = false,
    this.dense = false,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final PaperButtonStyle style;
  final bool expand;
  final bool dense;
  final Color? color;

  @override
  State<PaperButton> createState() => _PaperButtonState();
}

class _PaperButtonState extends State<PaperButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final filled = widget.style == PaperButtonStyle.filled;
    final quiet = widget.style == PaperButtonStyle.quiet;
    final accent = widget.color ?? Palette.ink;
    final foreground = filled ? Palette.paperLight : accent;
    final textStyle = AppText.mono(
      size: widget.dense ? 11.5 : 12.5,
      color: enabled ? foreground : Palette.inkFaint,
      weight: FontWeight.w700,
      letterSpacing: 1.3,
    ).copyWith(decoration: quiet ? TextDecoration.underline : null, decorationColor: accent);

    final Widget label = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: widget.dense ? 16 : 18, color: enabled ? foreground : Palette.inkFaint),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(widget.label.toUpperCase(), style: textStyle, textAlign: TextAlign.center, maxLines: 2),
        ),
      ],
    );

    final padding = EdgeInsets.symmetric(horizontal: quiet ? 4 : 20, vertical: widget.dense ? 10 : 14);
    final shadowOffset = _down ? const Offset(1, 1) : const Offset(3.5, 3.5);

    Widget body;
    if (filled) {
      body = AnimatedContainer(
        duration: context.motion(const Duration(milliseconds: 90)),
        transform: Matrix4.translationValues(_down ? 2.5 : 0, _down ? 2.5 : 0, 0),
        padding: padding,
        decoration: BoxDecoration(
          color: enabled ? Palette.ink : Palette.paperDeep,
          borderRadius: BorderRadius.circular(3),
          boxShadow: enabled ? [BoxShadow(color: Palette.coral.withValues(alpha: 0.85), offset: shadowOffset)] : null,
        ),
        child: label,
      );
    } else if (widget.style == PaperButtonStyle.outline) {
      body = CustomPaint(
        foregroundPainter: DashedBorderPainter(color: enabled ? accent : Palette.inkFaint, radius: 3, strokeWidth: 1.3),
        child: Padding(padding: padding, child: label),
      );
    } else {
      body = Padding(padding: padding, child: label);
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Padding(
            padding: filled ? const EdgeInsets.only(right: 4, bottom: 4) : EdgeInsets.zero,
            child: Center(widthFactor: widget.expand ? null : 1, heightFactor: 1, child: body),
          ),
        ),
      ),
    );
  }
}

/// Square icon button with a tooltip and a real 48 dp target.
class PaperIconButton extends StatelessWidget {
  const PaperIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = Palette.ink,
    this.size = 24,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color color;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onPressed,
          radius: 26,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: filled
                  ? Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: Palette.ink, borderRadius: BorderRadius.circular(3)),
                      child: Icon(icon, size: size - 4, color: Palette.paperLight),
                    )
                  : Icon(icon, size: size, color: onPressed == null ? Palette.inkFaint : color),
            ),
          ),
        ),
      ),
    );
  }
}

enum PaperChipStyle { serif, mono }

/// A selectable chip. Disabled chips stay visible with a dashed outline and a
/// strike-through, and can still explain themselves through [onDisabledTap].
class PaperChip extends StatelessWidget {
  const PaperChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.enabled = true,
    this.onDisabledTap,
    this.style = PaperChipStyle.serif,
    this.icon,
    this.semanticHint,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool enabled;
  final VoidCallback? onDisabledTap;
  final PaperChipStyle style;
  final IconData? icon;
  final String? semanticHint;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final Color foreground = !enabled ? Palette.inkFaint : (selected ? Palette.paperLight : Palette.ink);
    final base = style == PaperChipStyle.serif
        ? AppText.serifItalic(
            size: dense ? 14 : 15.5,
            color: foreground,
            weight: selected ? FontWeight.w500 : FontWeight.w400,
            height: 1.1,
          )
        : AppText.mono(
            size: dense ? 11 : 12,
            color: foreground,
            weight: selected ? FontWeight.w700 : FontWeight.w400,
            letterSpacing: 0.3,
          );
    final textStyle = base.copyWith(
      decoration: enabled ? null : TextDecoration.lineThrough,
      decorationColor: Palette.inkFaint,
    );

    final child = AnimatedContainer(
      duration: context.motion(const Duration(milliseconds: 140)),
      padding: EdgeInsets.symmetric(horizontal: dense ? 11 : 14, vertical: dense ? 8 : 10),
      decoration: BoxDecoration(
        color: !enabled ? Colors.transparent : (selected ? Palette.ink : Palette.paperLight),
        borderRadius: BorderRadius.circular(3),
        border: enabled ? Border.all(color: selected ? Palette.ink : Palette.rule, width: 1.2) : null,
      ),
      foregroundDecoration: null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected && enabled) ...[Icon(Icons.circle, size: 7, color: Palette.coral), const SizedBox(width: 7)],
          if (icon != null) ...[Icon(icon, size: 15, color: foreground), const SizedBox(width: 6)],
          Flexible(child: Text(label, style: textStyle)),
        ],
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      hint: semanticHint,
      excludeSemantics: true,
      onTap: enabled ? onTap : onDisabledTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : onDisabledTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Center(
            widthFactor: 1,
            child: enabled ? child : CustomPaint(foregroundPainter: const DashedBorderPainter(radius: 3), child: child),
          ),
        ),
      ),
    );
  }
}

/// Tiny bordered label: `vegan`, `35 min`, `520 kcal`.
class MonoTag extends StatelessWidget {
  const MonoTag(this.text, {super.key, this.color = Palette.inkSoft, this.filled = false});

  final String text;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.14) : null,
        border: Border.all(color: color.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(text.toUpperCase(), style: AppText.label(size: 9.5, color: color)),
    );
  }
}

/// Handwritten margin note, slightly tilted.
class HandNote extends StatelessWidget {
  const HandNote(
    this.text, {
    super.key,
    this.size = 22,
    this.color = Palette.coralDeep,
    this.angle = -0.018,
    this.textAlign,
  });

  final String text;
  final double size;
  final Color color;
  final double angle;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        textAlign: textAlign,
        style: AppText.hand(size: size, color: color),
      ),
    );
  }
}

/// Renders `&` as a large coral italic ampersand: "quick & easy".
class AmpersandText extends StatelessWidget {
  const AmpersandText(
    this.text, {
    super.key,
    required this.style,
    this.ampersandColor = Palette.coral,
    this.textAlign,
    this.fitWords = false,
  });

  final String text;
  final TextStyle style;
  final Color ampersandColor;
  final TextAlign? textAlign;

  /// For headlines: the text wraps between words as usual, and shrinks just
  /// enough that its longest word fits the line. Large system text can make a
  /// single word wider than the screen, and a word must never break in the middle.
  final bool fitWords;

  @override
  Widget build(BuildContext context) {
    if (!fitWords) return _build(style);
    return LayoutBuilder(builder: (context, box) => _build(_fitted(context, box.maxWidth)));
  }

  TextStyle _fitted(BuildContext context, double maxWidth) {
    final size = style.fontSize;
    if (size == null || !maxWidth.isFinite) return style;
    final scaler = MediaQuery.textScalerOf(context);
    var widest = 0.0;
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.isEmpty || word == '&') continue;
      final painter = TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    if (widest <= maxWidth || widest == 0) return style;
    return style.copyWith(fontSize: size * maxWidth / widest);
  }

  Widget _build(TextStyle style) {
    final parts = text.split('&');
    final spans = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      spans.add(TextSpan(text: parts[i]));
      if (i < parts.length - 1) {
        spans.add(
          TextSpan(
            text: '&',
            style: AppText.display(size: (style.fontSize ?? 24) * 1.18, color: ampersandColor),
          ),
        );
      }
    }
    return Text.rich(
      TextSpan(style: style, children: spans),
      textAlign: textAlign,
    );
  }
}

/// Section heading: italic title, optional trailing note, dashed rule below.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing, this.note});

  final String title;
  final Widget? trailing;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: AmpersandText(title, style: AppText.display(size: 27), fitWords: true),
                ),
              ),
              ?trailing,
            ],
          ),
          if (note != null) ...[const SizedBox(height: 2), HandNote(note!, size: 20)],
          const SizedBox(height: 8),
          const DashedRule(),
        ],
      ),
    );
  }
}

/// Small uppercase mono caption, for field and group labels.
class MonoLabel extends StatelessWidget {
  const MonoLabel(this.text, {super.key, this.color = Palette.inkSoft});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: AppText.label(color: color));
}
