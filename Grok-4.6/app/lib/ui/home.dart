import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../models/dish.dart';
import '../models/recipe.dart';
import 'dish_detail.dart';
import 'strings.dart';
import 'theme.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final p = LedgerScope.colors(context);
    final dishes = state.corpus.dishes.where((d) {
      if (_category != null && d.category != _category) return false;
      return true;
    }).toList();

    Dish? featured;
    Recipe? featuredRecipe;
    for (final d in dishes) {
      final r = state.bestForDish(d);
      if (r != null) {
        featured = d;
        featuredRecipe = r;
        break;
      }
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 8),
            child: Masthead(name: state.profile.name, tagline: s('tagline')),
          ),
        ),
        if (featured != null && featuredRecipe != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: _Featured(
                dish: featured,
                recipe: featuredRecipe,
                label: s('featuredToday'),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(s('fromTheKitchen')),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      SoftChip(
                        label: s('allCategories'),
                        selected: _category == null,
                        onTap: () => setState(() => _category = null),
                      ),
                      const SizedBox(width: 6),
                      for (final c in state.corpus.categories) ...[
                        SoftChip(
                          label: c.name.of(state.lang),
                          selected: _category == c.id,
                          onTap: () => setState(() => _category = c.id),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final dish = dishes[i];
                final recipe = state.bestForDish(dish);
                final tilt = (i.isEven ? -1 : 1) * 0.018;
                return PolaroidCard(
                  tilt: tilt,
                  onTap: () => openDish(context, dish.id),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: StripeHero(
                          stripe: Color(dish.stripeColor.value),
                          caption: dish.caption.of(state.lang),
                          height: 110,
                          tilt: 0,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dish.name.of(state.lang),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (recipe != null && state.profile.showVariantTags)
                              Text(
                                '${recipe.timeMinutes} ${s('minutes')}  ·  ${recipe.caloriesPerServing} ${s('calories')}',
                                style: Theme.of(context).textTheme.labelSmall,
                              )
                            else if (recipe == null)
                              Text(
                                s('comboUnavailable'),
                                style: TextStyle(
                                  fontFamily: LedgerTheme.caveat,
                                  color: p.walnutFaint,
                                  fontSize: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
              childCount: dishes.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _Featured extends StatelessWidget {
  final Dish dish;
  final Recipe recipe;
  final String label;
  const _Featured({required this.dish, required this.recipe, required this.label});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => openDish(context, dish.id),
          child: StripeHero(
            stripe: Color(dish.stripeColor.value),
            caption: dish.hero.of(state.lang),
            height: 200,
            tilt: -0.012,
          ),
        ),
        const SizedBox(height: 10),
        Text(dish.name.of(state.lang), style: Theme.of(context).textTheme.displayMedium),
        Text(
          recipe.title.of(state.lang),
          style: const TextStyle(fontFamily: LedgerTheme.caveat, fontSize: 22),
        ),
      ],
    );
  }
}

void openDish(BuildContext context, String dishId, {String? recipeId}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => DishDetailScreen(dishId: dishId, initialRecipeId: recipeId),
    ),
  );
}
