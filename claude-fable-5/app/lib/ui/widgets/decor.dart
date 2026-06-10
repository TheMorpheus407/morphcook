import 'package:flutter/material.dart';

import '../theme.dart';

/// Diagonal-striped SVG-style placeholder — real photos are explicitly out;
/// the stripes are part of the design.
class StripedPlaceholder extends StatelessWidget {
  final Color color;
  final double? height;
  final String? caption;

  const StripedPlaceholder({
    super.key,
    required this.color,
    this.height,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final stripes = CustomPaint(
      painter: _StripePainter(color: color),
      child: caption == null
          ? null
          : Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                color: MorphColors.card.withValues(alpha: 0.92),
                child: Text(
                  caption!,
                  textAlign: TextAlign.center,
                  style: MorphText.hand
                      .copyWith(fontSize: 19, color: MorphColors.ink),
                ),
              ),
            ),
    );
    return height == null
        ? stripes
        : SizedBox(height: height, width: double.infinity, child: stripes);
  }
}

class _StripePainter extends CustomPainter {
  final Color color;
  const _StripePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size,
        Paint()..color = color.withValues(alpha: 0.16));
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 7;
    const gap = 18.0;
    for (var x = -size.height; x < size.width + size.height; x += gap) {
      canvas.drawLine(
          Offset(x, size.height + 4), Offset(x + size.height, -4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StripePainter old) => old.color != color;
}

/// Hand-drawn-feel dashed rule.
class DashedDivider extends StatelessWidget {
  final double height;
  final Color color;

  const DashedDivider(
      {super.key, this.height = 24, this.color = MorphColors.line});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: CustomPaint(
          size: const Size(double.infinity, 1),
          painter: _DashPainter(color: color),
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;
  const _DashPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    for (var x = 0.0; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, 0), Offset(x + 4.5, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => old.color != color;
}

/// "— section name —" newspaper-style header.
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Expanded(child: DashedDivider(height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(title.toLowerCase(), style: MorphText.label()),
          ),
          Expanded(
            child: trailing == null
                ? const DashedDivider(height: 1)
                : Row(children: [
                    const Expanded(child: DashedDivider(height: 1)),
                    const SizedBox(width: 8),
                    trailing!,
                  ]),
          ),
        ],
      ),
    );
  }
}

/// Polaroid-ish card: white frame, striped photo area, handwritten caption,
/// slight deterministic rotation.
class PolaroidCard extends StatelessWidget {
  final Color stripe;
  final String title;
  final String caption;
  final String? badge;
  final VoidCallback? onTap;
  final int rotationSeed;
  final double photoHeight;

  const PolaroidCard({
    super.key,
    required this.stripe,
    required this.title,
    required this.caption,
    this.badge,
    this.onTap,
    this.rotationSeed = 0,
    this.photoHeight = 110,
  });

  @override
  Widget build(BuildContext context) {
    // ±1.6° wobble, deterministic per card.
    final angle = ((rotationSeed * 37) % 7 - 3) * 0.009;
    return Transform.rotate(
      angle: angle,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: MorphColors.card,
            border: Border.all(color: MorphColors.line),
            boxShadow: [
              BoxShadow(
                color: MorphColors.ink.withValues(alpha: 0.10),
                blurRadius: 10,
                offset: const Offset(2, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  StripedPlaceholder(color: stripe, height: photoHeight),
                  if (badge != null)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        color: MorphColors.ink,
                        child: Text(badge!,
                            style: MorphText.label(
                                color: MorphColors.cream, size: 9)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title.toLowerCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MorphText.display.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: MorphText.hand.copyWith(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small mono chip used in switchers and filters.
class MonoChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const MonoChip({
    super.key,
    required this.label,
    this.selected = false,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = !enabled
        ? MorphColors.inkFaint
        : selected
            ? MorphColors.cream
            : MorphColors.ink;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? MorphColors.ink : Colors.transparent,
            border: Border.all(
                color: selected ? MorphColors.ink : MorphColors.line),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(label.toLowerCase(),
              style: MorphText.mono.copyWith(fontSize: 11, color: fg)),
        ),
      ),
    );
  }
}

/// Skeleton block for paginated list loading states. Deliberately static:
/// no infinite shimmer — calmer, honors reduce-motion by default, and an
/// endlessly repeating animation would keep `pumpAndSettle` from ever
/// settling in widget tests.
class SkeletonBlock extends StatelessWidget {
  final double height;
  const SkeletonBlock({super.key, this.height = 72});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: MorphColors.paperDeep.withValues(alpha: 0.7),
        border: Border.all(color: MorphColors.line),
      ),
    );
  }
}
