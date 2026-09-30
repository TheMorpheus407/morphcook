import '../data/models/ingredient.dart';
import '../data/models/ontology.dart';
import '../data/models/profile.dart';
import '../data/models/recipe.dart';

/// Why a recipe is hidden for a profile.
enum MatchFailure { avoidFlag, avoidIngredient, requiredAttribute, timeBudget, calorieTarget }

class MatchResult {
  const MatchResult({
    this.failures = const <MatchFailure>{},
    this.blockingFlags = const <String>{},
    this.blockingIngredients = const <String>{},
    this.missingAttributes = const <String>{},
  });

  final Set<MatchFailure> failures;

  /// Contains-flags that intersect the profile's (expanded) avoid-flags.
  final Set<String> blockingFlags;

  /// Ingredient ids that intersect the profile's (expanded) avoided ingredients.
  final Set<String> blockingIngredients;

  /// Required attributes the recipe lacks.
  final Set<String> missingAttributes;

  bool get visible => failures.isEmpty;

  /// What clashes with the profile, named the way a cook thinks about it: the
  /// recipe's own ingredients ("lamb shoulder", "plain yogurt"). Flags that no
  /// ingredient explains, such as the derived meat and dairy combination, fall
  /// back to their own name.
  List<String> clashLabels(Recipe recipe, Ontology ontology, IngredientDictionary ingredients, String lang) {
    final names = <String>{};
    final explained = <String>{};
    for (final line in recipe.ingredients) {
      final flags = ontology.flagClosureUp(ingredients.effectiveFlags(line.id));
      explained.addAll(flags);
      if (blockingIngredients.contains(line.id) || flags.any(blockingFlags.contains)) {
        names.add(ingredients.nameOf(line.id, lang));
      }
    }
    for (final flag in blockingFlags) {
      if (!explained.contains(flag)) names.add(ontology.label(flag, lang));
    }
    return names.toList();
  }
}

/// A profile compiled for repeated matching: compound flags and ingredient
/// subtrees are expanded once and reused for every recipe.
///
/// ```
/// visible(recipe, profile) :=
///     recipe.contains ∩ profile.avoid_flags = ∅
///     AND profile.avoid_ingredients ∩ recipe.ingredient_ids = ∅
///     AND profile.required_attributes ⊆ recipe.attributes
///     AND recipe.time_minutes ≤ profile.max_time_minutes
///     AND |recipe.calories_per_serving - profile.calorie_target| ≤ tolerance
/// ```
class ProfileFilter {
  ProfileFilter._({
    required this.profile,
    required this.ontology,
    required this.avoidFlags,
    required this.avoidIngredients,
  });

  factory ProfileFilter.compile(Profile profile, Ontology ontology, IngredientDictionary ingredients) {
    return ProfileFilter._(
      profile: profile,
      ontology: ontology,
      avoidFlags: ontology.expandAvoidFlags(profile.avoidFlags),
      avoidIngredients: ingredients.expandAvoid(profile.avoidIngredients),
    );
  }

  final Profile profile;
  final Ontology ontology;

  /// Compound shortcuts and flag descendants already expanded.
  final Set<String> avoidFlags;

  /// Avoided ingredient ids with all their descendants.
  final Set<String> avoidIngredients;

  /// Evaluates every rule. Set [ignoreCalories] for the per-dish override that
  /// shows versions outside the calorie target.
  MatchResult evaluate(RecipeMeta recipe, {bool ignoreCalories = false}) {
    final failures = <MatchFailure>{};

    // A recipe that lists `almonds` also carries `tree-nuts` for matching.
    final blockingFlags = avoidFlags.isEmpty
        ? const <String>{}
        : ontology.flagClosureUp(recipe.contains).intersection(avoidFlags);
    if (blockingFlags.isNotEmpty) failures.add(MatchFailure.avoidFlag);

    final blockingIngredients = avoidIngredients.isEmpty
        ? const <String>{}
        : recipe.ingredientIds.intersection(avoidIngredients);
    if (blockingIngredients.isNotEmpty) failures.add(MatchFailure.avoidIngredient);

    final missing = profile.requiredAttributes.isEmpty
        ? const <String>{}
        : profile.requiredAttributes.difference(recipe.attributes);
    if (missing.isNotEmpty) failures.add(MatchFailure.requiredAttribute);

    final budget = profile.maxTimeMinutes;
    if (budget != null && recipe.timeMinutes > budget) failures.add(MatchFailure.timeBudget);

    final target = profile.calorieTarget;
    if (!ignoreCalories && target != null && (recipe.caloriesPerServing - target).abs() > profile.calorieTolerance) {
      failures.add(MatchFailure.calorieTarget);
    }

    return MatchResult(
      failures: failures,
      blockingFlags: blockingFlags,
      blockingIngredients: blockingIngredients,
      missingAttributes: missing,
    );
  }

  bool isVisible(RecipeMeta recipe, {bool ignoreCalories = false}) =>
      evaluate(recipe, ignoreCalories: ignoreCalories).visible;

  /// Only the safety rules (allergens and avoided ingredients), used to warn
  /// about saved recipes that no longer fit a changed profile.
  bool isSafe(RecipeMeta recipe) {
    final result = evaluate(recipe, ignoreCalories: true);
    return !result.failures.contains(MatchFailure.avoidFlag) && !result.failures.contains(MatchFailure.avoidIngredient);
  }

  Iterable<T> filter<T extends RecipeMeta>(Iterable<T> recipes, {bool ignoreCalories = false}) sync* {
    for (final recipe in recipes) {
      if (isVisible(recipe, ignoreCalories: ignoreCalories)) yield recipe;
    }
  }
}

/// The matching algorithm as a plain pure function.
bool isRecipeVisible(
  RecipeMeta recipe,
  Profile profile,
  Ontology ontology,
  IngredientDictionary ingredients, {
  bool ignoreCalories = false,
}) {
  return ProfileFilter.compile(profile, ontology, ingredients).isVisible(recipe, ignoreCalories: ignoreCalories);
}
