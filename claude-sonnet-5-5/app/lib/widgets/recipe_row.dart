import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/palette.dart';
import '../core/theme/typography.dart';
import 'polaroid_card.dart';
import 'stripe_placeholder.dart';

/// Height of a [RecipeRow] at the default text size.
const double kRecipeRowExtent = 96;

/// The height of a [RecipeRow] for the person's text size, and how many lines
/// its title and meta line get. A row has a known height, so paginated lists can
/// keep the reader's place when they trim their window. At large text the title
/// and the meta line may wrap to two lines, and the height grows to hold them.
class RecipeRowMetrics {
  const RecipeRowMetrics._(this.extent, this.titleLines, this.metaLines);

  /// Text this much larger than the default gives the title and the meta line two lines.
  static const double wrapAt = 1.4;

  factory RecipeRowMetrics.of(BuildContext context) => RecipeRowMetrics.forScaler(MediaQuery.textScalerOf(context));

  factory RecipeRowMetrics.forScaler(TextScaler scaler) {
    final wrap = scaler.scale(18.5) >= 18.5 * wrapAt;
    final titleLines = wrap ? 2 : 1;
    final metaLines = wrap ? 2 : 1;
    final title = titleLines * scaler.scale(18.5) * 1.2;
    final meta = metaLines * scaler.scale(9.5) * 1.35;
    // The line under the meta is a note or a warning with an icon, never both.
    final under = math.max(scaler.scale(18) * 1.1, 2 + math.max(14, scaler.scale(10.5) * 1.35));
    const gaps = 3 + 2;
    const padding = 2 * 9;
    final content = title + meta + under + gaps + padding;
    return RecipeRowMetrics._(math.max(kRecipeRowExtent, content.ceilToDouble() + 1), titleLines, metaLines);
  }

  final double extent;
  final int titleLines;
  final int metaLines;
}

/// An index-card row: tilted striped thumbnail, title, meta line and a trailing action.
class RecipeRow extends StatelessWidget {
  const RecipeRow({
    super.key,
    required this.seed,
    required this.title,
    required this.meta,
    required this.stripe,
    this.note,
    this.trailing,
    this.warning,
    this.onTap,
  });

  final String seed;
  final String title;
  final String meta;
  final Color stripe;

  /// Handwritten line under the meta ("saved 3 days ago").
  final String? note;
  final Widget? trailing;

  /// Short safety note shown in coral (for example "contains dairy").
  final String? warning;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final metrics = RecipeRowMetrics.of(context);
    return Semantics(
      button: onTap != null,
      label: [title, meta, ?warning].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: metrics.extent,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
            child: Row(
              children: [
                Transform.rotate(
                  angle: polaroidAngle(seed),
                  child: Container(
                    width: 70,
                    height: 70,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Palette.paperLight,
                      border: Border.all(color: Palette.paperEdge),
                      boxShadow: [
                        BoxShadow(
                          color: Palette.ink.withValues(alpha: 0.14),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: StripePlaceholder(color: stripe, aspectRatio: null, stripeWidth: 6, border: false),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: metrics.titleLines,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.serifItalic(size: 18.5, weight: FontWeight.w500, height: 1.2),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        meta.toUpperCase(),
                        maxLines: metrics.metaLines,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.label(size: 9.5),
                      ),
                      if (warning != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 14, color: Palette.coralDeep),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  warning!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.mono(size: 10.5, color: Palette.coralDeep),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (note != null)
                        Text(
                          note!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.hand(size: 18, color: Palette.inkSoft),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) trailing! else const Icon(Icons.chevron_right, size: 20, color: Palette.inkFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
