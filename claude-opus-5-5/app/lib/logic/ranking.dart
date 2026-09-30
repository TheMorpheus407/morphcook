import '../models/profile.dart';
import '../models/recipe.dart';

/// Feed ranking: a numeric base score that mirrors the variant ordering
/// (required attributes ≫ effort match ≫ time closeness ≫ calorie
/// closeness), plus the temporal bonuses from the spec applied after it.
class RankingWeights {
  static const requiredAttribute = 1000;
  static const effortMatch = 300;
  static const effortNear = 150;
  static const timeCloseness = 100; // max
  static const calorieCloseness = 100; // max

  static const morningBreakfast = 200;
  static const eveningDinner = 90;
  static const weekendEffort = 90;
  static const stale = 50;
  static const staleAfter = Duration(days: 30);
}

const _effortRank = {'easy': 0, 'medium': 1, 'hard': 2};

int baseScore(Recipe r, Profile p) {
  var score = 0;
  score += RankingWeights.requiredAttribute * p.requiredAttributes.where(r.attributes.contains).length;
  final d = ((_effortRank[r.effort] ?? 1) - (_effortRank[p.preferredEffort] ?? 0)).abs();
  score += d == 0 ? RankingWeights.effortMatch : (d == 1 ? RankingWeights.effortNear : 0);
  final budget = p.maxTimeMinutes;
  final timeGap = budget == null ? r.timeMinutes : (budget - r.timeMinutes).abs();
  score += (RankingWeights.timeCloseness - timeGap).clamp(0, RankingWeights.timeCloseness);
  if (p.calorieTarget != null) {
    final gap = (r.calories - p.calorieTarget!).abs();
    score += (RankingWeights.calorieCloseness - gap ~/ 5).clamp(0, RankingWeights.calorieCloseness);
  }
  return score;
}

/// Morning (5–11) → breakfast +200; evening (17–21) → dinner +90;
/// weekend → medium/hard effort +90.
int timeContextBonus(Recipe r, DateTime now) {
  var bonus = 0;
  final h = now.hour;
  if (h >= 5 && h < 11 && r.mealTypes.contains('breakfast')) {
    bonus += RankingWeights.morningBreakfast;
  }
  if (h >= 17 && h < 21 && r.mealTypes.contains('dinner')) {
    bonus += RankingWeights.eveningDinner;
  }
  final weekend = now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
  if (weekend && (r.effort == 'medium' || r.effort == 'hard')) {
    bonus += RankingWeights.weekendEffort;
  }
  return bonus;
}

/// +50 when the recipe was last cooked 30+ days ago. Never-cooked and
/// recently cooked recipes get nothing.
int stalenessBonus(DateTime? lastCooked, DateTime now) {
  if (lastCooked == null) return 0;
  return now.difference(lastCooked) >= RankingWeights.staleAfter ? RankingWeights.stale : 0;
}

bool isStale(DateTime? lastCooked, DateTime now) => stalenessBonus(lastCooked, now) > 0;

int rankScore(Recipe r, Profile p, DateTime now, {DateTime? lastCooked}) =>
    baseScore(r, p) + timeContextBonus(r, now) + stalenessBonus(lastCooked, now);
