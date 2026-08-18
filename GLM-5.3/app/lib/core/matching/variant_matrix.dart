import '../models/recipe.dart';

/// The per-dimension variant switcher model for the dish detail page
/// (the "money shot"): one row per dimension (diet, effort, calorie level),
/// each collapsed by default, chips revealed on tap. Unreachable
/// combinations are disabled with a note, never hidden (SPEC).
class VariantMatrix {
  VariantMatrix(this.recipes) {
    for (final recipe in recipes) {
      _diets.add(recipe.diet);
      _efforts.add(recipe.effort);
      _calories.add(recipe.calorieBucket);
    }
  }

  final List<Recipe> recipes;
  final Set<String> _diets = {};
  final Set<String> _efforts = {};
  final Set<String> _calories = {};

  /// Distinct diet values across the dish's variants, in corpus order.
  List<String> get diets => recipes.map((r) => r.diet).toSet().toList();

  List<String> get efforts => recipes.map((r) => r.effort).toSet().toList();

  List<String> get calorieBuckets => recipes.map((r) => r.calorieBucket).toSet().toList();

  /// The recipe matching the currently selected combination, or null.
  Recipe? resolve(String? diet, String? effort, String? calorieBucket) {
    for (final recipe in recipes) {
      if (diet != null && recipe.diet != diet) continue;
      if (effort != null && recipe.effort != effort) continue;
      if (calorieBucket != null && recipe.calorieBucket != calorieBucket) continue;
      return recipe;
    }
    return null;
  }

  /// Whether any recipe exists for the exact combination.
  bool exists({String? diet, String? effort, String? calorieBucket}) =>
      resolve(diet, effort, calorieBucket) != null;

  /// Whether choosing [value] on the diet dimension would still leave a
  /// reachable recipe given the other two current selections.
  bool dietReachable(String value, String? effort, String? calorieBucket) =>
      resolve(value, effort, calorieBucket) != null;

  bool effortReachable(String value, String? diet, String? calorieBucket) =>
      resolve(diet, value, calorieBucket) != null;

  bool calorieReachable(String value, String? diet, String? effort) =>
      resolve(diet, effort, value) != null;

  /// When the exact combination does not exist, relaxes one dimension at a
  /// time (calorie, then effort, then diet) to land on the nearest recipe —
  /// used when a dimension switch invalidates the current selection.
  Recipe? resolveNearest(String? diet, String? effort, String? calorieBucket) {
    return resolve(diet, effort, calorieBucket) ??
        resolve(diet, effort, null) ??
        resolve(diet, null, calorieBucket) ??
        resolve(null, effort, calorieBucket) ??
        resolve(diet, null, null) ??
        resolve(null, effort, null) ??
        resolve(null, null, calorieBucket) ??
        (recipes.isEmpty ? null : recipes.first);
  }

  /// Human note for a disabled combination ("no vegan × hard version yet").
  String noteFor({required String dimension, required String value}) => '$dimension:$value';
}
