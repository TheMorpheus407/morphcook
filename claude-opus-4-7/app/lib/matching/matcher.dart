import '../models/profile.dart';
import '../models/recipe.dart';
import '../models/ontology.dart';
import '../models/ingredient_dict.dart';

/// Result of evaluating a recipe against a profile.
class MatchResult {
  final Recipe recipe;
  final bool visible;
  final List<String> blockingReasons;  // human-readable reasons for hide
  final List<String> blockingFlags;    // raw flags / ingredients

  const MatchResult({
    required this.recipe,
    required this.visible,
    this.blockingReasons = const [],
    this.blockingFlags = const [],
  });
}

class Matcher {
  final Ontology ontology;
  final IngredientDict dict;

  Matcher({required this.ontology, required this.dict});

  /// Set-logic visibility check per SPEC §Matching algorithm:
  ///   contains ∩ expanded(avoid_flags) = ∅
  ///   expanded(avoid_ingredients) ∩ ingredient_ids = ∅
  ///   required_attributes ⊆ attributes
  ///   time_minutes ≤ max_time_minutes (if set)
  ///   |calories - target| ≤ tolerance (if calorie_hard_filter and target set)
  MatchResult evaluate(Recipe r, Profile p) {
    final reasons = <String>[];
    final flags = <String>[];

    // Expand compound flags
    final expandedAvoid = ontology.expandAll(p.avoidFlags);
    final blockedFlags = r.contains.toSet().intersection(expandedAvoid);
    if (blockedFlags.isNotEmpty) {
      reasons.add('contains_flag');
      flags.addAll(blockedFlags);
    }

    // Expand avoided ingredients (parents → all descendants)
    final expandedIng = dict.expand(p.avoidIngredients);
    final blockedIng = r.ingredientIds.intersection(expandedIng);
    if (blockedIng.isNotEmpty) {
      reasons.add('avoid_ingredient');
      flags.addAll(blockedIng);
    }

    // Required attributes
    final missingRequired =
        p.requiredAttributes.difference(r.attributes.toSet());
    if (missingRequired.isNotEmpty) {
      reasons.add('missing_required');
      flags.addAll(missingRequired);
    }

    // Time budget
    if (p.maxTimeMinutes > 0 && r.timeMinutes > p.maxTimeMinutes) {
      reasons.add('over_time_budget');
    }

    // Calorie tolerance (hard filter only)
    if (p.calorieHardFilter && p.calorieTarget > 0) {
      final diff = (r.caloriesPerServing - p.calorieTarget).abs();
      if (diff > p.calorieTolerance) {
        reasons.add('out_of_calorie_range');
      }
    }

    return MatchResult(
      recipe: r,
      visible: reasons.isEmpty,
      blockingReasons: reasons,
      blockingFlags: flags,
    );
  }

  Iterable<Recipe> filter(Iterable<Recipe> recipes, Profile p) sync* {
    for (final r in recipes) {
      if (evaluate(r, p).visible) yield r;
    }
  }
}
