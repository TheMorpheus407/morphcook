// Ranking: which variant to pick when several pass, and how to order the
// feed. Base score is lexicographic by construction (weights separate the
// tiers), then time-aware and staleness bonuses are added on top.
import 'dart:math' as math;

import '../data/models/profile.dart';
import '../data/models/recipe.dart';

const int kMorningBreakfastBonus = 200;
const int kEveningDinnerBonus = 90;
const int kWeekendEffortBonus = 90;
const int kStalenessBonus = 50;
const int kStalenessDays = 30;

/// How many required attributes the recipe satisfies (all of them when it
/// is visible; still informative when ranking hidden fallbacks).
int matchCount(Recipe r, Profile p) => p.requiredAttributes.where(r.attributes.contains).length;

bool effortMatch(Recipe r, Profile p) => r.effort == p.preferredEffort;

/// 0..100, closer to the time budget (or a 30-minute default) is better.
int timeCloseness(Recipe r, Profile p) {
  final budget = p.maxTimeMinutes ?? 30;
  return 100 - math.min(100, (r.timeMinutes - budget).abs());
}

/// 0..100, closer to the calorie target (or a 600 kcal default) is better.
int calorieCloseness(Recipe r, Profile p) {
  final target = p.calorieTarget ?? 600;
  return 100 - math.min(100, ((r.caloriesPerServing - target).abs() / 5).round());
}

int baseScore(Recipe r, Profile p) =>
    matchCount(r, p) * 1000 + (effortMatch(r, p) ? 300 : 0) + timeCloseness(r, p) + calorieCloseness(r, p);

/// Morning (5–11) favours breakfast, evening (17–21) favours dinner,
/// weekends favour medium/hard projects.
int timeBonus(Recipe r, DateTime now) {
  var bonus = 0;
  final h = now.hour;
  if (h >= 5 && h < 11 && r.isBreakfast) bonus += kMorningBreakfastBonus;
  if (h >= 17 && h < 21 && r.isDinner) bonus += kEveningDinnerBonus;
  final weekend = now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
  if (weekend && (r.effort == 'medium' || r.effort == 'hard')) bonus += kWeekendEffortBonus;
  return bonus;
}

/// Not cooked for 30+ days → +50. Never cooked or recently cooked → 0.
int stalenessBonus(DateTime? lastCooked, DateTime now) {
  if (lastCooked == null) return 0;
  return now.difference(lastCooked).inDays >= kStalenessDays ? kStalenessBonus : 0;
}

class RankContext {
  RankContext({required this.now, Map<String, DateTime>? lastCookedByRecipe})
      : lastCookedByRecipe = lastCookedByRecipe ?? const {};
  final DateTime now;
  final Map<String, DateTime> lastCookedByRecipe;
}

int score(Recipe r, Profile p, RankContext ctx) =>
    baseScore(r, p) + timeBonus(r, ctx.now) + stalenessBonus(ctx.lastCookedByRecipe[r.id], ctx.now);

/// Highest score wins; ties resolve by id so results are stable.
Recipe? pickBest(Iterable<Recipe> candidates, Profile p, RankContext ctx) {
  Recipe? best;
  int bestScore = -1;
  for (final r in candidates) {
    final s = score(r, p, ctx);
    if (best == null || s > bestScore || (s == bestScore && r.id.compareTo(best.id) < 0)) {
      best = r;
      bestScore = s;
    }
  }
  return best;
}

List<Recipe> rank(Iterable<Recipe> candidates, Profile p, RankContext ctx) {
  final list = candidates.toList();
  final scores = {for (final r in list) r.id: score(r, p, ctx)};
  list.sort((a, b) {
    final c = scores[b.id]!.compareTo(scores[a.id]!);
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  return list;
}
