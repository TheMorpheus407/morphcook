import '../models/ingredient.dart';
import '../models/ontology.dart';
import '../models/profile.dart';
import '../models/recipe.dart';

/// Why a recipe is not visible to the current profile.
enum VisibilityReason {
  /// The recipe contains something the user avoids.
  containsFlag,

  /// The recipe uses an ingredient the user avoids.
  ingredient,

  /// The recipe misses a required attribute (e.g. `halal`).
  missingAttribute,

  /// The recipe takes longer than the user's time budget.
  tooSlow,

  /// The recipe is outside the user's calorie target.
  calorieTarget,

  /// The dish itself was not excluded — the variant simply is not available.
  available,
}

/// The outcome of evaluating one recipe against one profile.
class MatchResult {
  const MatchResult({
    required this.visible,
    this.reasons = const <VisibilityReason>[],
    this.conflictingFlags = const <String>{},
    this.conflictingIngredients = const <String>{},
    this.missingAttributes = const <String>{},
  });

  final bool visible;
  final List<VisibilityReason> reasons;
  final Set<String> conflictingFlags;
  final Set<String> conflictingIngredients;
  final Set<String> missingAttributes;

  bool get hasReason => reasons.isNotEmpty;

  /// The first reason, which is the most useful one to show.
  VisibilityReason get primaryReason =>
      reasons.isEmpty ? VisibilityReason.available : reasons.first;
}

/// The matching algorithm — a pure function of (recipe, profile).
///
/// Visibility is set logic, not a similarity score:
///
/// ```
/// recipe.contains ∩ expand(profile.avoid_flags)          = ∅
/// expand(profile.avoid_ingredients) ∩ recipe.ingredient_ids = ∅
/// profile.required_attributes ⊆ recipe.attribute_tokens    (⊆)
/// recipe.time_minutes ≤ profile.max_time_minutes
/// |recipe.calories − profile.calorie_target| ≤ tolerance
/// ```
class RecipeMatcher {
  RecipeMatcher({required this.ontology, required this.ingredients});

  final Ontology ontology;
  final IngredientTree ingredients;

  /// Expands the user's class-level avoid flags into primitive flags.
  Set<String> expandedAvoidFlags(Set<String> avoidFlags) =>
      ontology.expandAvoid(avoidFlags);

  /// Expands the user's specific ingredient avoidance into every descendant.
  Set<String> expandedAvoidIngredients(Set<String> avoidIngredientIds) =>
      ingredients.expandAvoidance(avoidIngredientIds);

  /// Evaluates a single recipe against a profile.
  MatchResult evaluate(Recipe recipe, Profile profile) {
    final reasons = <VisibilityReason>[];
    final conflictingFlags = <String>{};
    final conflictingIngredients = <String>{};
    final missingAttributes = <String>{};

    final avoidFlags = expandedAvoidFlags(profile.avoidFlags);
    final flagConflict = recipe.contains.intersection(avoidFlags);
    if (flagConflict.isNotEmpty) {
      reasons.add(VisibilityReason.containsFlag);
      conflictingFlags.addAll(flagConflict);
    }

    final avoidedIngredients = expandedAvoidIngredients(profile.avoidIngredients);
    if (avoidedIngredients.isNotEmpty) {
      final ingredientConflict =
          recipe.ingredientIds.intersection(avoidedIngredients);
      if (ingredientConflict.isNotEmpty) {
        reasons.add(VisibilityReason.ingredient);
        conflictingIngredients.addAll(ingredientConflict);
      }
    }

    if (profile.requiredAttributes.isNotEmpty) {
      final tokens = recipe.attributeTokens;
      final missing = profile.requiredAttributes.difference(tokens);
      if (missing.isNotEmpty) {
        reasons.add(VisibilityReason.missingAttribute);
        missingAttributes.addAll(missing);
      }
    }

    if (recipe.timeMinutes > profile.maxTimeMinutes) {
      reasons.add(VisibilityReason.tooSlow);
    }

    if (!_withinCalorieTarget(recipe, profile)) {
      reasons.add(VisibilityReason.calorieTarget);
    }

    return MatchResult(
      visible: reasons.isEmpty,
      reasons: List<VisibilityReason>.unmodifiable(reasons),
      conflictingFlags: conflictingFlags,
      conflictingIngredients: conflictingIngredients,
      missingAttributes: missingAttributes,
    );
  }

  bool _withinCalorieTarget(Recipe recipe, Profile profile) {
    final delta = (recipe.calories - profile.calorieTarget).abs();
    return delta <= profile.calorieTolerance;
  }

  /// True when the recipe is visible to the profile.
  bool isVisible(Recipe recipe, Profile profile) =>
      evaluate(recipe, profile).visible;

  /// Filters a list down to the recipes the profile can see.
  List<Recipe> filter(Iterable<Recipe> recipes, Profile profile) {
    return recipes.where((recipe) => isVisible(recipe, profile)).toList();
  }

  /// Whether the recipe is visible when the dish's calorie override is on.
  ///
  /// The override relaxes *only* the calorie filter — dietary and time
  /// filters always apply.
  bool isVisibleWithCalorieOverride(
    Recipe recipe,
    Profile profile, {
    required bool allowOutsideCalorieTarget,
  }) {
    if (!allowOutsideCalorieTarget) return isVisible(recipe, profile);
    final result = evaluate(recipe, profile);
    return result.reasons.every(
      (reason) => reason == VisibilityReason.calorieTarget,
    );
  }

  /// Scores how well a variant satisfies the profile.
  ///
  /// The order is fixed by the spec: required attributes first, then effort
  /// match, then time closeness, then calorie closeness.
  double variantScore(Recipe recipe, Profile profile) {
    var score = 0.0;

    final tokens = recipe.attributeTokens;
    for (final required in profile.requiredAttributes) {
      if (tokens.contains(required)) score += 1000;
    }

    if (recipe.effort == profile.preferredEffort) score += 500;

    final timeGap = (recipe.timeMinutes - profile.maxTimeMinutes).abs();
    score += (120 - timeGap).clamp(0, 120).toDouble();

    final calorieGap = (recipe.calories - profile.calorieTarget).abs();
    final tolerance = profile.calorieTolerance <= 0 ? 1 : profile.calorieTolerance;
    score += (100 - (calorieGap / tolerance) * 40).clamp(0, 100).toDouble();

    return score;
  }

  /// Picks the best-scoring variant of a dish for this profile.
  ///
  /// Returns `null` when no variant passes the filters.
  Recipe? bestVariant(
    List<Recipe> variants,
    Profile profile, {
    bool allowOutsideCalorieTarget = false,
  }) {
    final visible = variants
        .where(
          (recipe) => isVisibleWithCalorieOverride(
            recipe,
            profile,
            allowOutsideCalorieTarget: allowOutsideCalorieTarget,
          ),
        )
        .toList();

    if (visible.isEmpty) return null;

    visible.sort((a, b) {
      final byScore = variantScore(b, profile).compareTo(
        variantScore(a, profile),
      );
      if (byScore != 0) return byScore;
      return a.title.resolve('en').compareTo(b.title.resolve('en'));
    });
    return visible.first;
  }
}
