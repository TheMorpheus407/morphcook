import 'package:flutter/foundation.dart';

import '../models/ingredient.dart';
import '../models/profile.dart';
import '../models/recipe.dart';

/// The pure matching function. Heavily tested — never touches storage.
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
  Matcher({required this.ingredientTree});

  /// Ingredient dictionary, used to propagate specific avoidances
  /// (avoiding "nuts" excludes every child nut).
  final IngredientTree ingredientTree;

  /// Reasons a recipe failed, for UI notes ("no vegan × keto version yet"
  /// is handled elsewhere; this covers profile-driven invisibility).
  MatchResult evaluate(
    Recipe recipe,
    Profile profile, {
    bool overrideCalories = false,
  }) {
    final failures = <String>[];

    final contains = recipe.contains.toSet();
    final avoided = contains.intersection(profile.avoidFlags);
    if (avoided.isNotEmpty) {
      failures.add('flags:${avoided.join(',')}');
    }

    final avoidedIngredients = ingredientTree
        .propagationOf(profile.avoidIngredients)
        .intersection(recipe.ingredientIds.toSet());
    if (avoidedIngredients.isNotEmpty) {
      failures.add('ingredients:${avoidedIngredients.join(',')}');
    }

    final missingAttributes =
        profile.requiredAttributes.difference(recipe.attributes);
    if (missingAttributes.isNotEmpty) {
      failures.add('attributes:${missingAttributes.join(',')}');
    }

    if (recipe.timeMinutes > profile.maxTimeMinutes) {
      failures.add('time');
    }

    if (!overrideCalories) {
      final diff = (recipe.caloriesPerServing - profile.calorieTarget).abs();
      if (diff > profile.calorieTolerance) {
        failures.add('calories');
      }
    }

    return MatchResult(
      visible: failures.isEmpty,
      failures: List.unmodifiable(failures),
    );
  }

  /// Filters a recipe list by profile, keeping only visible ones.
  List<Recipe> filter(
    Iterable<Recipe> recipes,
    Profile profile, {
    bool overrideCalories = false,
  }) => [
        for (final r in recipes)
          if (evaluate(r, profile, overrideCalories: overrideCalories).visible) r,
      ];

  /// Scores a visible recipe against the profile:
  /// match_count(required) → effort_match → time_closeness → calorie_closeness.
  /// Higher is better. Recipes that are not visible score -1.
  int score(Recipe recipe, Profile profile, {bool overrideCalories = false}) {
    if (!evaluate(recipe, profile, overrideCalories: overrideCalories).visible) {
      return -1;
    }
    var s = 0;

    final requiredHits =
        profile.requiredAttributes.intersection(recipe.attributes).length;
    s += requiredHits * 1000;

    if (recipe.effort == profile.preferredEffort) {
      s += 400;
    } else {
      const effortRank = {'easy': 0, 'medium': 1, 'hard': 2};
      final diff = (effortRank[recipe.effort] ?? 1) -
          (effortRank[profile.preferredEffort] ?? 1);
      s += diff.abs() == 1 ? 200 : 100;
    }

    final timeCloseness =
        (profile.maxTimeMinutes - recipe.timeMinutes).clamp(-9999, 9999);
    s += (60 - timeCloseness.abs()).clamp(0, 60) * 2;

    final calorieDiff =
        (recipe.caloriesPerServing - profile.calorieTarget).abs();
    s += (profile.calorieTolerance - calorieDiff).clamp(0, 999) ~/ 5;

    return s;
  }

  /// The best visible variant of a dish — the one shown by default.
  /// Ties break deterministically by recipe id.
  Recipe? bestVariant(
    List<Recipe> variants,
    Profile profile, {
    bool overrideCalories = false,
  }) {
    Recipe? best;
    var bestScore = -1;
    for (final r in variants) {
      final s = score(r, profile, overrideCalories: overrideCalories);
      if (s > bestScore || (s == bestScore && s >= 0 && (best == null || r.id.compareTo(best.id) < 0))) {
        best = r;
        bestScore = s;
      }
    }
    return best;
  }
}

/// Pure result record — visible + the reasons it failed.
@immutable
class MatchResult {
  const MatchResult({required this.visible, this.failures = const []});

  final bool visible;
  final List<String> failures;

  bool failedFlag(String flag) =>
      failures.any((f) => f.startsWith('flags:') && f.contains(flag));
  bool get failedTime => failures.contains('time');
  bool get failedCalories => failures.contains('calories');

  @override
  bool operator ==(Object other) =>
      other is MatchResult && other.visible == visible;

  @override
  int get hashCode => visible.hashCode;
}
