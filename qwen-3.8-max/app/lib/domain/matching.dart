// Pure matching & variant-selection logic. Heavily tested.

import '../data/models.dart';
import '../data/profile.dart';

/// Calorie target is a hard filter with this tolerance (per meal).
const int calorieTolerance = 150;

/// Expand the profile's class-level avoid flags (compounds included) into
/// base contains-flags.
Set<String> expandedAvoidFlags(Profile profile, Ontology ontology) {
  final out = <String>{};
  for (final flag in profile.avoidFlags) {
    out.addAll(ontology.expandAvoidFlag(flag));
  }
  return out;
}

/// Expand specific ingredient avoidance down the dictionary tree: avoiding a
/// parent excludes all descendants.
Set<String> expandedAvoidIngredients(
    Profile profile, IngredientDictionary dictionary) {
  final out = <String>{};
  for (final id in profile.avoidIngredients) {
    final descendants = dictionary.descendantsOf(id);
    if (descendants.isEmpty) {
      out.add(id);
    } else {
      out.addAll(descendants);
    }
  }
  return out;
}

/// ```
/// visible(recipe, profile) :=
///     recipe.contains ∩ profile.avoid_flags = ∅
///     AND profile.avoid_ingredients ∩ recipe.ingredient_ids = ∅
///     AND profile.required_attributes ⊆ recipe.attributes
///     AND recipe.time_minutes ≤ profile.max_time_minutes
///     AND |recipe.calories_per_serving - profile.calorie_target| ≤ tolerance
/// ```
bool isRecipeVisible(
  Recipe recipe,
  Profile profile, {
  required Ontology ontology,
  required IngredientDictionary dictionary,
  bool overrideCalorieTarget = false,
}) {
  final avoidFlags = expandedAvoidFlags(profile, ontology);
  for (final flag in recipe.contains) {
    if (avoidFlags.contains(flag)) return false;
  }

  if (profile.avoidIngredients.isNotEmpty) {
    final avoidIngredients = expandedAvoidIngredients(profile, dictionary);
    for (final id in recipe.ingredientIds) {
      if (avoidIngredients.contains(id)) return false;
    }
  }

  for (final required in profile.requiredAttributes) {
    if (!recipe.attributes.contains(required)) return false;
  }

  final budget = profile.maxTimeMinutes;
  if (budget != null && recipe.timeMinutes > budget) return false;

  final target = profile.calorieTarget;
  if (!overrideCalorieTarget &&
      target != null &&
      (recipe.caloriesPerServing - target).abs() > calorieTolerance) {
    return false;
  }

  return true;
}

/// Which hard filters hide [recipe] — used for contextual UI copy.
List<String> visibilityReasons(
  Recipe recipe,
  Profile profile, {
  required Ontology ontology,
  required IngredientDictionary dictionary,
}) {
  final reasons = <String>[];
  final avoidFlags = expandedAvoidFlags(profile, ontology);
  for (final flag in recipe.contains) {
    if (avoidFlags.contains(flag)) reasons.add('flag:$flag');
  }
  if (profile.avoidIngredients.isNotEmpty) {
    final avoidIngredients = expandedAvoidIngredients(profile, dictionary);
    for (final id in recipe.ingredientIds) {
      if (avoidIngredients.contains(id)) reasons.add('ingredient:$id');
    }
  }
  for (final required in profile.requiredAttributes) {
    if (!recipe.attributes.contains(required)) reasons.add('missing:$required');
  }
  final budget = profile.maxTimeMinutes;
  if (budget != null && recipe.timeMinutes > budget) reasons.add('time');
  final target = profile.calorieTarget;
  if (target != null &&
      (recipe.caloriesPerServing - target).abs() > calorieTolerance) {
    reasons.add('calories');
  }
  return reasons;
}

const _effortOrder = {'easy': 0, 'medium': 1, 'hard': 2};

int _effortDistance(String a, String b) =>
    ((_effortOrder[a] ?? 1) - (_effortOrder[b] ?? 1)).abs();

/// Variant scoring when several variants of a dish pass the filters:
/// match_count(required_attributes) → effort_match → time_closeness →
/// calorie_closeness.
int variantScore(Recipe recipe, Profile profile) {
  var score = 0;

  var requiredMatches = 0;
  for (final required in profile.requiredAttributes) {
    if (recipe.attributes.contains(required)) requiredMatches++;
  }
  score += requiredMatches * 100000;

  score += (2 - _effortDistance(recipe.effort, profile.preferredEffort)) * 1000;

  final budget = profile.maxTimeMinutes ?? 60;
  final timeCloseness = 30 - ((recipe.timeMinutes - budget).abs() ~/ 5);
  score += timeCloseness * 10;

  final target = profile.calorieTarget ?? recipe.caloriesPerServing;
  final calorieCloseness =
      30 - (((recipe.caloriesPerServing - target).abs()) ~/ 25);
  score += calorieCloseness;

  return score;
}

/// Pick the variant of a dish that fits the profile best.
Recipe? bestVariant(List<Recipe> variants, Profile profile) {
  if (variants.isEmpty) return null;
  final ranked = [...variants]
    ..sort((a, b) => variantScore(b, profile).compareTo(variantScore(a, profile)));
  return ranked.first;
}
