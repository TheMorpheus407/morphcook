import '../models/profile.dart';
import '../models/recipe.dart';
import '../models/meal_plan.dart';

/// Picks the best variant of a dish per the SPEC tie-breaking order:
/// match_count(required_attributes) → effort_match → time_closeness →
/// calorie_closeness. Then applies time-aware and staleness-aware bonuses.
class Ranker {
  /// Provide cooked-history lookup: recipe id → most-recent cooked date.
  final Map<String, DateTime> lastCookedAt;
  final DateTime now;

  Ranker({
    Map<String, DateTime>? lastCookedAt,
    DateTime? now,
  })  : lastCookedAt = lastCookedAt ?? const {},
        now = now ?? DateTime.now();

  /// Score (higher = better).
  int score(Recipe r, Profile p) {
    int s = 0;

    // 1. Required attribute coverage (massive weight)
    s += r.attributes
            .toSet()
            .intersection(p.requiredAttributes)
            .length *
        10000;

    // 2. Effort match
    if (r.effort == p.preferredEffort) s += 2000;
    // partial credit for adjacency
    if ((r.effort == 'easy' && p.preferredEffort == 'medium') ||
        (r.effort == 'medium' && p.preferredEffort == 'easy') ||
        (r.effort == 'medium' && p.preferredEffort == 'hard') ||
        (r.effort == 'hard' && p.preferredEffort == 'medium')) {
      s += 800;
    }

    // 3. Time closeness — closer to budget = better, with no penalty for being well under.
    if (p.maxTimeMinutes > 0) {
      final overshoot = r.timeMinutes - p.maxTimeMinutes;
      if (overshoot <= 0) {
        s += 600 + (overshoot.abs().clamp(0, 60));
      } else {
        s -= overshoot * 20;
      }
    }

    // 4. Calorie closeness
    if (p.calorieTarget > 0) {
      final diff = (r.caloriesPerServing - p.calorieTarget).abs();
      s += (500 - diff).clamp(-500, 500);
    }

    // 5. Time-aware bonus
    s += _timeAwareBonus(r);

    // 6. Staleness bonus (encourage variety)
    s += _stalenessBonus(r);

    return s;
  }

  int _timeAwareBonus(Recipe r) {
    int bonus = 0;
    final hour = now.hour;
    final isWeekend = now.weekday == DateTime.saturday ||
        now.weekday == DateTime.sunday;
    if (hour >= 5 && hour < 11 && r.isBreakfast) bonus += 200;
    if (hour >= 17 && hour < 21 && r.isDinner) bonus += 90;
    if (isWeekend && (r.effort == 'medium' || r.effort == 'hard')) bonus += 90;
    return bonus;
  }

  int _stalenessBonus(Recipe r) {
    final last = lastCookedAt[r.id];
    if (last == null) return 0; // never cooked → no bonus per SPEC
    final daysSince = now.difference(last).inDays;
    if (daysSince >= 30) return 50;
    return 0;
  }

  /// Pick the highest-scoring recipe from the list.
  /// Returns null if input is empty.
  Recipe? pickBest(Iterable<Recipe> recipes, Profile p) {
    Recipe? best;
    int bestScore = -0x7fffffff;
    for (final r in recipes) {
      final s = score(r, p);
      if (s > bestScore) {
        bestScore = s;
        best = r;
      }
    }
    return best;
  }

  List<Recipe> sorted(Iterable<Recipe> recipes, Profile p) {
    final list = recipes.toList();
    list.sort((a, b) => score(b, p).compareTo(score(a, p)));
    return list;
  }

  static Map<String, DateTime> fromHistory(List<HistoryEntry> history) {
    final m = <String, DateTime>{};
    for (final h in history) {
      final prev = m[h.recipeId];
      if (prev == null || h.cookedAt.isAfter(prev)) {
        m[h.recipeId] = h.cookedAt;
      }
    }
    return m;
  }
}
