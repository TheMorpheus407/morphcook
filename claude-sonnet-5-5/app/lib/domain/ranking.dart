import 'dart:math' as math;

import '../data/models/profile.dart';
import '../data/models/recipe.dart';

/// Tunable numbers of the ranking. The four bonuses are fixed by the spec.
class RankingConfig {
  const RankingConfig();

  // Base score weights keep the spec's order: required matches, then effort,
  // then time, then calories. The smallest step of a level (one required
  // match, one effort notch of 0.5 x 200) is worth more than the whole range
  // of the levels below it (time 50 + calories 30).
  final double requiredMatchWeight = 1000;
  final double effortWeight = 200;
  final double timeWeight = 50;
  final double calorieWeight = 30;

  // Time-aware ranking.
  final int morningBonus = 200; // 5am–11am, breakfast recipes
  final int eveningBonus = 90; // 5pm–9pm, dinner recipes
  final int weekendBonus = 90; // Saturday/Sunday, medium and hard effort
  final int morningStartHour = 5;
  final int morningEndHour = 11;
  final int eveningStartHour = 17;
  final int eveningEndHour = 21;

  // Staleness-aware ranking.
  final int stalenessBonus = 50;
  final int stalenessDays = 30;
}

/// When the ranking runs and what the cook has cooked before.
class RankingContext {
  const RankingContext({required this.now, this.lastCooked = const <String, DateTime>{}});

  final DateTime now;

  /// Recipe id -> last time it was cooked.
  final Map<String, DateTime> lastCooked;

  bool get isWeekend => now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
}

class ScoreBreakdown {
  const ScoreBreakdown({required this.base, required this.timeBonus, required this.stalenessBonus});

  final double base;
  final double timeBonus;
  final double stalenessBonus;

  double get total => base + timeBonus + stalenessBonus;
}

/// Base ranking plus the time-of-day and staleness bonuses.
class Ranking {
  const Ranking([this.config = const RankingConfig()]);

  final RankingConfig config;

  static const Map<String, int> _effortRank = <String, int>{'easy': 0, 'medium': 1, 'hard': 2};

  /// 1 for the same effort, 0.5 for the neighbour, 0 for the far end.
  double effortMatch(String recipeEffort, String preferredEffort) {
    final a = _effortRank[recipeEffort];
    final b = _effortRank[preferredEffort];
    if (a == null || b == null) return 0;
    return 1 - (a - b).abs() / 2;
  }

  /// 1 when the recipe takes exactly the time budget, falling towards 0. Zero
  /// without a budget.
  double timeCloseness(int minutes, int? budget) {
    if (budget == null || budget <= 0) return 0;
    return (1 - (minutes - budget).abs() / budget).clamp(0.0, 1.0).toDouble();
  }

  /// 1 on the calorie target, 0 at the edge of the tolerance and beyond.
  double calorieCloseness(int kcal, Profile profile) {
    final target = profile.calorieTarget;
    if (target == null) return 0;
    final tolerance = math.max(profile.calorieTolerance, 1);
    return (1 - (kcal - target).abs() / tolerance).clamp(0.0, 1.0).toDouble();
  }

  /// `match_count(required_attributes) → effort_match → time_closeness → calorie_closeness`
  double baseScore(RecipeMeta recipe, Profile profile) {
    final matchCount = profile.requiredAttributes.where(recipe.attributes.contains).length;
    return matchCount * config.requiredMatchWeight +
        effortMatch(recipe.effort, profile.preferredEffort) * config.effortWeight +
        timeCloseness(recipe.timeMinutes, profile.maxTimeMinutes) * config.timeWeight +
        calorieCloseness(recipe.caloriesPerServing, profile) * config.calorieWeight;
  }

  bool _isMorning(DateTime now) => now.hour >= config.morningStartHour && now.hour < config.morningEndHour;
  bool _isEvening(DateTime now) => now.hour >= config.eveningStartHour && now.hour < config.eveningEndHour;

  /// Morning +200 for breakfast, evening +90 for dinner, weekend +90 for
  /// medium and hard effort. The bonuses stack.
  double timeBonus(RecipeMeta recipe, DateTime now) {
    var bonus = 0;
    if (_isMorning(now) && recipe.meal.contains('breakfast')) bonus += config.morningBonus;
    if (_isEvening(now) && recipe.meal.contains('dinner')) bonus += config.eveningBonus;
    final weekend = now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    if (weekend && (recipe.effort == 'medium' || recipe.effort == 'hard')) bonus += config.weekendBonus;
    return bonus.toDouble();
  }

  /// +50 for recipes last cooked 30 or more days ago. Never-cooked and recently
  /// cooked recipes get nothing.
  double stalenessBonus(RecipeMeta recipe, RankingContext context) {
    final last = context.lastCooked[recipe.id];
    if (last == null) return 0;
    if (context.now.difference(last).inDays >= config.stalenessDays) return config.stalenessBonus.toDouble();
    return 0;
  }

  ScoreBreakdown breakdown(RecipeMeta recipe, Profile profile, RankingContext context) {
    return ScoreBreakdown(
      base: baseScore(recipe, profile),
      timeBonus: timeBonus(recipe, context.now),
      stalenessBonus: stalenessBonus(recipe, context),
    );
  }

  /// The bonuses apply on top of the base calculation.
  double score(RecipeMeta recipe, Profile profile, RankingContext context) {
    return breakdown(recipe, profile, context).total;
  }

  /// Picks the variant that scores highest; ties resolve by id for stability.
  T? bestOf<T extends RecipeMeta>(Iterable<T> candidates, Profile profile, RankingContext context) {
    T? best;
    double bestScore = double.negativeInfinity;
    for (final candidate in candidates) {
      final s = score(candidate, profile, context);
      if (best == null || s > bestScore || (s == bestScore && candidate.id.compareTo(best.id) < 0)) {
        best = candidate;
        bestScore = s;
      }
    }
    return best;
  }

  /// Sorts by score, best first; ties resolve by id.
  List<T> sorted<T extends RecipeMeta>(Iterable<T> candidates, Profile profile, RankingContext context) {
    final scored = [for (final c in candidates) MapEntry(c, score(c, profile, context))];
    scored.sort((a, b) {
      final byScore = b.value.compareTo(a.value);
      return byScore != 0 ? byScore : a.key.id.compareTo(b.key.id);
    });
    return [for (final e in scored) e.key];
  }
}
