import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart';
import 'paper_widgets.dart';

class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.dish,
    required this.recipe,
    required this.onTap,
    this.compact = false,
    this.turns = -0.004,
    this.showDiet = true,
  });
  final Dish dish;
  final Recipe recipe;
  final VoidCallback onTap;
  final bool compact;
  final double turns;
  final bool showDiet;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Semantics(
      button: true,
      label: recipe.title.of(locale),
      child: InkWell(
        onTap: onTap,
        child: Polaroid(
          turns: turns,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DishArtwork(
                caption: dish.capCaption.of(locale),
                stripeColor: dish.stripeColor,
                height: compact ? 112 : 152,
              ),
              const SizedBox(height: 11),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title.of(locale),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 5),
                      Text(
                        recipe.summary.of(locale),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          context.l10n.t('minutes', {
                            'count': '${recipe.timeMinutes}',
                          }),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        Text(
                          '${recipe.caloriesPerServing} kcal',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        if (showDiet && recipe.diet != 'classic')
                          TagPill(recipe.diet, active: true),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
            ],
          ),
        ),
      ),
    );
  }
}

class RecipeListTile extends StatelessWidget {
  const RecipeListTile({
    super.key,
    required this.dish,
    required this.recipe,
    required this.onTap,
    this.trailing,
    this.subtitle,
  });
  final Dish dish;
  final Recipe recipe;
  final VoidCallback onTap;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 13),
      color: AppColors.paperLight.withValues(alpha: 0.76),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.muted.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 82,
                height: 88,
                child: DishArtwork(
                  caption: '',
                  stripeColor: dish.stripeColor,
                  figure: '·',
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title.of(locale),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle ??
                          '${recipe.timeMinutes} min · ${recipe.caloriesPerServing} kcal · ${recipe.effort}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
