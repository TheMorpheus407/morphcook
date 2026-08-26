/// Shared, non-screen widgets for the tumblr-era cookbook aesthetic:
/// striped dish placeholders, polaroid cards, chips, section headers,
/// empty states, buttons.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

Color stripeColor(String hex) {
  final x = hex.trim().replaceFirst('#', '');
  if (x.length != 6) return Palette.teal;
  final parsed = int.tryParse(x, radix: 16);
  if (parsed == null) return Palette.teal;
  return Color(0xFF000000 | parsed);
}

/// Diagonal striped placeholder in the dish's stripe color, with a
/// handwritten caption — the spec says these stay, they're the design.
class StripedPlaceholder extends StatelessWidget {
  const StripedPlaceholder({
    super.key,
    required this.color,
    required this.caption,
    this.width = 320,
    this.height = 180,
    this.radius = 10,
  });
  final Color color;
  final String caption;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CustomPaint(
          painter: _StripesPainter(color, radius),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              color: Palette.cardPaper,
              child: Text(caption, style: T.hand),
            ),
          ),
        ),
      ),
    );
  }
}

class _StripesPainter extends CustomPainter {
  _StripesPainter(this.color, this.radius);
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = Palette.cardPaper);
    canvas.save();
    canvas.clipRect(rect);
    canvas.rotate(-math.pi / 4);
    const stripeW = 24.0;
    const gap = 16.0;
    final diag = size.width + size.height;
    final paint = Paint()..color = color.withValues(alpha: 0.42);
    double x = -diag;
    while (x < diag) {
      canvas.drawRect(Rect.fromLTWH(x, -diag, stripeW, diag * 2), paint);
      x += stripeW + gap;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StripesPainter old) =>
      old.color != color || old.radius != radius;
}

/// A polaroid-ish card: cream paper, slight rotation, soft drop shadow.
class Polaroid extends StatelessWidget {
  const Polaroid({
    super.key,
    required this.child,
    this.rotation = 0.01,
    this.onTap,
    this.padding = const EdgeInsets.all(10),
  });
  final Widget child;
  final double rotation;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Transform.rotate(
        angle: rotation,
        child: Container(
          decoration: BoxDecoration(
            color: Palette.cardPaper,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Palette.ink.withValues(alpha: 0.09)),
            boxShadow: [
              BoxShadow(
                  color: Palette.ink.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(3, 4)),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Small rounded chip (variant switcher, filter, tags).
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.selected = false,
    this.disabled = false,
    this.onTap,
    this.icon,
  });
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color bg = disabled
        ? Palette.ink.withValues(alpha: 0.04)
        : selected
            ? Palette.ink.withValues(alpha: 0.92)
            : Colors.transparent;
    final Color fg = disabled
        ? Palette.inkFaint.withValues(alpha: 0.6)
        : selected
            ? Palette.paper
            : Palette.ink;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: disabled
                  ? Palette.ink.withValues(alpha: 0.08)
                  : selected
                      ? Palette.ink
                      : Palette.ink.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 13, color: fg, fontFamily: 'JetBrainsMono')),
          ],
        ),
      ),
    );
  }
}

/// Kicker + rule row used to head sections.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.label,
    this.hand,
    this.trailing,
  });
  final String label;
  final String? hand;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hand != null) ...[
          Text(hand!, style: T.hand),
          const SizedBox(height: 2),
        ],
        Row(
          children: [
            Expanded(
                child: Text(
              label.toUpperCase(),
              style: T.section.copyWith(letterSpacing: 2.6),
            )),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 5),
        Container(height: 1.4, color: Palette.ink.withValues(alpha: 0.14)),
      ],
    );
  }
}

/// Big friendly empty state.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.sub,
    this.action,
  });
  final String title;
  final String sub;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome,
                  size: 40, color: Palette.ink.withValues(alpha: 0.3)),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontStyle: FontStyle.italic,
                    fontSize: 22,
                    color: Palette.ink),
              ),
              const SizedBox(height: 8),
              Text(sub,
                  textAlign: TextAlign.center,
                  style: T.body.copyWith(fontSize: 13)),
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Primary/outline button in the house style.
class InkButton extends StatelessWidget {
  const InkButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.filled = true,
    this.small = false,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool filled;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final Color bg = filled ? Palette.coral : Colors.transparent;
    final Color fg = filled ? Colors.white : Palette.ink;
    final Color borderC =
        filled ? Palette.coral : Palette.ink.withValues(alpha: 0.4);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: small
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderC, width: filled ? 0 : 1.4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 7),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                    fontSize: small ? 13 : 15,
                    color: fg,
                    fontFamily: 'JetBrainsMono',
                    letterSpacing: 0.4),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tiny handwritten tag (like "×2" or "your döner").
class HandTag extends StatelessWidget {
  const HandTag({super.key, required this.text, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: (color ?? Palette.teal).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: T.hand.copyWith(fontSize: 17)),
    );
  }
}

/// Meta row: minutes / kcal / effort with small icons.
class MetaRow extends StatelessWidget {
  const MetaRow({
    super.key,
    required this.minutes,
    required this.kcal,
    required this.effortLabel,
  });
  final int minutes;
  final int kcal;
  final String effortLabel;

  @override
  Widget build(BuildContext context) {
    Widget cell(IconData icon, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Palette.inkFaint),
            const SizedBox(width: 4),
            Text(label, style: T.mono.copyWith(color: Palette.inkSoft)),
          ],
        );
    return Row(
      children: [
        cell(Icons.timer_outlined, '$minutes min'),
        const SizedBox(width: 10),
        cell(Icons.local_fire_department_outlined, '$kcal kcal'),
        const SizedBox(width: 10),
        cell(Icons.restaurant_menu_outlined, effortLabel),
      ],
    );
  }
}
