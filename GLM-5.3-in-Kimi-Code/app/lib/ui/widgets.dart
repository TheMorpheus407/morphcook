/// Shared paper-age widgets: masthead, dashed rules, striped placeholders,
/// polaroid recipe cards, hand-drawn chips & tags.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n.dart';
import 'theme.dart';

/// Paper grain overlay — cheap deterministic noise via translucent dots.
class PaperGrain extends StatelessWidget {
  final Widget child;
  const PaperGrain({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      child,
      const Positioned.fill(
        child: IgnorePointer(
          child: RepaintBoundary(child: CustomPaint(painter: _GrainPainter())),
        ),
      ),
    ]);
  }
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppTheme.inkFaint.withValues(alpha: 0.05);
    final rng = math.Random(7); // deterministic grain
    for (var i = 0; i < size.width * size.height / 900; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), rng.nextDouble() * 0.8 + 0.2, paint);
    }
    // faint horizontal paper fibers
    final fiber = Paint()
      ..color = AppTheme.inkFaint.withValues(alpha: 0.03)
      ..strokeWidth = 0.6;
    for (var i = 0; i < size.height / 26; i++) {
      final y = rng.nextDouble() * size.height;
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y + rng.nextDouble() * 6 - 3), fiber);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Newspaper masthead: heavy top rule, wordmark, tagline, dateline.
class Masthead extends StatelessWidget {
  final Lang lang;
  final String? name;
  const Masthead({super.key, required this.lang, this.name});

  String _dateline() {
    final now = DateTime.now();
    const months = [
      'january', 'february', 'march', 'april', 'may', 'june', 'july',
      'august', 'september', 'october', 'november', 'december'
    ];
    const monthsDe = [
      'januar', 'februar', 'märz', 'april', 'mai', 'juni', 'juli',
      'august', 'september', 'oktober', 'november', 'dezember'
    ];
    final m = lang == Lang.de ? monthsDe[now.month - 1] : months[now.month - 1];
    final wd = [
      'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
    ][now.weekday - 1];
    final wdDe = [
      'montag', 'dienstag', 'mittwoch', 'donnerstag', 'freitag', 'samstag', 'sonntag'
    ][now.weekday - 1];
    return lang == Lang.de
        ? '$wdDe, ${now.day}. $m ${now.year}'
        : '$wd, $m ${now.day}, ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final lang = this.lang;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(height: 7, color: AppTheme.ink),
      const SizedBox(height: 10),
      Text(
        'morphcook',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppTheme.display,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
          fontSize: 40,
          height: 1,
          letterSpacing: -0.5,
          color: AppTheme.ink,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        L.t(lang, 'tagline'),
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontFamily: AppTheme.mono,
            fontSize: 10.5,
            letterSpacing: 2.2,
            color: AppTheme.inkSoft),
      ),
      const SizedBox(height: 8),
      DashedRule(),
      const SizedBox(height: 4),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name == null || name!.isEmpty ? 'no. 001 — vol. i' : "$name's edition",
            style: const TextStyle(
                fontFamily: AppTheme.mono,
                fontSize: 9.5,
                letterSpacing: 1.6,
                color: AppTheme.inkFaint),
          ),
          Text(
            _dateline(),
            style: const TextStyle(
                fontFamily: AppTheme.mono,
                fontSize: 9.5,
                letterSpacing: 1.6,
                color: AppTheme.inkFaint),
          ),
        ],
      ),
      const SizedBox(height: 4),
      DashedRule(),
    ]);
  }
}

/// Dashed horizontal rule — the cookbook's favorite divider.
class DashedRule extends StatelessWidget {
  final Color color;
  final double dashWidth;
  final double gap;
  const DashedRule({super.key, this.color = AppTheme.line, this.dashWidth = 6, this.gap = 4});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: _DashPainter(color: color, dashWidth: dashWidth, gap: gap),
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double gap;
  const _DashPainter({required this.color, required this.dashWidth, required this.gap});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) =>
      old.color != color || old.dashWidth != dashWidth;
}

