// Time-aware + staleness-aware ranking for the home feed.

import '../data/models.dart';
import '../data/profile.dart';
import 'matching.dart';

class RankingContext {
  final DateTime now;
  final Map<String, DateTime> lastCooked; // recipeId -> last cooked at

  const RankingContext({required this.now, required this.lastCooked});

  bool get isWeekend =>
      now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;

  bool get isMorning => now.hour >= 5 && now.hour < 11;
  bool get isEvening => now.hour >= 17 && now.hour < 21;
}

/// Base score from dish popularity tier (tier 1 = most used).
int baseScore(Dish dish) => (4 - dish.frequencyTier) * 40;

/// Morning context (5am–11am): breakfast recipes +200.
/// Evening context (5pm–9pm): dinner recipes +90.
/// Weekend context: medium and hard effort recipes +90.
int timeOfDayBonus(Recipe recipe, RankingContext ctx) {
  var bonus = 0;
  if (ctx.isMorning && recipe.mealSlots.contains('breakfast')) bonus += 200;
  if (ctx.isEvening && recipe.mealSlots.contains('dinner')) bonus += 90;
  if (ctx.isWeekend &&
      (recipe.effort == 'medium' || recipe.effort == 'hard')) {
    bonus += 90;
  }
  return bonus;
}

/// Recipes not cooked in 30+ days get +50 to encourage variety.
/// Recently cooked or never-cooked recipes receive no bonus.
int stalenessBonus(Recipe recipe, RankingContext ctx) {
  final last = ctx.lastCooked[recipe.id];
  if (last == null) return 0;
  final days = ctx.now.difference(last).inDays;
  return days >= 30 ? 50 : 0;
}

int rankRecipe(
  Recipe recipe,
  Dish dish,
  Profile profile,
  RankingContext ctx,
) {
  var score = baseScore(dish);
  score += variantScore(recipe, profile) ~/ 100;
  score += timeOfDayBonus(recipe, ctx);
  score += stalenessBonus(recipe, ctx);
  return score;
}

/// Rank the best visible variant of every dish; returns dishes that have at
/// least one visible variant, best variant first.
List<({Dish dish, Recipe recipe, int score})> rankDishes({
  required Iterable<Dish> dishes,
  required List<Recipe> Function(Dish dish) allVariants,
  required Profile profile,
  required RankingContext ctx,
  required Ontology ontology,
  required IngredientDictionary dictionary,
}) {
  final out = <({Dish dish, Recipe recipe, int score})>[];
  for (final dish in dishes) {
    final visible = allVariants(dish)
        .where((r) => isRecipeVisible(r, profile,
            ontology: ontology, dictionary: dictionary))
        .toList();
    if (visible.isEmpty) continue;
    final best = bestVariant(visible, profile)!;
    out.add((
      dish: dish,
      recipe: best,
      score: rankRecipe(best, dish, profile, ctx),
    ));
  }
  out.sort((a, b) => b.score.compareTo(a.score));
  return out;
}
