import '../data/corpus.dart';
import '../models/profile.dart';
import '../models/recipe.dart';

/// The tiny slice of ontology + dictionary surface the matcher needs; backed
/// by [Corpus] in the app and stubbed directly in tests.
class OntologyRef {
  OntologyRef({required this.expandAvoidFlags, required this.expandAvoidIngredients});

  final Set<String> Function(Set<String> flags) expandAvoidFlags;
  final Set<String> Function(Set<String> ids) expandAvoidIngredients;

  factory OntologyRef.fromCorpus(Corpus corpus) => OntologyRef(
        expandAvoidFlags: corpus.ontology.expandAll,
        expandAvoidIngredients: corpus.ingredients.expandAvoidSet,
      );
}

/// The pure matching function, heavily tested (SPEC):
///
/// ```
/// visible(recipe, profile) :=
///     recipe.contains ∩ profile.avoid_flags = ∅
///     AND profile.avoid_ingredients ∩ recipe.ingredient_ids = ∅
///     AND profile.required_attributes ⊆ recipe.attributes
///     AND recipe.time_minutes ≤ profile.max_time_minutes
///     AND |recipe.calories_per_serving - profile.calorie_target| ≤ tolerance
/// ```
class Matcher {
  const Matcher();

  /// Full visibility check. [ignoreCalorieFilter] implements the per-dish
  /// calorie override switch on the dish page.
  bool isVisible(
    Recipe recipe,
    Profile profile,
    OntologyRef ontology, {
    bool ignoreCalorieFilter = false,
  }) {
    // 1. contains-flags must not intersect the expanded avoid set.
    final avoided = ontology.expandAvoidFlags(profile.avoidFlags);
    for (final flag in recipe.contains) {
      if (avoided.contains(flag)) return false;
    }
    // 2. no specifically avoided ingredient (incl. tree descendants).
    final avoidIngredients = ontology.expandAvoidIngredients(profile.avoidIngredients);
    for (final id in recipe.ingredientIds) {
      if (avoidIngredients.contains(id)) return false;
    }
    // 3. positive attribute requirements.
    for (final requiredAttr in profile.requiredAttributes) {
      if (!recipe.attributeSet.contains(requiredAttr)) return false;
    }
    // 4. hard time budget.
    if (profile.maxTimeMinutes != null && recipe.timeMinutes > profile.maxTimeMinutes!) {
      return false;
    }
    // 5. hard calorie target ± tolerance (per-dish override optional).
    if (!ignoreCalorieFilter && profile.calorieTarget != null) {
      final distance = (recipe.cal - profile.calorieTarget!).abs();
      if (distance > Profile.calorieTolerance) return false;
    }
    return true;
  }

  /// Filters a list of recipes down to the visible ones.
  List<Recipe> visible(
    List<Recipe> recipes,
    Profile profile,
    OntologyRef ontology, {
    bool ignoreCalorieFilter = false,
  }) {
    return recipes
        .where((r) => isVisible(r, profile, ontology, ignoreCalorieFilter: ignoreCalorieFilter))
        .toList();
  }

  /// Which rule kills a recipe — used for the "why is this hidden?" notes.
  /// Returns null when the recipe is visible.
  String? blockingReason(Recipe recipe, Profile profile, OntologyRef ontology) {
    final avoided = ontology.expandAvoidFlags(profile.avoidFlags);
    for (final flag in recipe.contains) {
      if (avoided.contains(flag)) return 'flag:$flag';
    }
    final avoidIngredients = ontology.expandAvoidIngredients(profile.avoidIngredients);
    for (final id in recipe.ingredientIds) {
      if (avoidIngredients.contains(id)) return 'ingredient:$id';
    }
    for (final requiredAttr in profile.requiredAttributes) {
      if (!recipe.attributeSet.contains(requiredAttr)) return 'attribute:$requiredAttr';
    }
    if (profile.maxTimeMinutes != null && recipe.timeMinutes > profile.maxTimeMinutes!) {
      return 'time';
    }
    if (profile.calorieTarget != null) {
      final distance = (recipe.cal - profile.calorieTarget!).abs();
      if (distance > Profile.calorieTolerance) return 'calorie';
    }
    return null;
  }
  /// Picks the best variant among the visible ones (SPEC): highest
  /// `match_count(required_attributes)` → `effort_match` → `time_closeness`
  /// → `calorie_closeness`.
  Recipe? pickBest(List<Recipe> candidates, Profile profile, OntologyRef ontology) {
    final visibleRecipes = visible(candidates, profile, ontology);
    if (visibleRecipes.isEmpty) return null;
    visibleRecipes.sort((a, b) => compareVariants(a, b, profile));
    return visibleRecipes.first;
  }

  /// Stable comparator implementing the SPEC tie-break chain.
  int compareVariants(Recipe a, Recipe b, Profile profile) {
    final aMatch = _requiredMatchCount(a, profile);
    final bMatch = _requiredMatchCount(b, profile);
    if (aMatch != bMatch) return bMatch - aMatch;
    final aEffort = _effortScore(a, profile);
    final bEffort = _effortScore(b, profile);
    if (aEffort != bEffort) return bEffort - aEffort;
    final aTime = _timeCloseness(a, profile);
    final bTime = _timeCloseness(b, profile);
    if (aTime != bTime) return bTime - aTime;
    final aCal = _calorieCloseness(a, profile);
    final bCal = _calorieCloseness(b, profile);
    if (aCal != bCal) return bCal - aCal;
    return a.id.compareTo(b.id);
  }

  int _requiredMatchCount(Recipe r, Profile profile) =>
      profile.requiredAttributes.where(r.attributeSet.contains).length;

  /// 2 = exact effort match, 1 = adjacent, 0 = far.
  int _effortScore(Recipe r, Profile profile) {
    const order = ['easy', 'medium', 'hard'];
    final a = order.indexOf(r.effort);
    final b = order.indexOf(profile.preferredEffort);
    if (a < 0 || b < 0) return 0;
    final distance = (a - b).abs();
    if (distance == 0) return 2;
    if (distance == 1) return 1;
    return 0;
  }

  /// Negative absolute distance (higher is closer to the time budget).
  int _timeCloseness(Recipe r, Profile profile) {
    final budget = profile.maxTimeMinutes;
    if (budget == null) return 0;
    return -(r.timeMinutes - budget).abs();
  }

  /// Negative absolute distance to the calorie target.
  int _calorieCloseness(Recipe r, Profile profile) {
    final target = profile.calorieTarget;
    if (target == null) return 0;
    return -(r.cal - target).abs();
  }
}
