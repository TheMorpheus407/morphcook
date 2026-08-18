import 'dart:math';

import 'package:flutter/material.dart';

import 'theme.dart';

class PaperBackdrop extends StatelessWidget {
  final Widget child;
  const PaperBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = LedgerScope.colors(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: p.linen),
        CustomPaint(painter: PaperGrainPainter(p.grain), child: const SizedBox.expand()),
        child,
      ],
    );
  }
}

class PaperGrainPainter extends CustomPainter {
  final Color grain;
  const PaperGrainPainter(this.grain);

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(17);
    final paint = Paint()..color = grain;
    final count = (size.width * size.height / 180).round().clamp(80, 1400);
    for (var i = 0; i < count; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), rnd.nextDouble() * 0.9 + 0.2, paint);
    }
  }

  @override
  bool shouldRepaint(PaperGrainPainter oldDelegate) => oldDelegate.grain != grain;
}

class DashedRule extends StatelessWidget {
  const DashedRule({super.key});

  @override
  Widget build(BuildContext context) {
    final p = LedgerScope.colors(context);
    return CustomPaint(
      painter: _DashPainter(p.line),
      size: const Size(double.infinity, 8),
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;
  const _DashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 5.0;
    const gap = 4.0;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(min(x + dash, size.width), y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StripeHero extends StatelessWidget {
  final Color stripe;
  final String caption;
  final double height;
  final double tilt;

  const StripeHero({
    super.key,
    required this.stripe,
    required this.caption,
    this.height = 168,
    this.tilt = -0.02,
  });

  @override
  Widget build(BuildContext context) {
    final p = LedgerScope.colors(context);
    return Transform.rotate(
      angle: tilt,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: p.card,
          border: Border.all(color: p.walnut.withValues(alpha: 0.12), width: 1),
          boxShadow: [
            BoxShadow(
              color: p.walnut.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: CustomPaint(
                painter: StripePainter(stripe),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: LedgerTheme.caveat,
                fontSize: 18,
                color: p.walnutSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StripePainter extends CustomPainter {
  final Color stripe;
  const StripePainter(this.stripe);

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = stripe.withValues(alpha: 0.18);
    canvas.drawRect(Offset.zero & size, bg);
    final paint = Paint()
      ..color = stripe.withValues(alpha: 0.55)
      ..strokeWidth = 7;
    const gap = 14.0;
    for (var x = -size.height; x < size.width + size.height; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(StripePainter oldDelegate) => oldDelegate.stripe != stripe;
}

class PolaroidCard extends StatelessWidget {
  final Widget child;
  final double tilt;
  final VoidCallback? onTap;

  const PolaroidCard({
    super.key,
    required this.child,
    this.tilt = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = LedgerScope.colors(context);
    return Transform.rotate(
      angle: tilt,
      child: Material(
        color: p.card,
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: p.walnut.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: p.walnut.withValues(alpha: 0.07),
                  blurRadius: 12,
                  offset: const Offset(1, 6),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = LedgerScope.colors(context);
    return Text(
      text.toLowerCase(),
      style: TextStyle(
        fontFamily: LedgerTheme.mono,
        fontSize: 11,
        letterSpacing: 1.4,
        color: p.clay,
      ),
    );
  }
}

class SoftChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const SoftChip({
    super.key,
    required this.label,
    this.selected = false,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = LedgerScope.colors(context);
    final fg = !enabled
        ? p.walnutFaint
        : selected
            ? p.linen
            : p.walnut;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: selected ? p.clay : p.linenDeep,
        shape: StadiumBorder(side: BorderSide(color: p.line)),
        child: InkWell(
          onTap: enabled ? onTap : null,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: LedgerTheme.mono,
                fontSize: 11,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Masthead extends StatelessWidget {
  final String name;
  final String tagline;
  const Masthead({super.key, required this.name, required this.tagline});

  @override
  Widget build(BuildContext context) {
    final p = LedgerScope.colors(context);
    final now = DateTime.now();
    final date =
        '${now.day.toString().padLeft(2, '0')} · ${now.month.toString().padLeft(2, '0')} · ${now.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              date,
              style: TextStyle(
                fontFamily: LedgerTheme.mono,
                fontSize: 10,
                letterSpacing: 1.2,
                color: p.walnutFaint,
              ),
            ),
            const Spacer(),
            Text(
              'vol. i  ·  kitchen ledger',
              style: TextStyle(
                fontFamily: LedgerTheme.mono,
                fontSize: 10,
                letterSpacing: 1.1,
                color: p.walnutFaint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'morphcook',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displayLarge,
        ),
        Text(
          tagline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: LedgerTheme.caveat,
            fontSize: 22,
            color: p.walnutSoft,
          ),
        ),
        if (name.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '&  $name',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: LedgerTheme.playfair,
              fontStyle: FontStyle.italic,
              fontSize: 16,
              color: p.sage,
            ),
          ),
        ],
        const SizedBox(height: 12),
        const DashedRule(),
      ],
    );
  }
}

class QuietButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  const QuietButton({
    super.key,
    required this.label,
    this.onPressed,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = LedgerScope.colors(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: filled ? p.walnut : Colors.transparent,
        foregroundColor: filled ? p.linen : p.walnut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: p.walnut.withValues(alpha: 0.35)),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: LedgerTheme.playfair,
          fontStyle: FontStyle.italic,
          fontSize: 16,
        ),
      ),
    );
  }
}