/// Striped dish illustration — angled bands in the dish's stripe color,
/// with an italic handwritten caption band across the middle.
class StripedPlate extends StatelessWidget {
  final Color color;
  final String caption;
  final double height;
  final double rotation; // polaroid-ish tilt in degrees
  const StripedPlate({
    super.key,
    required this.color,
    required this.caption,
    this.height = 200,
    this.rotation = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation * math.pi / 180,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _StripePainter(base: color),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                color: AppTheme.paper.withValues(alpha: 0.92),
                child: Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.display,
                    fontStyle: FontStyle.italic,
                    fontSize: 15,
                    color: AppTheme.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  final Color base;
  const _StripePainter({required this.base});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base.withValues(alpha: 0.14));
    final paint = Paint()..color = base.withValues(alpha: 0.55);
    final dark = Paint()..color = base;
    const spacing = 26.0;
    const bandWidth = 11.0;
    final diag = size.width + size.height;
    var i = 0;
    for (var x = -size.height; x < diag; x += spacing) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + bandWidth, 0)
        ..lineTo(x + bandWidth + size.height * 0.35, size.height)
        ..lineTo(x + size.height * 0.35, size.height)
        ..close();
      canvas.drawPath(path, i % 4 == 0 ? dark : paint);
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant _StripePainter old) => old.base != base;
}

/// Polaroid recipe card: striped plate, thick paper frame, slight rotation,
/// handwritten dish name, mono metadata line. [flagText] renders a small
/// mustard marker when the shown variant sits outside the user's rules.
class PolaroidCard extends StatelessWidget {
  final void Function()? onTap;
  final Color stripeColor;
  final String title;
  final String? subtitle;
  final String meta; // e.g. "vegan · 45 min · ~590 kcal"
  final String? tag; // variant tag when enabled
  final String? flagText; // e.g. "outside your rules"
  final double rotation;
  final double plateHeight;

  const PolaroidCard({
    super.key,
    required this.stripeColor,
    required this.title,
    required this.meta,
    this.onTap,
    this.subtitle,
    this.tag,
    this.flagText,
    this.rotation = 0,
    this.plateHeight = 132,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Transform.rotate(
        angle: rotation * math.pi / 180,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.paper,
            border: Border.all(color: AppTheme.line),
            boxShadow: [
              BoxShadow(
                color: AppTheme.ink.withValues(alpha: 0.10),
                blurRadius: 10,
                offset: const Offset(2, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              StripedPlate(color: stripeColor, caption: title, height: plateHeight),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: AppTheme.hand,
                    fontSize: 21,
                    height: 1.05,
                    color: AppTheme.ink),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: AppTheme.display,
                      fontStyle: FontStyle.italic,
                      fontSize: 13.5,
                      color: AppTheme.inkSoft),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: AppTheme.mono,
                    fontSize: 10,
                    letterSpacing: 0.6,
                    color: AppTheme.inkFaint),
              ),
              if (tag != null) ...[
                const SizedBox(height: 6),
                Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: stripeColor, width: 1.2),
                  ),
                  child: Text(
                    tag!.toUpperCase(),
                    style: TextStyle(
                        fontFamily: AppTheme.mono,
                        fontSize: 9,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w700,
                        color: stripeColor),
                  ),
                ),
              ],
              if (flagText != null) ...[
                const SizedBox(height: 5),
                Text(
                  '⚑ $flagText',
                  style: const TextStyle(
                      fontFamily: AppTheme.mono,
                      fontSize: 8.5,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mustard),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small ink stamp chip (diet flags, techniques).
class StampChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;
  final bool enabled;
  const StampChip({
    super.key,
    required this.label,
    required this.color,
    this.selected = false,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? color : AppTheme.paper,
            border: Border.all(
              color: selected ? color : AppTheme.line,
              width: 1.3,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.mono,
              fontSize: 10.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: selected ? AppTheme.paper : AppTheme.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

/// Section header: mono overline + dashed underline, e.g. "— diet ———".
class RuleLabel extends StatelessWidget {
  final String label;
  const RuleLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(
        '— $label ',
        style: const TextStyle(
            fontFamily: AppTheme.mono,
            fontSize: 11,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w700,
            color: AppTheme.inkFaint),
      ),
      const Expanded(child: DashedRule()),
    ]);
  }
}

/// Handwritten empty-state note.
class HandNote extends StatelessWidget {
  final String text;
  const HandNote({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
          fontFamily: AppTheme.hand, fontSize: 20, color: AppTheme.inkSoft, height: 1.2),
    );
  }
}
