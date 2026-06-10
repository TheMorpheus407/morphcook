import 'package:flutter/material.dart';

import '../core/context_ext.dart';
import '../models/dish.dart';
import '../models/recipe.dart';
import '../screens/dish/dish_detail_screen.dart';
import '../theme/app_theme.dart';
import 'decor.dart';
import 'striped_placeholder.dart';

/// A polaroid-style card for one recipe variant. Used by the home feed, search
/// and the cookbook. Tapping opens the dish detail, pre-selected to this variant.
class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    required this.dish,
    this.rotation = -0.012,
    this.compact = false,
    this.trailing,
  });

  final Recipe recipe;
  final Dish dish;
  final double rotation;
  final bool compact;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final showTags = context.scope.services.profile.profile.showVariantTags;
    return PolaroidCard(
      rotation: rotation,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              DishDetailScreen(dishId: dish.id, initialRecipeId: recipe.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StripedPlaceholder(
            color: hexColor(dish.stripeColor),
            caption: context.loc(dish.capCaption),
            height: compact ? 96 : 150,
          ),
          const SizedBox(height: 8),
          Text(
            context.loc(recipe.name),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: Fonts.display,
              fontStyle: FontStyle.italic,
              fontSize: compact ? 18 : 21,
              color: AppColors.ink,
              height: 1.05,
            ),
          ),
          if (showTags) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final entry in recipe.variantAxes.entries)
                  _Tag(context.scope.corpus
                      .axisValueLabel(entry.key, entry.value, context.lang)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              MonoLabel('${recipe.timeMinutes} ${context.tr('common.minutes')}'),
              const SizedBox(width: 10),
              MonoLabel('${recipe.calories} ${context.tr('common.kcal')}'),
              const Spacer(),
              ?trailing,
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.inkFaint),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        label,
        style: const TextStyle(
            fontFamily: Fonts.mono, fontSize: 10, color: AppColors.inkSoft),
      ),
    );
  }
}
