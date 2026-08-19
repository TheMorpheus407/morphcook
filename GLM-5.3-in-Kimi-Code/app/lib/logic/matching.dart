/// The matching algorithm — pure set logic, heavily tested.
///
/// visible(recipe, profile) :=
///     recipe.contains ∩ avoid_flags_expanded = ∅
/// AND avoid_ingredients_expanded ∩ recipe.ingredient_ids = ∅
/// AND required_attributes ⊆ recipe (compound required flags expand to bans)
/// AND recipe.time_minutes ≤ max_time_minutes
/// AND |recipe.calories - calorie_target| ≤ tolerance
library;

import '../data/models.dart';
import 'profile.dart';

class MatchOptions {
  /// Per-dish override switch: show versions outside the calorie target.
  final bool calorieOverride;

  /// Used by ranking where the time budget is advisory, not hiding.
  final bool ignoreTime;

  const MatchOptions({this.calorieOverride = false, this.ignoreTime = false});
}

class MatchResult {
  final bool visible;
  /// Machine-readable reasons: 'avoid_flag:x', 'avoid_ingredient:x',
  /// 'required:x', 'time', 'calories'.
  final Set<String> violations;
  const MatchResult(this.visible, this.violations);
}

/// Precomputed avoidance sets for a profile — build once, reuse per recipe.
class Avoidance {
  final Set<String> flags; // expanded class/compound avoid-flags
  final Set<String> ingredientIds; // specific avoidances incl. descendants

  const Avoidance(this.flags, this.ingredientIds);

  factory Avoidance.of(Profile p, Ontology onto, [IngredientIndex? idx]) {
    final flags = onto.expandAvoidFlags(p.avoidFlags);
    final ids = <String>{};
    if (idx == null) {
      ids.addAll(p.avoidIngredients);
    } else {
      for (final id in p.avoidIngredients) {
        if (idx.nodes.containsKey(id)) ids.addAll(idx.subtreeOf(id));
      }
    }
    return Avoidance(flags, ids);
  }
}

MatchResult matchesRecipe(
  Recipe r,
  Profile p,
  Ontology onto, {
  Avoidance? avoidance,
  MatchOptions opts = const MatchOptions(),
}) {
  final av = avoidance ?? Avoidance.of(p, onto);
  final violations = <String>{};

  // contains ∩ avoid = ∅
  for (final f in r.contains) {
    if (av.flags.contains(f)) violations.add('avoid_flag:$f');
  }

  // specific avoided ingredients (already expanded to subtrees)
  for (final id in r.ingredientIds) {
    if (av.ingredientIds.contains(id)) violations.add('avoid_ingredient:$id');
  }

  // required attributes — compound required flags expand to bans
  for (final req in p.requiredAttributes) {
    final compound = onto.compoundFlags[req];
    if (compound != null) {
      if (r.contains.any(compound.expandsTo.contains)) {
        violations.add('required:$req');
      }
    } else if (!r.contains.contains(req)) {
      violations.add('required:$req');
    }
  }

  if (!opts.ignoreTime &&
      p.maxTimeMinutes != null &&
      r.timeMinutes > p.maxTimeMinutes!) {
    violations.add('time');
  }

  if (!opts.calorieOverride &&
      p.calorieTarget != null &&
      (r.caloriesPerServing - p.calorieTarget!).abs() >
          Profile.calorieTolerance) {
    violations.add('calories');
  }

  return MatchResult(violations.isEmpty, violations);
}

/// Diet-compatible = only calorie/time may stand between recipe and user.
/// Used to decide which variants a dish page may offer beneath the switches.
bool isDietCompatible(
  Recipe r,
  Profile p,
  Ontology onto, {
  Avoidance? avoidance,
}) {
  final res = matchesRecipe(
    r,
    p,
    onto,
    avoidance: avoidance,
    opts: const MatchOptions(calorieOverride: true, ignoreTime: true),
  );
  return res.visible;
}
