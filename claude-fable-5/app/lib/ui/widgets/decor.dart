import 'package:flutter/material.dart';

import '../theme.dart';

/// Diagonal-striped SVG-style placeholder — real photos are explicitly out;
/// the stripes are part of the design. In readable mode the diagonals give
/// way to a flat wash: community feedback flagged the stripes as visual
/// noise that bleeds into text for dyslexic and low-vision readers.
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
    final morph = MorphTheme.of(context);
    final cover = CustomPaint(
      painter: _CoverPainter(
        color: color,
        flat: morph.readable,
        isDark: morph.isDark,
      ),
      child: caption == null
          ? null
          : Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                // Fully opaque with a hairline: stripes end at the plate's
                // edge instead of running on under the words.
                decoration: BoxDecoration(
                  color: morph.colors.card,
                  border: Border.all(color: morph.colors.line),
                ),
                child: Text(
                  caption!,
                  textAlign: TextAlign.center,
                  style: morph.text.handAt(19, color: morph.colors.ink),
                ),
              ),
            ),
    );
    return height == null
        ? cover
        : SizedBox(height: height, width: double.infinity, child: cover);
  }
}

class _CoverPainter extends CustomPainter {
  final Color color;
  final bool flat;
  final bool isDark;
  const _CoverPainter({
    required this.color,
    required this.flat,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Dish stripe colors are authored against paper; on night they need a
    // touch more presence to read as color at all.
    final washAlpha = isDark ? 0.22 : 0.16;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = color.withValues(alpha: washAlpha),
    );
    if (flat) {
      final border = Paint()
        ..color = color.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRect(
        const Offset(0.75, 0.75) & Size(size.width - 1.5, size.height - 1.5),
        border,
      );
      return;
    }
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 7;
    const gap = 18.0;
    for (var x = -size.height; x < size.width + size.height; x += gap) {
      canvas.drawLine(
        Offset(x, size.height + 4),
        Offset(x + size.height, -4),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CoverPainter old) =>
      old.color != color || old.flat != flat || old.isDark != isDark;
}

/// Hand-drawn-feel dashed rule.
class DashedDivider extends StatelessWidget {
  final double height;
  final Color? color;

  const DashedDivider({super.key, this.height = 24, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: CustomPaint(
          size: const Size(double.infinity, 1),
          painter: _DashPainter(
            color: color ?? MorphTheme.of(context).colors.line,
          ),
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
    final morph = MorphTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Expanded(child: DashedDivider(height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(morph.cased(title), style: morph.text.label()),
          ),
          Expanded(
            child: trailing == null
                ? const DashedDivider(height: 1)
                : Row(
                    children: [
                      const Expanded(child: DashedDivider(height: 1)),
                      const SizedBox(width: 8),
                      trailing!,
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Polaroid-ish card: white frame, striped photo area, handwritten caption,
/// slight deterministic rotation (level in readable mode).
class PolaroidCard extends StatelessWidget {
  final Color stripe;
  final String title;
  final String caption;
  final String? badge;
  final VoidCallback? onTap;
  final int rotationSeed;
  final double photoHeight;
  final Widget? photo;

  const PolaroidCard({
    super.key,
    required this.stripe,
    required this.title,
    required this.caption,
    this.badge,
    this.onTap,
    this.rotationSeed = 0,
    this.photoHeight = 110,
    this.photo,
  });

  @override
  Widget build(BuildContext context) {
    final morph = MorphTheme.of(context);
    // ±1.6° wobble, deterministic per card.
    final angle = morph.readable ? 0.0 : ((rotationSeed * 37) % 7 - 3) * 0.009;
    return Transform.rotate(
      angle: angle,
      child: Semantics(
        button: onTap != null,
        label: badge == null ? title : '$title, $badge',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: morph.colors.card,
              border: Border.all(color: morph.colors.line),
              boxShadow: [
                BoxShadow(
                  color: morph.colors.ink.withValues(alpha: 0.10),
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
                    photo ??
                        StripedPlaceholder(color: stripe, height: photoHeight),
                    if (badge != null)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          color: morph.colors.ink,
                          child: Text(
                            badge!,
                            style: morph.text.label(
                              color: morph.colors.paper,
                              size: 9,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  morph.cased(title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: morph.text.display.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: morph.text.handAt(16),
                ),
              ],
            ),
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

  /// Tappable but outside the user's profile — quieter, not forbidden.
  final bool muted;
  final VoidCallback? onTap;

  const MonoChip({
    super.key,
    required this.label,
    this.selected = false,
    this.enabled = true,
    this.muted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final morph = MorphTheme.of(context);
    final colors = morph.colors;
    final fg = !enabled
        ? colors.inkFaint
        : selected
        ? colors.paper
        : muted
        ? colors.inkSoft
        : colors.ink;
    return Opacity(
      opacity: !enabled
          ? 0.55
          : muted
          ? 0.75
          : 1,
      child: Semantics(
        button: onTap != null,
        selected: selected,
        enabled: enabled,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: selected ? colors.ink : Colors.transparent,
              border: Border.all(color: selected ? colors.ink : colors.line),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              morph.cased(label),
              style: morph.text.mono.copyWith(fontSize: 11, color: fg),
            ),
          ),
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
    final colors = MorphTheme.of(context).colors;
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: colors.paperDeep.withValues(alpha: 0.7),
        border: Border.all(color: colors.line),
      ),
    );
  }
}
