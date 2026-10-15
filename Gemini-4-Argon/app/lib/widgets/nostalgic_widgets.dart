import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/dish.dart';
import '../models/ingredient_guide.dart';
import '../models/recipe.dart';
import '../services/matching_engine.dart';
import '../theme/nostalgic_theme.dart';

/// Wraps content in a warm parchment background with subtle organic paper grain.
class PaperGrainBackground extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;

  const PaperGrainBackground({
    super.key,
    required this.child,
    this.backgroundColor = NostalgicPalette.parchment,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: CustomPaint(
        painter: _PaperGrainPainter(),
        child: child,
      ),
    );
  }
}

class _PaperGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final speckPaint = Paint()
      ..color = NostalgicPalette.ink.withValues(alpha: 0.025)
      ..style = PaintingStyle.fill;
    final warmPaint = Paint()
      ..color = NostalgicPalette.terracotta.withValues(alpha: 0.018)
      ..style = PaintingStyle.fill;

    // Deterministic pseudo-random paper fibers
    final rng = math.Random(1998);
    final count = ((size.width * size.height) / 3800).clamp(35, 160).toInt();
    for (int i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = 0.6 + rng.nextDouble() * 1.1;
      canvas.drawCircle(
        Offset(x, y),
        r,
        i.isEven ? speckPaint : warmPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Vintage typewriter/cookbook dashed horizontal rule (`- - - - - -`).
class DashedRule extends StatelessWidget {
  final Color color;
  final double height;
  final double dashWidth;
  final double dashGap;
  final String? label;

  const DashedRule({
    super.key,
    this.color = NostalgicPalette.mutedRule,
    this.height = 1.0,
    this.dashWidth = 5.0,
    this.dashGap = 4.0,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (label == null || label!.isEmpty) {
      return SizedBox(
        height: height + 6,
        width: double.infinity,
        child: CustomPaint(
          painter: _DashedLinePainter(
            color: color,
            strokeWidth: height,
            dashWidth: dashWidth,
            dashGap: dashGap,
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: height + 6,
            child: CustomPaint(
              painter: _DashedLinePainter(
                color: color,
                strokeWidth: height,
                dashWidth: dashWidth,
                dashGap: dashGap,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label!.toLowerCase(),
            style: NostalgicTheme.mono(
              fontSize: 11,
              color: NostalgicPalette.fadedInk,
            ),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: height + 6,
            child: CustomPaint(
              painter: _DashedLinePainter(
                color: color,
                strokeWidth: height,
                dashWidth: dashWidth,
                dashGap: dashGap,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;

  const _DashedLinePainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashGap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final y = size.height / 2;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dashWidth, size.width), y),
        paint,
      );
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Striped SVG-style artwork placeholder with masking tape & Caveat handwritten caption.
class StripedPlaceholderArtwork extends StatelessWidget {
  final Color stripeColor;
  final String caption;
  final String? badgeText;
  final double height;
  final bool showPolaroidFrame;

  const StripedPlaceholderArtwork({
    super.key,
    required this.stripeColor,
    required this.caption,
    this.badgeText,
    this.height = 150,
    this.showPolaroidFrame = true,
  });

  @override
  Widget build(BuildContext context) {
    final artwork = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: NostalgicPalette.agedPaper,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: NostalgicPalette.ink.withValues(alpha: 0.15),
              width: 0.8,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: CustomPaint(
              painter: _StripedPlaceholderPainter(stripeColor: stripeColor),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: NostalgicPalette.cardStock.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: NostalgicPalette.ink.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    badgeText ?? '✦ kitchen plate ✦',
                    style: NostalgicTheme.mono(
                      fontSize: 10.5,
                      color: NostalgicPalette.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Masking tape strip on top
        Positioned(
          top: -7,
          left: 0,
          right: 0,
          child: Center(
            child: Transform.rotate(
              angle: -0.025,
              child: Container(
                width: 68,
                height: 15,
                decoration: BoxDecoration(
                  color: const Color(0xFFEADFC9).withValues(alpha: 0.88),
                  border: Border.all(
                    color: NostalgicPalette.mutedRule.withValues(alpha: 0.6),
                    width: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (!showPolaroidFrame) return artwork;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: BoxDecoration(
        color: NostalgicPalette.cardStock,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: NostalgicPalette.mutedRule, width: 0.9),
        boxShadow: [
          BoxShadow(
            color: NostalgicPalette.ink.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          artwork,
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: NostalgicTheme.handwritten(
                fontSize: 17,
                color: NostalgicPalette.fadedInk,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StripedPlaceholderPainter extends CustomPainter {
  final Color stripeColor;

  const _StripedPlaceholderPainter({required this.stripeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = stripeColor.withValues(alpha: 0.16);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final stripePaint = Paint()
      ..color = stripeColor.withValues(alpha: 0.42)
      ..strokeWidth = 9
      ..style = PaintingStyle.stroke;

    final thinPaint = Paint()
      ..color = stripeColor.withValues(alpha: 0.75)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const step = 22.0;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height * 0.65, size.height),
        stripePaint,
      );
      canvas.drawLine(
        Offset(x + 7, 0),
        Offset(x + 7 + size.height * 0.65, size.height),
        thinPaint,
      );
    }

    // Subtle inner botanical frame
    final frameRect = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    canvas.drawRect(
      frameRect,
      Paint()
        ..color = NostalgicPalette.cardStock.withValues(alpha: 0.55)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _StripedPlaceholderPainter oldDelegate) =>
      oldDelegate.stripeColor != stripeColor;
}

/// Polaroid-ish dish/recipe card with slight organic rotation and Tumblr-cookbook aesthetic.
class PolaroidDishCard extends StatelessWidget {
  final Dish dish;
  final Recipe variant;
  final String lang;
  final bool showVariantTag;
  final bool isSaved;
  final int rotationIndex;
  final VoidCallback onTap;
  final VoidCallback? onToggleSave;

  const PolaroidDishCard({
    super.key,
    required this.dish,
    required this.variant,
    required this.lang,
    this.showVariantTag = true,
    this.isSaved = false,
    this.rotationIndex = 0,
    required this.onTap,
    this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    // Slight organic polaroid rotation (-0.8 deg to +0.8 deg)
    final angles = [-0.011, 0.009, -0.007, 0.012];
    final angle = angles[rotationIndex % angles.length];

    return Transform.rotate(
      angle: angle,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          decoration: BoxDecoration(
            color: NostalgicPalette.cardStock,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: NostalgicPalette.mutedRule, width: 1),
            boxShadow: [
              BoxShadow(
                color: NostalgicPalette.ink.withValues(alpha: 0.07),
                blurRadius: 10,
                offset: const Offset(1, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StripedPlaceholderArtwork(
                stripeColor: dish.stripeColor,
                caption: dish.capCaption.resolve(lang),
                badgeText: showVariantTag
                    ? '${variant.dietDimension} & ${variant.effort}'
                    : dish.id,
                height: 118,
                showPolaroidFrame: false,
              ),
              const SizedBox(height: 8),
              Text(
                dish.capCaption.resolve(lang),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NostalgicTheme.handwritten(
                  fontSize: 16,
                  color: NostalgicPalette.fadedInk,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      variant.title.resolve(lang),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: NostalgicTheme.serifDisplay(
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  if (onToggleSave != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        isSaved ? Icons.bookmark : Icons.bookmark_border,
                        size: 20,
                        color: isSaved
                            ? NostalgicPalette.terracotta
                            : NostalgicPalette.fadedInk,
                      ),
                      onPressed: onToggleSave,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${variant.timeMinutes}m  ·  ~${variant.caloriesPerServing} kcal  ·  ${variant.effort}',
                style: NostalgicTheme.mono(
                  fontSize: 11,
                  color: NostalgicPalette.fadedInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Collapsible per-dimension variant switcher row ("the money shot" in SPEC.md):
/// `— diet ——————————————————— vegan ⌄`
/// Tap to reveal chips; unreachable combinations remain visible in a disabled
/// state with an explanatory note.
class DimensionVariantSwitcher extends StatefulWidget {
  final String dimensionLabel;
  final String activeValueLabel;
  final List<DimensionOptionState> options;
  final ValueChanged<Recipe> onSelectRecipe;
  final bool initiallyExpanded;

  const DimensionVariantSwitcher({
    super.key,
    required this.dimensionLabel,
    required this.activeValueLabel,
    required this.options,
    required this.onSelectRecipe,
    this.initiallyExpanded = false,
  });

  @override
  State<DimensionVariantSwitcher> createState() =>
      _DimensionVariantSwitcherState();
}

class _DimensionVariantSwitcherState extends State<DimensionVariantSwitcher> {
  late bool _expanded;
  String? _inspectedDisabledReason;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final disabledOptions =
        widget.options.where((o) => !o.isEnabled && o.disabledReason != null).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: ValueKey('dimension_row_${widget.dimensionLabel}'),
          onTap: () => setState(() {
            _expanded = !_expanded;
          }),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Text(
                  '— ${widget.dimensionLabel.toLowerCase()} ',
                  style: NostalgicTheme.mono(
                    fontSize: 12.5,
                    color: NostalgicPalette.fadedInk,
                  ),
                ),
                Expanded(
                  child: DashedRule(
                    color: NostalgicPalette.mutedRule.withValues(alpha: 0.9),
                    dashWidth: 4,
                    dashGap: 3,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: NostalgicPalette.agedPaper,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: NostalgicPalette.mutedRule),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.activeValueLabel.toLowerCase(),
                        style: NostalgicTheme.mono(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: NostalgicPalette.ink,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 16,
                        color: NostalgicPalette.ink,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(left: 10, bottom: 10, top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.options.map((opt) {
                    final selected = opt.isSelected;
                    final enabled = opt.isEnabled;

                    return GestureDetector(
                      onTap: () {
                        if (enabled && opt.bestMatchingRecipe != null) {
                          setState(() {
                            _inspectedDisabledReason = null;
                          });
                          widget.onSelectRecipe(opt.bestMatchingRecipe!);
                        } else if (opt.disabledReason != null) {
                          setState(() {
                            _inspectedDisabledReason = opt.disabledReason;
                          });
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? NostalgicPalette.terracotta
                              : (enabled
                                  ? NostalgicPalette.cardStock
                                  : NostalgicPalette.agedPaper
                                      .withValues(alpha: 0.45)),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: selected
                                ? NostalgicPalette.terracotta
                                : (enabled
                                    ? NostalgicPalette.ink.withValues(alpha: 0.4)
                                    : NostalgicPalette.mutedRule
                                        .withValues(alpha: 0.6)),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              selected ? '${opt.label} ●' : opt.label,
                              style: NostalgicTheme.mono(
                                fontSize: 11.5,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? NostalgicPalette.cardStock
                                    : (enabled
                                        ? NostalgicPalette.ink
                                        : NostalgicPalette.lightInk),
                              ),
                            ),
                            if (!enabled) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.block,
                                size: 12,
                                color: NostalgicPalette.lightInk,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (_inspectedDisabledReason != null ||
                    disabledOptions.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _inspectedDisabledReason ??
                        disabledOptions.first.disabledReason!,
                    style: NostalgicTheme.handwritten(
                      fontSize: 15.5,
                      color: NostalgicPalette.fadedInk,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Modal bottom sheet displaying the Kitchen Reference guide for an ingredient.
class IngredientLearnMoreSheet extends StatelessWidget {
  final IngredientGuideEntry entry;
  final String lang;

  const IngredientLearnMoreSheet({
    super.key,
    required this.entry,
    required this.lang,
  });

  static Future<void> show(
    BuildContext context, {
    required IngredientGuideEntry entry,
    required String lang,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: NostalgicPalette.parchment,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => IngredientLearnMoreSheet(entry: entry, lang: lang),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDe = lang == 'de';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: NostalgicPalette.mutedRule,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isDe ? 'küchen-lexikon & warenkunde' : 'kitchen reference & guide',
                style: NostalgicTheme.mono(
                  fontSize: 11,
                  color: NostalgicPalette.terracotta,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                entry.title.resolve(lang),
                style: NostalgicTheme.serifDisplay(fontSize: 26),
              ),
              const SizedBox(height: 4),
              Text(
                entry.category.resolve(lang),
                style: NostalgicTheme.handwritten(
                  fontSize: 18,
                  color: NostalgicPalette.sage,
                ),
              ),
              const SizedBox(height: 12),
              const DashedRule(),
              const SizedBox(height: 12),
              _section(
                title: isDe ? 'Charakter & Geschmack' : 'What It Is',
                body: entry.description.resolve(lang),
                icon: Icons.auto_stories_outlined,
              ),
              const SizedBox(height: 14),
              _section(
                title: isDe ? 'Küchentipps & Verwendung' : 'Kitchen Usage Tips',
                body: entry.usageTips.resolve(lang),
                icon: Icons.soup_kitchen_outlined,
              ),
              const SizedBox(height: 14),
              _section(
                title: isDe ? 'Aufbewahrung & Haltbarkeit' : 'Storage Guidance',
                body: entry.storageGuidance.resolve(lang),
                icon: Icons.inventory_2_outlined,
              ),
              const SizedBox(height: 14),
              _section(
                title: isDe ? 'Wo man es findet' : 'Where to Find It',
                body: entry.whereToFind.resolve(lang),
                icon: Icons.storefront_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required String body,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NostalgicPalette.cardStock,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: NostalgicPalette.mutedRule),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: NostalgicPalette.terracotta),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toLowerCase(),
                  style: NostalgicTheme.mono(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: NostalgicPalette.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: NostalgicTheme.serifBody(fontSize: 14.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
