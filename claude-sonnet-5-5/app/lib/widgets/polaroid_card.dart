import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../core/theme/palette.dart';
import '../core/theme/typography.dart';
import 'paper.dart';
import 'stripe_placeholder.dart';

/// Deterministic tilt for a card: same id, same angle, every run. Between about
/// 0.5 and 1.9 degrees to either side.
double polaroidAngle(String seed) {
  var hash = 17;
  for (final unit in seed.codeUnits) {
    hash = (hash * 31 + unit) & 0xFFFFFF;
  }
  // A final mix spreads a change in the last letter over all the bits, so ids
  // like `dish-1` and `dish-2` do not lean the same way by the same amount.
  hash ^= hash >> 11;
  hash = (hash * 0x873593) & 0xFFFFFF;
  hash ^= hash >> 13;
  final sign = (hash >> 11).isEven ? 1 : -1;
  final magnitude = 0.009 + ((hash >> 12) % 100) / 100 * 0.024;
  return sign * magnitude;
}

/// A polaroid-ish recipe card: striped picture, handwritten title, a piece of
/// tape and a slight tilt that straightens when pressed.
class PolaroidCard extends StatefulWidget {
  const PolaroidCard({
    super.key,
    required this.seed,
    required this.title,
    required this.stripe,
    this.subtitle,
    this.caption,
    this.tape = true,
    this.onTap,
    this.badge,
    this.aspectRatio = 1,
  });

  /// Stable id that decides the tilt (usually the dish id).
  final String seed;
  final String title;
  final String? subtitle;
  final String? caption;
  final Color stripe;
  final bool tape;
  final VoidCallback? onTap;

  /// Optional corner badge (for example a small tag).
  final Widget? badge;
  final double aspectRatio;

  @override
  State<PolaroidCard> createState() => _PolaroidCardState();
}

class _PolaroidCardState extends State<PolaroidCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final angle = polaroidAngle(widget.seed);
    final duration = context.motion(const Duration(milliseconds: 160));
    final tapeColor = <Color>[Palette.mustard, Palette.sage, Palette.dustyBlue, Palette.rose][widget.seed.length % 4];

    return Semantics(
      button: widget.onTap != null,
      label: [widget.title, if (widget.subtitle != null) widget.subtitle!].join(', '),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: AnimatedRotation(
          turns: (_pressed ? 0 : angle) / (2 * 3.141592653589793),
          duration: duration,
          curve: Curves.easeOut,
          child: AnimatedScale(
            scale: _pressed ? 1.025 : 1,
            duration: duration,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.fromLTRB(9, 9, 9, 8),
                  decoration: BoxDecoration(
                    color: Palette.paperLight,
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: Palette.paperEdge.withValues(alpha: 0.9)),
                    boxShadow: [
                      BoxShadow(color: Palette.ink.withValues(alpha: 0.16), blurRadius: 12, offset: const Offset(0, 6)),
                      BoxShadow(color: Palette.ink.withValues(alpha: 0.10), blurRadius: 2, offset: const Offset(0, 1)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Stack(
                        children: [
                          StripePlaceholder(
                            color: widget.stripe,
                            caption: widget.caption,
                            aspectRatio: widget.aspectRatio,
                            stripeWidth: 9,
                            captionInset: 6,
                          ),
                          if (widget.badge != null) Positioned(top: 6, right: 6, child: widget.badge!),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.hand(size: 23, color: Palette.ink, weight: FontWeight.w700),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.label(size: 9.5),
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.tape)
                  Positioned(
                    top: -2,
                    child: TapeStrip(color: tapeColor, angle: -angle * 2.2),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
