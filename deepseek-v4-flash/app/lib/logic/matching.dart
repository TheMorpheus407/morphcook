import '../data/corpus.dart';
import '../models/models.dart';

/// The matching algorithm — a pure function, heavily tested.
///
/// visible(recipe, profile) :=
///   recipe.contains ∩ expand(profile.avoid_flags) = ∅
///   AND no avoid_ingredient is the same as, an ancestor of, or a descendant
///       of any recipe ingredient id (specific avoidance propagates to children)
///   AND profile.required_attributes ⊆ recipe.attributes
///   AND recipe.time_minutes ≤ profile.max_time_minutes
///   AND |recipe.calories - profile.calorie_target| ≤ tolerance
class RecipeMatcher {
  final Corpus corpus;

  RecipeMatcher(this.corpus);

  Set<String> expandedAvoids(UserProfile profile) =>
      corpus.ontology.expandAvoids(profile.avoidFlags);

  /// Specific ingredient avoidance with tree propagation.
  /// Returns true if the recipe conflicts with any specific avoid ingredient.
  bool _specificConflict(UserProfile profile, Recipe recipe) {
    if (profile.avoidIngredients.isEmpty) return false;
    final recipeIds = recipe.ingredientIds;
    for (final avoid in profile.avoidIngredients) {
      if (corpus.ingredientsById[avoid] == null) continue;
      // conflict iff the avoided id is the same as, or an ancestor of, any
      // recipe ingredient id (avoiding a parent hides children).
      for (final rid in recipeIds) {
        final ancestors = corpus.ancestorsOf(rid);
        if (ancestors.contains(avoid)) return true;
      }
    }
    return false;
  }

  bool visible(Recipe recipe, UserProfile profile) {
    final avoids = expandedAvoids(profile);
    if (avoids.isNotEmpty &&
        recipe.contains.intersection(avoids).isNotEmpty) {
      return false;
    }
    if (_specificConflict(profile, recipe)) return false;
    if (profile.requiredAttributes.isNotEmpty &&
        !profile.requiredAttributes.every(recipe.attributes.contains)) {
      return false;
    }
    if (profile.maxTimeMinutes != null &&
        recipe.timeMinutes > profile.maxTimeMinutes!) {
      return false;
    }
    if (profile.calorieTarget != null &&
        (recipe.calories - profile.calorieTarget!).abs() >
            UserProfile.calorieTolerance) {
      return false;
    }
    return true;
  }

  List<Recipe> visibleWhere(
      Iterable<Recipe> recipes, UserProfile profile) {
    return recipes.where((r) => visible(r, profile)).toList();
  }

  /// Rank (higher = better) two recipes by: required-attribute match →
  /// effort match → time closeness → calorie closeness.
  double rankScore(Recipe recipe, UserProfile profile) {
    var score = 0.0;

    final matchedRequired = profile.requiredAttributes
        .where(recipe.attributes.contains)
        .length;
    score += matchedRequired * 1000.0;

    if (profile.preferredEffort != null &&
        recipe.effort == profile.preferredEffort) {
      score += 500.0;
    }

    if (profile.maxTimeMinutes != null) {
      final closeness =
          (recipe.timeMinutes / profile.maxTimeMinutes!.toDouble()).clamp(0.0, 1.0);
      score += 200.0 * (1.0 - closeness);
    }

    if (profile.calorieTarget != null) {
      final diff =
          (recipe.calories - profile.calorieTarget!).abs().toDouble();
      final window = UserProfile.calorieTolerance * 2.0;
      score += 100.0 * (1.0 - (diff / window).clamp(0.0, 1.0));
    }

    return score;
  }

  /// Pick the best visible variant of a dish (spec tie-break order + profile defaults).
  Recipe? bestForDish(Dish dish, UserProfile profile,
      {UserProfile? effective}) {
    final p = effective ?? profile;
    final cast = corpus.recipesForDish(dish.id);
    final winners = cast.where((r) => visible(r, p)).toList();
    if (winners.isEmpty) return null;
    winners.sort((a, b) => rankScore(b, p).compareTo(rankScore(a, p)));
    return winners.first;
  }
}

/// Temporal + staleness context for the home feed ranking.
class RankingContext {
  final DateTime now;
  final Map<String, DateTime> lastCookedByRecipe;

  const RankingContext({required this.now, this.lastCookedByRecipe = const {}});

  bool get isMorning => now.hour >= 5 && now.hour < 11;
  bool get isEvening => now.hour >= 17 && now.hour < 21;
  bool get isWeekend => now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
}

/// Time-aware + staleness-aware bonuses applied on top of the base ranking.
double homeScore(Recipe r, RankingContext ctx, UserProfile profile,
    RecipeMatcher matcher) {
  var s = matcher.rankScore(r, profile);

  if (ctx.isMorning && r.isBreakfast) s += 200.0;
  if (ctx.isEvening && r.isDinner) s += 90.0;
  if (ctx.isWeekend && (r.effort == 'medium' || r.effort == 'hard')) s += 90.0;

  final last = ctx.lastCookedByRecipe[r.id];
  if (last != null && ctx.now.difference(last).inDays > 30) s += 50.0;

  return s;
}

/// Variant-switcher geometry for a dish detail page.
///
/// Selection is (diet, effort, calorieBucket). Changing one dimension narrows
/// the others; combos without a recipe are disabled but never hidden.
class VariantGeometry {
  final Dish dish;
  final List<Recipe> variants;
  final List<String> dietOptions;
  final List<String> effortOptions;
  final List<String> bucketOptions;

