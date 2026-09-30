import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/corpus_repository.dart';
import '../../i18n/strings.dart';
import '../../models/recipe.dart';
import '../../state/profile_controller.dart';
import '../theme.dart';
import 'common.dart';
import 'stripes.dart';

String recipeMeta(BuildContext context, Recipe r) {
  final tr = context.tr;
  return '${tr('dish.minutes', {'n': r.timeMinutes})} · ${tr('dish.kcal', {'n': r.calories})} · ${tr('effort.${r.effort}')}';
}

/// Diet tag, shown only when the profile's `show_variant_tags` is on and
/// the variant isn't the plain classic.
class DietTag extends StatelessWidget {
  const DietTag(this.recipe, {super.key, this.dark = false});
  final Recipe recipe;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final show = context.select<ProfileController, bool>((p) => p.profile.showVariantTags);
    if (!show || recipe.diet == 'classic') return const SizedBox.shrink();
    final onto = context.read<CorpusRepository>().ontology;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: MC.teal.withValues(alpha: dark ? 0.35 : 0.14),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        onto.dimensionValueLabel('diet', recipe.diet, context.lang),
        style: MT.mono(9.5, color: dark ? MC.nightInk : MC.tealDeep, weight: FontWeight.w500),
      ),
    );
  }
}

/// Polaroid card for grids.
class RecipePolaroid extends StatelessWidget {
  const RecipePolaroid({
    super.key,
    required this.dish,
    required this.recipe,
    required this.onTap,
    this.showCaption = false,
  });
  final Dish dish;
  final Recipe recipe;
  final VoidCallback onTap;
  final bool showCaption;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return Polaroid(
      tilt: tiltFor(recipe.id),
      onTap: onTap,
      semanticLabel: recipe.title.of(lang),
      image: StripedPlaceholder(
        color: dish.stripeColor,
        caption: dish.caption.of(lang),
        showCaption: showCaption,
        stripeWidth: 7,
      ),
      caption: Text(
        recipe.title.of(lang).toLowerCase(),
        style: MT.display(16.5),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(recipeMeta(context, recipe), style: MT.mono(9.5), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          DietTag(recipe),
        ],
      ),
    );
  }
}

/// Compact row for lists (search results, cookbook, pickers).
class RecipeRow extends StatelessWidget {
  const RecipeRow({
    super.key,
    required this.dish,
    required this.recipe,
    required this.onTap,
    this.trailing,
    this.note,
    this.dimmed = false,
  });

  final Dish dish;
  final Recipe recipe;
  final VoidCallback onTap;
  final Widget? trailing;
  final String? note;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Transform.rotate(
                angle: tiltFor(recipe.id, maxDegrees: 3),
                child: Container(
                  width: 62,
                  height: 62,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: MC.card,
                    boxShadow: [
                      BoxShadow(color: MC.ink.withValues(alpha: 0.1), blurRadius: 5, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: StripedPlaceholder(color: dish.stripeColor, showCaption: false, stripeWidth: 5),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title.of(lang).toLowerCase(),
                      style: MT.display(18),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(recipeMeta(context, recipe), style: MT.mono(10.5)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        DietTag(recipe),
                        if (note != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              note!,
                              style: MT.hand(16, color: MC.coralDeep),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class RecipeRowSkeleton extends StatelessWidget {
  const RecipeRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    child: Row(
      children: [
        SkeletonBox(width: 62, height: 62),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [SkeletonBox(height: 18, width: 180), SizedBox(height: 8), SkeletonBox(height: 10, width: 120)],
          ),
        ),
      ],
    ),
  );
}
