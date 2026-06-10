import '../models/ingredient.dart';
import '../models/ontology.dart';
import '../models/profile.dart';
import '../models/recipe.dart';

/// Why a recipe is not visible — used for "no vegan × keto version yet" notes.
enum HiddenReason {
  avoidedFlag,
  avoidedIngredient,
  missingAttribute,
  overTimeBudget,
  outsideCalorieTarget,
}

/// Expands the profile's avoid-flags: compound flags (vegan, halal…) expand
/// to their atomic contains-flags; atomic flags pass through.
Set<String> expandAvoidFlags(Set<String> avoidFlags, Ontology ontology) {
  final expanded = <String>{};
  for (final flag in avoidFlags) {
    final compound = ontology.compound(flag);
    if (compound != null) {
      expanded.addAll(compound.expandsTo);
    } else {
      expanded.add(flag);
    }
  }
  return expanded;
}

/// The matching algorithm from SPEC.md — a pure function over sets.
///
/// visible(recipe, profile) :=
///     recipe.contains ∩ expand(profile.avoid_flags) = ∅
///     AND expand(profile.avoid_ingredients) ∩ recipe.ingredient_ids = ∅
///     AND profile.required_attributes ⊆ recipe.attributes
///     AND recipe.time_minutes ≤ profile.max_time_minutes
///     AND |recipe.calories_per_serving − profile.calorie_target| ≤ tolerance
class Matcher {
  final Ontology ontology;
  final IngredientDictionary dictionary;

  const Matcher({required this.ontology, required this.dictionary});

  /// All reasons [recipe] fails for [profile]; empty means visible.
  /// [ignoreCalories] implements the per-dish calorie override switch.
  List<HiddenReason> reasons(
    Recipe recipe,
    Profile profile, {
    bool ignoreCalories = false,
  }) {
    final out = <HiddenReason>[];

    final avoided = expandAvoidFlags(profile.avoidFlags, ontology);
    if (recipe.contains.intersection(avoided).isNotEmpty) {
      out.add(HiddenReason.avoidedFlag);
    }

    final avoidedIngredients =
        dictionary.expandAvoided(profile.avoidIngredients);
    if (recipe.ingredientIds.intersection(avoidedIngredients).isNotEmpty) {
      out.add(HiddenReason.avoidedIngredient);
    }

    if (!profile.requiredAttributes
        .every((attr) => recipe.attributes.contains(attr))) {
      out.add(HiddenReason.missingAttribute);
    }

    final maxTime = profile.maxTimeMinutes;
    if (maxTime != null && recipe.timeMinutes > maxTime) {
      out.add(HiddenReason.overTimeBudget);
    }

    final target = profile.calorieTarget;
    if (!ignoreCalories &&
        target != null &&
        (recipe.caloriesPerServing - target).abs() >
            Profile.calorieTolerance) {
      out.add(HiddenReason.outsideCalorieTarget);
    }

    return out;
  }

  bool isVisible(Recipe recipe, Profile profile,
          {bool ignoreCalories = false}) =>
      reasons(recipe, profile, ignoreCalories: ignoreCalories).isEmpty;

  /// True if the only thing hiding [recipe] is the calorie target —
  /// the per-dish override switch can reveal it.
  bool hiddenOnlyByCalories(Recipe recipe, Profile profile) {
    final r = reasons(recipe, profile);
    return r.length == 1 && r.single == HiddenReason.outsideCalorieTarget;
  }
}
