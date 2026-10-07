import 'model/ingredient.dart';
import 'model/ontology.dart';
import 'model/profile.dart';
import 'model/recipe.dart';

/// Hard calorie filter tolerance: |recipe kcal − profile target| ≤ tolerance.
const int calorieTolerance = 150;

/// The matching algorithm — a pure function, heavily tested.
///
/// ```
/// visible(recipe, profile) :=
///     recipe.contains ∩ profile.avoid_flags = ∅
///     AND profile.avoid_ingredients ∩ recipe.ingredient_ids = ∅
///     AND profile.required_attributes ⊆ recipe.attributes
///     AND recipe.time_minutes ≤ profile.max_time_minutes
///     AND |recipe.calories_per_serving − profile.calorie_target| ≤ tolerance
/// ```
class Matcher {
  final Ontology ontology;
  final IngredientDictionary ingredients;

  const Matcher({required this.ontology, required this.ingredients});

  /// Expanded class-level avoid-flags (compound flags resolved).
  Set<String> expandedAvoidFlags(UserProfile profile) =>
      ontology.expandAvoidFlags(profile.avoidFlags);

  /// Expanded specific-avoidance ids (tree propagation to descendants).
  Set<String> expandedAvoidIngredients(UserProfile profile) =>
      ingredients.expandAvoidance(profile.avoidIngredients);

  bool isVisible(Recipe recipe, UserProfile profile, {bool ignoreCalorieTarget = false}) {
    final avoidFlags = expandedAvoidFlags(profile);
    if (recipe.contains.intersection(avoidFlags).isNotEmpty) return false;

    final avoidIngredients = expandedAvoidIngredients(profile);
    if (recipe.ingredientIds.intersection(avoidIngredients).isNotEmpty) return false;

    if (!profile.requiredAttributes.every(recipe.attributes.contains)) {
      return false;
    }

    if (recipe.timeMinutes > profile.maxTimeMinutes) return false;

    if (!ignoreCalorieTarget) {
      final delta = (recipe.caloriesPerServing - profile.calorieTarget).abs();
      if (delta > calorieTolerance) return false;
    }
    return true;
  }

  List<Recipe> visibleVariants(List<Recipe> recipes, UserProfile profile,
      {bool ignoreCalorieTarget = false}) {
    return recipes
        .where((r) => isVisible(r, profile, ignoreCalorieTarget: ignoreCalorieTarget))
        .toList();
  }

  /// Lexicographic scoring for picking the best variant of a dish:
  /// match_count(required_attributes) → effort_match → time_closeness →
  /// calorie_closeness. Higher is better at every step.
  VariantScore score(Recipe recipe, UserProfile profile) {
    final requiredMatches =
        profile.requiredAttributes.intersection(recipe.attributes).length;
    final effortMatch = recipe.effort == profile.preferredEffort ? 1 : 0;
    // More headroom under the time budget scores higher.
    final timeCloseness = profile.maxTimeMinutes - recipe.timeMinutes;
    // Closer to the calorie target scores higher.
    final calorieCloseness =
        calorieTolerance - (recipe.caloriesPerServing - profile.calorieTarget).abs();
    return VariantScore(
      requiredMatches: requiredMatches,
      effortMatch: effortMatch,
      timeCloseness: timeCloseness,
      calorieCloseness: calorieCloseness,
    );
  }

  /// The variant of a dish the profile would want by default. When several
  /// variants pass, the highest score wins; ties break on recipe id for
  /// determinism.
  Recipe? pickBest(List<Recipe> variants, UserProfile profile,
      {bool ignoreCalorieTarget = false}) {
    final visible = visibleVariants(variants, profile,
        ignoreCalorieTarget: ignoreCalorieTarget);
    if (visible.isEmpty) return null;
    visible.sort((a, b) {
      final byScore = score(b, profile).compareTo(score(a, profile));
      if (byScore != 0) return byScore;
      return a.id.compareTo(b.id);
    });
    return visible.first;
  }

  /// Rank a list of recipes for the feed. Base ranking first, then the
  /// time-aware and staleness-aware bonuses are applied.
  List<Recipe> rank(
    List<Recipe> recipes,
    UserProfile profile, {
    DateTime? now,
    Map<String, DateTime> lastCookedByRecipe = const {},
    bool ignoreCalorieTarget = false,
  }) {
    final at = now ?? DateTime.now();
    final scored = <(Recipe, int)>[];
    for (final recipe in recipes) {
      if (!isVisible(recipe, profile, ignoreCalorieTarget: ignoreCalorieTarget)) {
        continue;
      }
      final base = score(recipe, profile);
      final bonus = timeAwareBonus(recipe, at) + stalenessBonus(recipe, lastCookedByRecipe, at);
      final total = base.toComparable() * 1000 + bonus;
      scored.add((recipe, total));
    }
    scored.sort((a, b) {
      if (b.$2 != a.$2) return b.$2.compareTo(a.$2);
      return a.$1.id.compareTo(b.$1.id);
    });
    return scored.map((e) => e.$1).toList();
  }

  /// Morning context (5am–11am): breakfast +200. Evening context (5pm–9pm):
  /// dinner +90. Weekend: medium and hard effort +90. The bonuses stack.
  int timeAwareBonus(Recipe recipe, DateTime now) {
    var bonus = 0;
    final hour = now.hour;
    if (hour >= 5 && hour < 11 && recipe.mealType == 'breakfast') bonus += 200;
    if (hour >= 17 && hour < 21 && recipe.mealType == 'dinner') bonus += 90;
    final weekend = now.weekday >= 6;
    if (weekend && (recipe.effort == 'medium' || recipe.effort == 'hard')) bonus += 90;
    return bonus;
  }

  /// Recipes not cooked in 30+ days get a +50 bonus to encourage variety.
  /// Recently cooked or never-cooked recipes get no bonus.
  int stalenessBonus(Recipe recipe, Map<String, DateTime> lastCookedByRecipe, DateTime now) {
    final last = lastCookedByRecipe[recipe.id];
    if (last == null) return 0;
    if (now.difference(last).inDays >= 30) return 50;
    return 0;
  }
}

/// Lexicographic variant score. Compared field by field, in order.
class VariantScore implements Comparable<VariantScore> {
  final int requiredMatches;
  final int effortMatch;
  final num timeCloseness;
  final num calorieCloseness;

  const VariantScore({
    required this.requiredMatches,
    required this.effortMatch,
    required this.timeCloseness,
    required this.calorieCloseness,
  });

  @override
  int compareTo(VariantScore other) {
    if (requiredMatches != other.requiredMatches) {
      return requiredMatches.compareTo(other.requiredMatches);
    }
    if (effortMatch != other.effortMatch) {
      return effortMatch.compareTo(other.effortMatch);
    }
    if (timeCloseness != other.timeCloseness) {
      return timeCloseness.compareTo(other.timeCloseness);
    }
    return calorieCloseness.compareTo(other.calorieCloseness);
  }

  /// Fold into a single comparable number (order-preserving given bounded
  /// inputs; used only for the feed's combined base + bonus ranking).
  int toComparable() =>
      requiredMatches * 1000000 + effortMatch * 10000 + timeCloseness.round() * 100 + calorieCloseness.round();
}
