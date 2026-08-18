import 'package:flutter/material.dart';

import 'palette.dart';
import 'paper.dart';

/// Diagonal-stripe placeholder "photo" with a handwritten caption —
/// the signature MorphCook image treatment.
class StripedPlaceholder extends StatelessWidget {
  const StripedPlaceholder({
    super.key,
    required this.colors,
    this.caption,
    this.width,
    this.height = 190,
    this.stripeWidth = 14,
    this.borderRadius,
    this.dark = false,
  });

  final List<Color> colors;
  final String? caption;
  final double? width;
  final double height;
  final double stripeWidth;
  final BorderRadius? borderRadius;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final size = Size(width ?? double.infinity, height);
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(2),
      child: Container(
        width: size.width,
        height: size.height,
        color: colors.isNotEmpty ? colors.first.withValues(alpha: 0.85) : MC.rule,
        child: CustomPaint(
          painter: StripePainter(colors: colors, stripeWidth: stripeWidth),
          child: caption == null
              ? null
              : Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.42),
                        ],
                      ),
                    ),
                    child: Text(
                      caption!,
                      style: TextStyle(
                        fontFamily: 'Caveat',
                        fontSize: 19,
                        height: 1.1,
                        color: dark ? MC.nightInk : MC.card,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class StripePainter extends CustomPainter {
  StripePainter({required this.colors, this.stripeWidth = 14});

  final List<Color> colors;
  final double stripeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.isEmpty) return;
    var i = 0;
    var offset = -size.height;
    while (offset < size.width + size.height) {
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: 0.9);
      final path = Path()
        ..moveTo(offset, size.height)
        ..lineTo(offset + stripeWidth, size.height)
        ..lineTo(offset + stripeWidth + size.height, 0)
        ..lineTo(offset + size.height, 0)
        ..close();
      canvas.drawPath(path, paint);
      offset += stripeWidth;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant StripePainter old) =>
      old.colors != colors || old.stripeWidth != stripeWidth;
}

/// Polaroid-framed striped placeholder with a handwritten caption.
class PolaroidStripes extends StatelessWidget {
  const PolaroidStripes({
    super.key,
    required this.colors,
    required this.caption,
    this.rotation = 0,
    this.height = 170,
    this.dark = false,
  });

  final List<Color> colors;
  final String caption;
  final double rotation;
  final double height;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final frame = dark ? MC.nightRaised : MC.card;
    return Polaroid(
      rotation: rotation,
      color: frame,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StripedPlaceholder(colors: colors, height: height, caption: null),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 2, right: 2, bottom: 2),
            child: Text(
              caption,
              style: TextStyle(
                fontFamily: 'Caveat',
                fontSize: 17,
                height: 1.1,
                color: dark ? MC.nightInk : MC.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small striped square used in lists/tiles.
class StripeThumb extends StatelessWidget {
  const StripeThumb({super.key, required this.colors, this.size = 56});

  final List<Color> colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: StripePainter(colors: colors, stripeWidth: 9),
        ),
      ),
    );
  }
}

/// The newspaper-style masthead: big italic wordmark, date line, double rule.
class Masthead extends StatelessWidget {
  const Masthead({super.key, this.subtitle, this.trailing, this.dark = false});

  final String? subtitle;
  final Widget? trailing;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final ink = dark ? MC.nightInk : MC.ink;
    final rule = dark ? MC.nightRule : MC.rule;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'morphcook',
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 40,
                    height: 0.95,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    color: ink,
                  ),
                ),
              ),
            ),
            const Spacer(),
            ?trailing,
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                subtitle ?? '',
                style: TextStyle(
                  fontFamily: 'Caveat',
                  fontSize: 19,
                  height: 1.1,
                  color: dark ? MC.inkFaint : MC.inkSoft,
                ),
              ),
            ),
            Text(
              'vol. I · ${_today()}',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 10,
                letterSpacing: 1.2,
                color: dark ? MC.inkFaint : MC.inkFaint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(height: 2.5, color: ink),
        const SizedBox(height: 2),
        Container(height: 1, color: rule),
      ],
    );
  }

  String _today() {
    final now = DateTime.now();
    const months = [
      'jan', 'feb', 'mar', 'apr', 'may', 'jun',
      'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
    ];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }
}

/// Section header: serif title + handwritten annotation + dashed rule.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.annotation,
    this.action,
    this.dark = false,
  });

  final String title;
  final String? annotation;
  final Widget? action;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final ink = dark ? MC.nightInk : MC.ink;
    final rule = dark ? MC.nightRule : MC.rule;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontSize: 23,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
            if (annotation != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  annotation!,
                  style: TextStyle(
                    fontFamily: 'Caveat',
                    fontSize: 17,
                    color: dark ? MC.inkFaint : MC.inkSoft,
                  ),
                ),
              ),
            ],
            ?action,
          ],
        ),
        const SizedBox(height: 6),
        CustomPaint(
          painter: DashedRulePainter(color: rule),
          size: const Size(double.infinity, 1),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
