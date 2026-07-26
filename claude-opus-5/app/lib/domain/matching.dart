import 'models.dart';
import 'profile.dart';

/// Why a recipe is not visible. Surfaced in the UI so "fewer recipes" is never
/// a mystery — the point of the product is that nothing silently disappears.
enum RejectionReason {
  containsAvoidedFlag,
  containsAvoidedIngredient,
  missingRequiredAttribute,
  overTimeBudget,
  outsideCalorieBand,
}

class MatchResult {
  const MatchResult({
    required this.visible,
    required this.rejections,
    required this.details,
  });

  static const MatchResult pass = MatchResult(
    visible: true,
    rejections: <RejectionReason>{},
    details: <String>{},
  );

  final bool visible;
  final Set<RejectionReason> rejections;

  /// Flag / ingredient / attribute ids that caused the rejection.
  final Set<String> details;
}

/// The whole engine. Pure, synchronous, no I/O — see test/matching_test.dart.
///
///     visible(recipe, profile) :=
///         recipe.contains ∩ profile.avoid_flags = ∅
///         AND profile.avoid_ingredients ∩ recipe.ingredient_ids = ∅
///         AND profile.required_attributes ⊆ recipe.attributes
///         AND recipe.time_minutes ≤ profile.max_time_minutes
///         AND |recipe.calories - profile.calorie_target| ≤ tolerance
class RecipeMatcher {
  RecipeMatcher({required this.ontology, required this.ingredients});

  final Ontology ontology;
  final IngredientDictionary ingredients;

  /// Precomputes the expanded avoid sets once per profile; expanding compound
  /// flags and walking the ingredient tree for every recipe would be wasteful.
  MatchContext contextFor(Profile profile, {bool ignoreCalorieTarget = false}) {
    return MatchContext(
      profile: profile,
      expandedFlags: ontology.expandAvoidFlags(profile.avoidFlags),
      expandedIngredients: ingredients.expandDownwards(
        profile.avoidIngredients,
      ),
      ignoreCalorieTarget: ignoreCalorieTarget,
    );
  }

  MatchResult evaluate(Recipe recipe, MatchContext ctx) {
    final rejections = <RejectionReason>{};
    final details = <String>{};

    final flagClash = recipe.contains.intersection(ctx.expandedFlags);
    if (flagClash.isNotEmpty) {
      rejections.add(RejectionReason.containsAvoidedFlag);
      details.addAll(flagClash);
    }

    final ingredientClash = recipe.ingredientIds.intersection(
      ctx.expandedIngredients,
    );
    if (ingredientClash.isNotEmpty) {
      rejections.add(RejectionReason.containsAvoidedIngredient);
      details.addAll(ingredientClash);
    }

    final missing = ctx.profile.requiredAttributes.difference(
      recipe.attributes,
    );
    if (missing.isNotEmpty) {
      rejections.add(RejectionReason.missingRequiredAttribute);
      details.addAll(missing);
    }

    if (recipe.timeMinutes > ctx.profile.maxTimeMinutes) {
      rejections.add(RejectionReason.overTimeBudget);
    }

    final target = ctx.profile.calorieTarget;
    if (!ctx.ignoreCalorieTarget && target != null) {
      final delta = (recipe.caloriesPerServing - target).abs();
      if (delta > ctx.profile.calorieTolerance) {
        rejections.add(RejectionReason.outsideCalorieBand);
      }
    }

    if (rejections.isEmpty) return MatchResult.pass;
    return MatchResult(
      visible: false,
      rejections: rejections,
      details: details,
    );
  }

  bool isVisible(Recipe recipe, MatchContext ctx) =>
      evaluate(recipe, ctx).visible;

  List<Recipe> filter(Iterable<Recipe> recipes, MatchContext ctx) =>
      recipes.where((r) => isVisible(r, ctx)).toList(growable: false);
}

class MatchContext {
  const MatchContext({
    required this.profile,
    required this.expandedFlags,
    required this.expandedIngredients,
    required this.ignoreCalorieTarget,
  });

  final Profile profile;
  final Set<String> expandedFlags;
  final Set<String> expandedIngredients;
  final bool ignoreCalorieTarget;

  MatchContext withCalorieOverride(bool ignore) => MatchContext(
    profile: profile,
    expandedFlags: expandedFlags,
    expandedIngredients: expandedIngredients,
    ignoreCalorieTarget: ignore,
  );
}
