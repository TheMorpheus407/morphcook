import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../models/recipe.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/decor.dart';
import '../screens/dish_detail_screen.dart';

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
    final lang = state.lang;
    final s = S(lang);
    final dish = state.corpus.dishById(recipe.dishId);
    final stripe = dish == null
        ? MorphColors.teal
        : Color(int.parse(dish.stripe.replaceFirst('#', '0xFF')));

    return InkWell(
      onTap: onTap ??
          () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => DishDetailScreen(dishId: recipe.dishId))),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: MorphColors.card,
          border: Border.all(color: MorphColors.line),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 54,
              height: 54,
              child: StripedPlaceholder(color: stripe),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.title.of(lang).toLowerCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MorphText.display.copyWith(fontSize: 17)),
                  const SizedBox(height: 2),
                  Text(
                    '${recipe.timeMinutes} ${s('minutes')} · ${recipe.caloriesPerServing} kcal · ${state.corpus.ontology.nameOf(recipe.variant.effort, lang)}'
                        .toLowerCase(),
                    style: MorphText.label(size: 9),
                  ),
                ],
              ),
            ),
            if (state.profile.showVariantTags &&
                recipe.variant.diet != 'classic')
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  state.corpus.ontology.nameOf(recipe.variant.diet, lang),
                  style:
                      MorphText.hand.copyWith(fontSize: 15, color: MorphColors.teal),
                ),
              ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
