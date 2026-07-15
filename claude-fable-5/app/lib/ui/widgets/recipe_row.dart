import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../models/recipe.dart';
import '../strings.dart';
import '../theme.dart';
import '../screens/dish_detail_screen.dart';
import 'recipe_cover.dart';

/// Compact list row used by search, cookbook and pickers.
class RecipeRow extends StatelessWidget {
  final Recipe recipe;
  final int index;
  final VoidCallback? onTap;
  final Widget? trailing;

  const RecipeRow({
    super.key,
    required this.recipe,
    this.index = 0,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final morph = MorphTheme.of(context);
    final lang = state.lang;
    final s = S(lang);
    final dish = state.dishById(recipe.dishId);
    final stripe = dish == null
        ? morph.colors.teal
        : Color(int.parse(dish.stripe.replaceFirst('#', '0xFF')));

    return InkWell(
      onTap:
          onTap ??
          () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DishDetailScreen(dishId: recipe.dishId),
            ),
          ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: morph.colors.card,
          border: Border.all(color: morph.colors.line),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 54,
              height: 54,
              child: RecipeCover(
                recipeId: recipe.id,
                fallbackColor: stripe,
                height: 54,
                semanticLabel: recipe.title.of(lang),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    morph.cased(recipe.title.of(lang)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: morph.text.display.copyWith(fontSize: 17),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    morph.cased(
                      recipe.hasNutrition
                          ? '${recipe.timeMinutes} ${s('minutes')} · ${recipe.caloriesPerServing} kcal · ${state.corpus.ontology.nameOf(recipe.variant.effort, lang)}'
                          : '${recipe.timeMinutes} ${s('minutes')} · ${recipe.servings} ${s('servings')}',
                    ),
                    style: morph.text.label(size: 9),
                  ),
                ],
              ),
            ),
            if (state.isPersonalRecipe(recipe.id))
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  s('privateRecipe'),
                  style: morph.text.handAt(15, color: morph.colors.teal),
                ),
              )
            else if (state.profile.showVariantTags &&
                recipe.variant.diet != 'classic')
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  state.corpus.ontology.nameOf(recipe.variant.diet, lang),
                  style: morph.text.handAt(15, color: morph.colors.teal),
                ),
              ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
