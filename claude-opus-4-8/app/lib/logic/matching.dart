import '../models/ingredient_dict.dart';
import '../models/ontology.dart';
import '../models/profile.dart';
import '../models/recipe.dart';

/// Pure matching logic — the set algebra that decides whether a recipe is
/// visible for a profile. Heavily tested.
///
/// ```
/// visible(recipe, profile) :=
///     recipe.contains ∩ profile.avoid_flags = ∅
///     AND profile.avoid_ingredients ∩ recipe.ingredient_ids = ∅
///     AND profile.required_attributes ⊆ recipe.attributes
///     AND recipe.time_minutes ≤ profile.max_time_minutes
///     AND |recipe.calories - profile.calorie_target| ≤ tolerance
/// ```
class Matcher {
  Matcher({required this.ontology, required this.dict});

  final Ontology ontology;
  final IngredientDict dict;

  /// Build a reusable, profile-specific matcher (expansions computed once).
  ProfileMatcher forProfile(Profile profile) {
    return ProfileMatcher(
      profile: profile,
      avoidFlags: ontology.expandAvoidFlags(profile.avoidFlags),
      avoidIngredients: dict.expandAvoidedIngredients(profile.avoidIngredients),
    );
  }
}

class ProfileMatcher {
  ProfileMatcher({
    required this.profile,
    required this.avoidFlags,
    required this.avoidIngredients,
  });

  final Profile profile;

  /// Concrete contains-flags to exclude (compounds already expanded).
  final Set<String> avoidFlags;

  /// Specific ingredient ids to exclude (parents already propagated to leaves).
  final Set<String> avoidIngredients;

  /// `ignoreCalories` lets the dish-detail per-dish override show versions
  /// outside the calorie target.
  bool isVisible(Recipe recipe, {bool ignoreCalories = false}) {
    // 1. contains-flags must not intersect avoid-flags.
    if (recipe.contains.any(avoidFlags.contains)) return false;

    // 2. no specifically-avoided ingredient may appear.
    if (recipe.ingredientIds.any(avoidIngredients.contains)) return false;

    // 3. required attributes must all be present.
    if (!profile.requiredAttributes.every(recipe.attributes.contains)) {
      return false;
    }

    // 4. time budget (hard).
    final maxT = profile.maxTimeMinutes;
    if (maxT != null && recipe.timeMinutes > maxT) return false;

    // 5. calorie target (hard, with tolerance) unless overridden.
    if (!ignoreCalories &&
        profile.calorieFilterEnabled &&
        profile.calorieTarget != null) {
      final delta = (recipe.calories - profile.calorieTarget!).abs();
      if (delta > profile.calorieTolerance) return false;
    }
    return true;
  }

  /// Which individual checks fail — used to render the "why is this hidden"
  /// note on disabled variant chips.
  Set<MatchFailure> failures(Recipe recipe, {bool ignoreCalories = false}) {
    final out = <MatchFailure>{};
    if (recipe.contains.any(avoidFlags.contains)) out.add(MatchFailure.flag);
    if (recipe.ingredientIds.any(avoidIngredients.contains)) {
      out.add(MatchFailure.ingredient);
    }
    if (!profile.requiredAttributes.every(recipe.attributes.contains)) {
      out.add(MatchFailure.required);
    }
    final maxT = profile.maxTimeMinutes;
    if (maxT != null && recipe.timeMinutes > maxT) out.add(MatchFailure.time);
    if (!ignoreCalories &&
        profile.calorieFilterEnabled &&
        profile.calorieTarget != null &&
        (recipe.calories - profile.calorieTarget!).abs() >
            profile.calorieTolerance) {
      out.add(MatchFailure.calorie);
    }
    return out;
  }
}

enum MatchFailure { flag, ingredient, required, time, calorie }
