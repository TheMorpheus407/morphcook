import 'models.dart';

/// Result of checking a single recipe against a profile.
class MatchResult {
  const MatchResult.visible_() : visible = true, reasons = const [];
  const MatchResult.blocked(List<String> reasons)
      : visible = false,
        reasons = reasons;

  final bool visible;
  final List<String> reasons; // human-readable ids, e.g. 'avoid:dairy', 'time'

  static final ok = MatchResult.visible_();
}

/// Pure matching algorithm (heavily tested).
class Matcher {
  const Matcher();

  /// Why [recipe] is (not) visible for [profile] given [corpus] data.
  MatchResult check(Recipe recipe, Profile profile, {required bool ignoreCalories}) {
    // 1. class-level contains ∩ avoid_flags
    for (final c in recipe.contains) {
      if (profile.avoidFlags.contains(c)) {
        return MatchResult.blocked(['avoid:$c']);
      }
    }
    // 2. specific avoided ingredients (caller passes closure via corpus below)
    // handled by caller-supplied closure set.
    return MatchResult.ok;
  }

  /// Full check including specific-ingredient closure (precomputed by caller).
  MatchResult checkFull({
    required Recipe recipe,
    required Profile profile,
    required Set<String> avoidClosedIds,
    required bool ignoreCalories,
    int? toleranceOverride,
  }) {
    for (final c in recipe.contains) {
      if (profile.avoidFlags.contains(c)) {
        return MatchResult.blocked(['avoid:$c']);
      }
    }
    for (final ing in recipe.ingredientIds) {
      if (avoidClosedIds.contains(ing)) {
        return MatchResult.blocked(['avoid-ingredient:$ing']);
      }
    }
    for (final attr in profile.requiredAttributes) {
      if (!recipe.attributes.contains(attr) && !recipe.contains.contains(attr)) {
        return MatchResult.blocked(['required:$attr']);
      }
    }
    if (recipe.timeMinutes > profile.maxTimeMinutes) {
      return MatchResult.blocked(['time:${recipe.timeMinutes}']);
    }
    final tolerance = toleranceOverride ?? profile.calorieTolerance;
    if (!ignoreCalories &&
        (recipe.calorieLevel - profile.calorieTarget).abs() > tolerance) {
      return MatchResult.blocked(
          'calories:${recipe.calorieLevel}-${profile.calorieTarget}+$tolerance');
    }
    return MatchResult.ok;
  }
}

class RankedRecipe {
  const RankedRecipe({required this.recipe, required this.score});
  final Recipe recipe;
  final int score;
}

/// Base match + time-aware & staleness bonuses (pure, testable).
class Ranker {
  Ranker({required this.matcher, this.now, this.isWeekend, this.staleDays = 30});

  final Matcher matcher;
  final DateTime? now;
  final bool? isWeekend;

  /// Days without cooking to count as "neglected" (+50).
  final int staleDays;

  DateTime get _now => now ?? DateTime.now();

  bool get _weekend {
    if (isWeekend != null) return isWeekend!;
    final wd = _now.weekday;
    return wd == DateTime.saturday || wd == DateTime.sunday;
  }

  /// Temporal context bonus for a recipe's meal tags.
  int temporalBonus(Recipe r) {
    final h = _now.hour;
    var bonus = 0;
    if (h >= 5 && h < 11) {
      // Morning: breakfast recipes +200. Meal tags come from the dish; callers
      // pass it via r (wrapped in recipe.tags by corpus as 'meal:breakfast').
      if (r.tags.any((t) => t == 'meal:breakfast')) bonus += 200;
    }
    if (h >= 17 && h < 21) {
      if (r.tags.any((t) => t == 'meal:dinner')) bonus += 90;
    }
    if (_weekend) {
      if (r.effort == 'medium' || r.effort == 'hard') bonus += 90;
    }
    return bonus;
  }

  int stalenessBonus(Recipe r, int? lastCookedMs) {
    if (lastCookedMs == null) return 0;
    final days =
        (_now.millisecondsSinceEpoch - lastCookedMs) / 86400000;
    return days >= staleDays ? 50 : 0;
  }

  /// Base score: required-attribute matches → effort match → time closeness →
  /// calorie closeness.
  int baseScore(Recipe r, Profile p) {
    var score = 0;
    for (final attr in p.requiredAttributes) {
      if (r.attributes.contains(attr) || r.contains.contains(attr)) score += 100;
    }
    if (r.effort == p.preferredEffort) {
      score += 80;
    } else {
      final order = {'easy': 0, 'medium': 1, 'hard': 2};
      final d = (order[r.effort]! - order[p.preferredEffort]!).abs();
      score += (2 - d).clamp(0, 2) * 10;
    }
    score -= (r.timeMinutes - p.maxTimeMinutes).abs().clamp(0, 240) ~/ 4;
    score -= (r.calorieLevel - p.calorieTarget).abs() ~/ 16;
    return score;
  }

  RankedRecipe rank(
    Recipe r,
    Profile p, {
    required Set<String> avoidClosed,
    required bool ignoreCalories,
    int? lastCookedMs,
  }) {
    final res = matcher.checkFull(
      recipe: r,
      profile: p,
      avoidClosedIds: avoidClosed,
      ignoreCalories: ignoreCalories,
    );
    if (!res.visible) {
      return RankedRecipe(recipe: r, score: -1 << 30);
    }
    return RankedRecipe(
        recipe: r,
        score: baseScore(r, p) + temporalBonus(r) + stalenessBonus(r, lastCookedMs));
  }
}

/// Pick the best variant of a dish for a profile.
RankedRecipe? bestVariant({
  required List<Recipe> variants,
  required Profile profile,
  required Set<String> avoidClosed,
  required bool ignoreCalories,
  int Function(String recipeId)? lastCooked,
  DateTime? now,
  bool? weekend,
}) {
  final ranker = Ranker(
      matcher: const Matcher(), now: now, isWeekend: weekend);
  RankedRecipe? best;
  for (final v in variants) {
    final ranked = ranker.rank(
      v,
      profile,
      avoidClosed: avoidClosed,
      ignoreCalories: ignoreCalories,
      lastCooked: lastCooked?.call(v.id),
    );
    if (ranked.score < 0) continue;
    if (best == null ||
        ranked.score > best.score ||
        (ranked.score == best.score && v.id.compareTo(best.recipe.id) > 0)) {
      best = ranked;
    }
  }
  return best;
}