  VariantGeometry({
    required this.dish,
    required this.variants,
  })  : dietOptions = _orderedDiets(variants),
        effortOptions = _orderedEfforts(variants),
        bucketOptions = _orderedBuckets(variants);

  static List<String> _orderedDiets(List<Recipe> variants) {
    const order = [
      'classic', 'vegetarian', 'vegan', 'pescatarian', 'keto', 'halal',
      'kosher', 'gluten-free', 'lactose-free', 'low-fodmap', 'sugar-free',
    ];
    final present = variants.map((r) => r.diet).toSet();
    return order.where(present.contains).toList();
  }

  static List<String> _orderedEfforts(List<Recipe> variants) {
    const order = ['easy', 'medium', 'hard'];
    final present = variants.map((r) => r.effort).toSet();
    return order.where(present.contains).toList();
  }

  static const _calorieOrder = ['≤400', '≤600', '≤800', '>800'];

  static List<String> _orderedBuckets(List<Recipe> variants) {
    final present = variants.map((r) => r.calorieBucket).toSet();
    return _calorieOrder.where(present.contains).toList();
  }

  /// True when a recipe exists for the exact combination, given that
  /// [diet]/[effort]/[bucket] may be null (meaning "any").
  bool comboExists(String? diet, String? effort, String? bucket) {
    if (diet != null && !dietOptions.contains(diet)) return false;
    if (effort != null && !effortOptions.contains(effort)) return false;
    if (bucket != null && !bucketOptions.contains(bucket)) return false;
    return variants.any((r) {
      return (diet == null || r.diet == diet) &&
          (effort == null || r.effort == effort) &&
          (bucket == null || r.calorieBucket == bucket);
    });
  }

  /// Recipes that fit the selection.
  List<Recipe> select(String? diet, String? effort, String? bucket) =>
      variants.where((r) {
        return (diet == null || r.diet == diet) &&
            (effort == null || r.effort == effort) &&
            (bucket == null || r.calorieBucket == bucket);
      }).toList();

  /// Default selection from the profile. Diet reflects any required diet flag;
  /// effort reflects the preferred effort; bucket reflects the calorie target.
  String? defaultDiet(UserProfile profile) {
    for (final d in dietOptions) {
      if (profile.requiredAttributes.contains(d)) return d;
    }
    if (profile.avoidFlags.contains('halal') && dietOptions.contains('halal')) {
      return 'halal';
    }
    if (profile.avoidFlags.contains('kosher') && dietOptions.contains('kosher')) {
      return 'kosher';
    }
    if (profile.avoidFlags.contains('vegan') && dietOptions.contains('vegan')) {
      return 'vegan';
    }
    return dietOptions.isEmpty ? null : dietOptions.first;
  }

  String? defaultEffort(UserProfile profile) =>
      effortOptions.contains(profile.preferredEffort)
          ? profile.preferredEffort
          : (effortOptions.isEmpty ? null : effortOptions.first);

  String? defaultBucket(UserProfile profile) {
    if (profile.calorieTarget == null) {
      return bucketOptions.isEmpty ? null : bucketOptions.first;
    }
    final target = profile.calorieTarget!;
    for (final b in bucketOptions) {
      if (_bucketContains(b, target)) return b;
    }
    return bucketOptions.isEmpty ? null : bucketOptions.first;
  }

  static bool _bucketContains(String bucket, int calories) {
    final max = _calorieOrder.indexOf(bucket);
    if (max <= 0) return calories <= 400;
    if (max == 1) return calories <= 600;
    if (max == 2) return calories <= 800;
    return calories > 800;
  }

  /// When a user changes one dimension and the auto-adjusted selection would
  /// be unreachable, nudge the other dimensions (effort → bucket) until the
  /// combined selection is reachable. The newly-chosen dimension stays fixed.
  ({String? diet, String? effort, String? bucket}) settle({
    required String? diet,
    required String? effort,
    required String? bucket,
    required UserProfile profile,
  }) {
    String? d = diet ?? defaultDiet(profile);
    String? e = effort ?? defaultEffort(profile);
    String? b = bucket ?? defaultBucket(profile);

    // clamp into option ranges first
    if (d != null && !dietOptions.contains(d)) d = dietOptions.first;
    if (e != null && !effortOptions.contains(e)) e = effortOptions.first;
    if (b != null && !bucketOptions.contains(b)) b = bucketOptions.first;

    if (comboExists(d, e, b)) return (diet: d, effort: e, bucket: b);

    // try relaxing effort first, then calorie bucket.
    for (final option in effortOptions) {
      if (comboExists(d, option, b)) return (diet: d, effort: option, bucket: b);
    }
    for (final option in bucketOptions) {
      if (comboExists(d, e, option)) return (diet: d, effort: e, bucket: option);
    }
    // fully relax
    for (final ed in effortOptions) {
      for (final bc in bucketOptions) {
        if (comboExists(d, ed, bc)) {
          return (diet: d, effort: ed, bucket: bc);
        }
      }
    }
    return (diet: dietOptions.isEmpty ? null : dietOptions.first,
        effort: effortOptions.isEmpty ? null : effortOptions.first,
        bucket: bucketOptions.isEmpty ? null : bucketOptions.first);
  }
}