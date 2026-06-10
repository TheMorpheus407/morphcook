import '../models/ingredient.dart';
import '../models/ontology.dart';
import '../models/profile.dart';
import '../models/recipe.dart';

/// Pure visibility check for a single recipe against a profile.
///
/// A recipe is visible iff:
///  - recipe.contains ∩ expand(profile.avoidFlags) = ∅
///  - profile.avoidIngredients (and any descendants) ∩ recipe.ingredientIds = ∅
///  - profile.requiredAttributes ⊆ recipe.attributes
///  - recipe.timeMinutes ≤ profile.maxTimeMinutes (if set)
///  - |recipe.caloriesPerServing - profile.calorieTarget| ≤ tolerance (if target set)
bool isVisible(
  Recipe recipe,
  Profile profile, {
  required Ontology ontology,
  required IngredientTree ingredients,
  bool ignoreCalorieFilter = false,
}) {
  // 1. Expand compound avoid flags (vegan → all animal flags).
  final avoid = ontology.expand(profile.avoidFlags);
  for (final c in recipe.contains) {
    if (avoid.contains(c)) return false;
  }

  // 2. Specific ingredient avoidance — descendants propagate.
  final avoidedIngIds = <String>{};
  for (final id in profile.avoidIngredients) {
    avoidedIngIds.addAll(ingredients.descendantsOf(id));
    avoidedIngIds.add(id);
  }
  final recipeIngIds = recipe.ingredientIds;
  if (avoidedIngIds.intersection(recipeIngIds).isNotEmpty) return false;

  // 3. Required attributes (positive set).
  for (final r in profile.requiredAttributes) {
    if (!recipe.attributes.contains(r)) return false;
  }

  // 4. Time budget.
  if (profile.maxTimeMinutes != null &&
      recipe.timeMinutes > profile.maxTimeMinutes!) {
    return false;
  }

  // 5. Calorie target ± tolerance.
  if (!ignoreCalorieFilter &&
      profile.calorieTarget != null &&
      (recipe.caloriesPerServing - profile.calorieTarget!).abs() >
          profile.calorieTolerance) {
    return false;
  }

  return true;
}

/// Score a recipe against the profile. Higher is better.
///
/// Order of contributions:
///   match_count(required_attributes) > effort_match > time_closeness > calorie_closeness.
int baseScore(Recipe recipe, Profile profile) {
  var score = 0;

  // required attribute count
  for (final r in profile.requiredAttributes) {
    if (recipe.attributes.contains(r)) score += 1000;
  }

  // effort match
  if (profile.preferredEffort != null &&
      recipe.effort == profile.preferredEffort) {
    score += 400;
  }

  // time closeness (closer to budget without exceeding scores higher;
  // huge budget difference still adds to baseline)
  if (profile.maxTimeMinutes != null) {
    final diff = (profile.maxTimeMinutes! - recipe.timeMinutes).abs();
    score += (300 - (diff.clamp(0, 300))).toInt();
  }

  // calorie closeness
  if (profile.calorieTarget != null) {
    final diff = (recipe.caloriesPerServing - profile.calorieTarget!).abs();
    score += (200 - (diff.clamp(0, 200))).toInt();
  }

  return score;
}
