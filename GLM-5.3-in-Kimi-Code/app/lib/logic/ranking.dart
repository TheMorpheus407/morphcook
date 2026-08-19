/// Recipe ranking: base preferences + time-aware bonuses + staleness boost.
///
///   base = 100 × required-attr matches
///        +  50 × effort match
///        +  40 × time closeness
///        +  30 × calorie closeness
///   morning (5–11):  breakfast +200
///   evening (17–21): dinner +90
///   weekend:         medium/hard effort +90
///   staleness:       not cooked in 30+ days +50 (never-cooked: no bonus)
library;

import '../data/models.dart';
import 'profile.dart';

class RankContext {
  final DateTime now;
  /// recipeId -> last cooked at (null = never).
  final Map<String, DateTime> lastCooked;

  const RankContext({required this.now, this.lastCooked = const {}});

  factory RankContext.now({Map<String, DateTime> lastCooked = const {}}) =>
      RankContext(now: DateTime.now(), lastCooked: lastCooked);
}

int scoreRecipe(
  Recipe r,
  Profile p,
  RankContext ctx, {
  int requiredSatisfied = 0,
}) {
  var score = 0.0;

  // base: required attribute matches
  score += 100.0 * requiredSatisfied;

  // effort match
  if (r.effort == p.preferredEffort) score += 50;

  // time closeness — anchor near the budget (or a 45-min default)
  final anchor = (p.maxTimeMinutes ?? 60) * 0.75;
  final timeDev = (r.timeMinutes - anchor).abs() / 60.0;
  score += 40 * (1 - timeDev.clamp(0.0, 1.0));

  // calorie closeness
  if (p.calorieTarget == null) {
    score += 15;
  } else {
    final calDev =
        (r.caloriesPerServing - p.calorieTarget!).abs() / 400.0;
    score += 30 * (1 - calDev.clamp(0.0, 1.0));
  }

  // time-of-day context
  final hour = ctx.now.hour;
  if (hour >= 5 && hour < 11 && r.mealType == 'breakfast') score += 200;
  if (hour >= 17 && hour < 21 && r.mealType == 'dinner') score += 90;

  // weekend context
  final weekend = ctx.now.weekday == DateTime.saturday ||
      ctx.now.weekday == DateTime.sunday;
  if (weekend && (r.effort == 'medium' || r.effort == 'hard')) score += 90;

  // staleness — encourage rediscovery of neglected recipes
  final last = ctx.lastCooked[r.id];
  if (last != null && ctx.now.difference(last).inDays >= 30) score += 50;

  return score.round();
}

/// Convenience: rank a dish's variants for a profile.
List<Recipe> rankVariants(
  List<Recipe> variants,
  Profile p,
  RankContext ctx, {
  Dish? dish,
}) {
  final scored = <MapEntry<Recipe, int>>[];
  for (final r in variants) {
    scored.add(MapEntry(r, scoreRecipe(r, p, ctx)));
  }
  scored.sort((a, b) {
    final c = b.value.compareTo(a.value);
    if (c != 0) return c;
    final ta = dish?.variants.indexOf(a.key.id) ?? 0;
    final tb = dish?.variants.indexOf(b.key.id) ?? 0;
    if (ta != tb) return ta.compareTo(tb);
    return a.key.id.compareTo(b.key.id);
  });
  return scored.map((e) => e.key).toList();
}
