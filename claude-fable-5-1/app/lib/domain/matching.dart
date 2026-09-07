// The matching algorithm. Pure functions, heavily tested.
//
//   visible(recipe, profile) :=
//       recipe.contains ∩ profile.avoid_flags = ∅
//       AND profile.avoid_ingredients ∩ recipe.ingredient_ids = ∅
//       AND profile.required_attributes ⊆ recipe.attributes
//       AND recipe.time_minutes ≤ profile.max_time_minutes
//       AND |recipe.calories_per_serving - profile.calorie_target| ≤ tolerance
import '../data/models/ingredient.dart';
import '../data/models/ontology.dart';
import '../data/models/profile.dart';
import '../data/models/recipe.dart';

enum HiddenReason { avoidFlag, avoidIngredient, missingAttribute, tooLong, caloriesOff }

/// Profile expanded against the ontology + dictionary once, then reused
/// for every recipe.
class MatchContext {
  MatchContext({
    required this.profile,
    required this.avoidFlags,
    required this.avoidIngredients,
  });

  factory MatchContext.from(Profile profile, Ontology ontology, IngredientDictionary dictionary) => MatchContext(
        profile: profile,
        avoidFlags: ontology.expandAvoidFlags(profile.avoidFlags),
        avoidIngredients: dictionary.expandAvoidance(profile.avoidIngredients),
      );

  final Profile profile;

  /// Leaf contains-flags to avoid (compounds already expanded).
  final Set<String> avoidFlags;

  /// Ingredient ids to avoid (subtrees already expanded).
  final Set<String> avoidIngredients;
}

class MatchResult {
  const MatchResult({
    required this.reasons,
    required this.conflictingFlags,
    required this.conflictingIngredients,
  });

  final List<HiddenReason> reasons;
  final Set<String> conflictingFlags;
  final Set<String> conflictingIngredients;

  bool get visible => reasons.isEmpty;

  /// Hidden only because of the calorie target (so the per-dish override
  /// would reveal it).
  bool get onlyCaloriesOff => reasons.length == 1 && reasons.first == HiddenReason.caloriesOff;

  /// Fails a hard avoidance (flag or ingredient), regardless of the rest.
  bool get conflictsWithAvoidance =>
      reasons.contains(HiddenReason.avoidFlag) || reasons.contains(HiddenReason.avoidIngredient);

  static const MatchResult ok = MatchResult(reasons: [], conflictingFlags: {}, conflictingIngredients: {});
}

MatchResult evaluate(
  Recipe recipe,
  MatchContext ctx, {
  bool ignoreCalories = false,
  bool ignoreTime = false,
}) {
  final reasons = <HiddenReason>[];
  final flags = recipe.contains.intersection(ctx.avoidFlags);
  if (flags.isNotEmpty) reasons.add(HiddenReason.avoidFlag);
  final ings = recipe.ingredientIds.intersection(ctx.avoidIngredients);
  if (ings.isNotEmpty) reasons.add(HiddenReason.avoidIngredient);
  final p = ctx.profile;
  if (!p.requiredAttributes.every(recipe.attributes.contains)) reasons.add(HiddenReason.missingAttribute);
  final maxTime = p.maxTimeMinutes;
  if (!ignoreTime && maxTime != null && recipe.timeMinutes > maxTime) reasons.add(HiddenReason.tooLong);
  final target = p.calorieTarget;
  if (!ignoreCalories && target != null && (recipe.caloriesPerServing - target).abs() > p.calorieTolerance) {
    reasons.add(HiddenReason.caloriesOff);
  }
  return MatchResult(reasons: reasons, conflictingFlags: flags, conflictingIngredients: ings);
}

bool isVisible(Recipe recipe, MatchContext ctx, {bool ignoreCalories = false}) =>
    evaluate(recipe, ctx, ignoreCalories: ignoreCalories).visible;

List<Recipe> visibleRecipes(Iterable<Recipe> recipes, MatchContext ctx, {bool ignoreCalories = false}) =>
    [for (final r in recipes) if (isVisible(r, ctx, ignoreCalories: ignoreCalories)) r];
