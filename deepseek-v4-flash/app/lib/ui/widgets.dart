import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/models.dart';

/// Corner washi-tape accents for page frames.
class WashiTape extends StatelessWidget {
  final bool topLeft;
  final bool bottomRight;
  final Color color;

  const WashiTape({
    super.key,
    this.topLeft = true,
    this.bottomRight = true,
    this.color = AppColors.accentSoft,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (topLeft)
          Positioned(
            top: -8,
            left: -6,
            child: Transform.rotate(
              angle: -0.35,
              child: Container(
                width: 46,
                height: 14,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        if (bottomRight)
          Positioned(
            bottom: -8,
            right: -6,
            child: Transform.rotate(
              angle: 0.32,
              child: Container(
                width: 46,
                height: 14,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Dotted paper seam used as a separator.
class DottedDivider extends StatelessWidget {
  final Color color;
  final double height;

  const DottedDivider({
    super.key,
    this.color = AppColors.lineDotted,
    this.height = 10,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _DotsPainter(color),
    );
  }
}

class _DotsPainter extends CustomPainter {
  final Color color;
  _DotsPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    const step = 8.0;
    var x = 2.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawCircle(Offset(x, y), 1.1, paint);
      x += step;
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color;
}

/// Newspaper masthead: nameplate, issue line, date line, double rule.
class Masthead extends StatelessWidget {
  final String volLine;
  final String dateLine;
  final Widget? right;

  const Masthead({
    super.key,
    required this.volLine,
    required this.dateLine,
    this.right,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(volLine,
                style: AppText.mono(context,
                    size: 10, color: AppColors.inkSoft)),
            const Text('✦',
                style: TextStyle(color: AppColors.inkFaint, fontSize: 12)),
            Text(dateLine,
                style: AppText.mono(context,
                    size: 10, color: AppColors.inkSoft)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'morphcook',
          textAlign: TextAlign.center,
          style: AppText.serif(context,
              size: 42, weight: FontWeight.w800, height: 1.0),
        ),
        const SizedBox(height: 6),
        Text(
          '—  the same dish for every body  —',
          textAlign: TextAlign.center,
          style: AppText.mono(context, size: 10, color: AppColors.accent)
              .copyWith(letterSpacing: 1.2),
        ),
        const SizedBox(height: 8),
        Container(height: 2.2, color: AppColors.ink),
        const SizedBox(height: 2),
        Container(height: 1, color: AppColors.ink),
        ?right,
      ],
    );
  }
}

/// Section heading with a small kicker above a serif title.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? kicker;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.kicker,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (kicker != null)
                  Text(
                    kicker!.toUpperCase(),
                    style: AppText.mono(context, size: 9, color: AppColors.accent)
                        .copyWith(letterSpacing: 2),
                  ),
                const SizedBox(height: 2),
                Text(title,
                    style:
                        AppText.serif(context, size: 22, weight: FontWeight.w700)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Faded polaroid "photo plate" painted from the dish stripe colors with a
/// hand-drawn suggestion of the dish (moody blobs + rays).
class PlatePainter extends CustomPainter {
  final Dish dish;
  PlatePainter(this.dish);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final base = Paint()
      ..shader = LinearGradient(
        colors: [dish.stripeSecondary, dish.stripeColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(4)),
        base);

    // table line (hand-drawn, slightly wobbling)
    final wobble = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final path = Path();
    final y = h * 0.72;
    for (double x = 6; x < w - 4; x += 8) {
      final yy = y + math.sin(x / 14) * 1.6;
      if (x == 6) {
        path.moveTo(x, yy);
      } else {
        path.lineTo(x, yy);
      }
    }
    canvas.drawPath(path, wobble);

    // "plate" circle
    final plate = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(w / 2, h * 0.42), w * 0.26, plate);

    // steam curls
    final steam = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final s = Path();
    for (var i = 0; i < 3; i++) {
      final sx = w * (0.35 + i * 0.15);
      s.moveTo(sx, h * 0.16);
      s.quadraticBezierTo(sx + 4, h * 0.10, sx, h * 0.05);
      s.quadraticBezierTo(sx - 4, h * 0.02, sx, h * 0.0);
    }
    canvas.drawPath(s, steam);
  }

  @override
  bool shouldRepaint(PlatePainter old) => old.dish.id != dish.id;
}

/// Decorative gradient backing for a dish (photo placeholder backgrounds).
BoxDecoration plateGradient(Dish dish) => BoxDecoration(
      gradient: LinearGradient(
        colors: [dish.stripeSecondary, dish.stripeColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );

/// The polaroid dish card: photo plate, dotted inner seam, handwritten caption.
class PolaroidCard extends StatelessWidget {
  final Dish dish;
  final String caption;
  final String? sub;
  final VoidCallback? onTap;
  final Widget? badge;
  final bool selected;
  final double? width;

  const PolaroidCard({
    super.key,
    required this.dish,
    required this.caption,
    this.sub,
    this.onTap,
    this.badge,
    this.selected = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: AppColors.paperBright,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: selected ? AppColors.accent : AppColors.line,
              width: selected ? 2 : 1),
          boxShadow: const [
            BoxShadow(color: Color(0x1F000000), blurRadius: 6, offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 88,
              decoration: plateGradient(dish),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                      child: CustomPaint(painter: PlatePainter(dish))),
                  if (badge != null) Positioned(top: 6, right: 6, child: badge!),
                ],
              ),
            ),
            const SizedBox(height: 7),
            DottedDivider(height: 5, color: dish.stripeColor.withValues(alpha: 0.45)),
            const SizedBox(height: 2),
            Text(
              caption,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.script(context, size: 22, color: AppColors.ink),
            ),
            if (sub != null)
              Text(
                sub!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.mono(context, size: 9, color: AppColors.inkFaint),
              ),
          ],
        ),
      ),
    );
  }
}

/// Zebra-striped list row with a staggered pastel backing.
class ZebraRow extends StatelessWidget {
  final int index;
  final Widget child;
  final Color? stripe;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const ZebraRow({
    super.key,
    required this.index,
    required this.child,
    this.stripe,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    final bg = stripe ??
        AppColors.zebraB[index % AppColors.zebraB.length];
    return Material(
      color: bg,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Press-style chip (mono uppercase).
class PressChip extends StatelessWidget {
  final String label;
  final Color? color;
  final bool filled;

  const PressChip({
    super.key,
    required this.label,
    this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? c : Colors.transparent,
        border: Border.all(color: c.withValues(alpha: 0.6), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppText.mono(context,
            size: 9,
            color: filled ? Colors.white : c).copyWith(letterSpacing: 0.8),
      ),
    );
  }
}

/// Handwritten margin note (Caveat).
class MarginNote extends StatelessWidget {
  final String text;
  final Color color;
  final double size;

  const MarginNote(
      {super.key, required this.text, this.color = AppColors.accent, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppText.script(context, size: size, color: color),
    );
  }
}

/// Page frame: paper + generous margins + tape corners, like a zine page.
class ZinePage extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const ZinePage({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 24)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      padding: padding,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(child: WashiTape()),
          Padding(padding: const EdgeInsets.only(top: 10), child: child),
        ],
      ),
    );
  }
}
