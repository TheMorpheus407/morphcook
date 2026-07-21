import '../models/dish.dart';
import '../models/ingredient_node.dart';
import '../models/ontology.dart';
import '../models/profile.dart';
import '../models/recipe.dart';

/// Pure matching logic: set algebra over flags + profile constraints.
class MatchingEngine {
  final Ontology ontology;
  final IngredientDictionary ingredients;

  const MatchingEngine(this.ontology, this.ingredients);

  /// A recipe is visible when its contains-flags don't intersect the user's
  /// (expanded) avoid-flags, no avoided ingredient appears (with descendant
  /// propagation), required attributes are met, and the hard time/calorie
  /// filters pass.
  bool visible(Recipe recipe, UserProfile profile,
      {bool ignoreCalorieTarget = false, bool ignoreTimeBudget = false}) {
    final avoid = ontology.expandAvoidFlags(profile.avoidFlags);
    if (recipe.contains.intersection(avoid).isNotEmpty) return false;

    if (profile.avoidIngredients.isNotEmpty) {
      for (final ingredientId in recipe.ingredientIds) {
        for (final avoided in profile.avoidIngredients) {
          if (ingredients.isCoveredBy(ingredientId, avoided)) return false;
        }
      }
    }

    if (!recipe.attributes.containsAll(profile.requiredAttributes)) {
      return false;
    }

    if (!ignoreTimeBudget && recipe.timeMinutes > profile.maxTimeMinutes) {
      return false;
    }

    if (!ignoreCalorieTarget) {
      final delta =
          (recipe.caloriesPerServing - profile.calorieTarget).abs();
      if (delta > ontology.calorieTolerance) return false;
    }

    return true;
  }

  /// Scores a passing recipe for "best default variant" selection:
  /// match_count(required_attributes) → effort_match → time_closeness →
  /// calorie_closeness. Higher is better.
  int score(Recipe recipe, UserProfile profile) {
    var s = 0;
    s += recipe.attributes.intersection(profile.requiredAttributes).length *
        100000;
    if (recipe.effort == profile.preferredEffort) s += 10000;
    s -= (recipe.timeMinutes - profile.maxTimeMinutes).abs() * 10;
    s -= (recipe.caloriesPerServing - profile.calorieTarget).abs();
    return s;
  }

  /// Picks the highest-scoring visible variant of [dish], or null when none
  /// pass the profile.
  Recipe? bestVariant(Dish dish, Iterable<Recipe> variants,
      UserProfile profile) {
    Recipe? best;
    var bestScore = -1 << 30;
    for (final recipe in variants) {
      if (dish.id != recipe.dishId) continue;
      if (!visible(recipe, profile)) continue;
      final s = score(recipe, profile);
      if (s > bestScore) {
        bestScore = s;
        best = recipe;
      }
    }
    return best;
  }

  /// Time-aware + staleness-aware bonuses, applied after the base score.
  /// [lastCookedAt] is millis-since-epoch of the last cook event, or null.
  int contextBonus(Recipe recipe, DateTime now, int? lastCookedAt) {
    var bonus = 0;
    final hour = now.hour;
    if (hour >= 5 && hour < 11 && recipe.mealTypes.contains('breakfast')) {
      bonus += 200;
    }
    if (hour >= 17 && hour < 21 && recipe.mealTypes.contains('dinner')) {
      bonus += 90;
    }
    final isWeekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    if (isWeekend &&
        (recipe.effort == 'medium' || recipe.effort == 'hard')) {
      bonus += 90;
    }
    if (lastCookedAt != null) {
      final days = now
          .difference(DateTime.fromMillisecondsSinceEpoch(lastCookedAt))
          .inDays;
      if (days >= 30) bonus += 50;
    }
    return bonus;
  }

  /// Ranks visible variants across dishes for feed/ordering purposes.
  List<Recipe> rankVisible(
    Iterable<Recipe> candidates,
    UserProfile profile, {
    required DateTime now,
    Map<String, int> lastCookedAtByRecipe = const {},
  }) {
    final visibleOnes = candidates
        .where((r) => visible(r, profile))
        .toList(growable: false);
    visibleOnes.sort((a, b) {
      final sa = score(a, profile) +
          contextBonus(a, now, lastCookedAtByRecipe[a.id]);
      final sb = score(b, profile) +
          contextBonus(b, now, lastCookedAtByRecipe[b.id]);
      return sb.compareTo(sa);
    });
    return visibleOnes;
  }
}
