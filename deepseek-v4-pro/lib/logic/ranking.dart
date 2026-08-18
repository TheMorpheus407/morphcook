import '../models/profile.dart';
import '../models/recipe.dart';
import 'matching.dart';

/// Time-aware + staleness-aware ranking.
///
/// Bonuses apply after the base matching score:
///  - morning (5–11):      breakfast +200
///  - evening (17–21):     dinner    +90
///  - weekend:             medium/hard effort +90
///  - not cooked in 30+ d: +50  (never-cooked gets no bonus)
class Ranker {
  const Ranker();

  bool isMorning(DateTime t) => t.hour >= 5 && t.hour < 11;
  bool isEvening(DateTime t) => t.hour >= 17 && t.hour < 21;
  bool isWeekend(DateTime t) => t.weekday == DateTime.saturday || t.weekday == DateTime.sunday;

  /// Sorted list of visible recipes, best first.
  List<Recipe> rank(
    Iterable<Recipe> recipes,
    Profile profile,
    Matcher matcher, {
    DateTime? now,
    Map<String, DateTime>? lastCookedAt,
    bool overrideCalories = false,
  }) {
    final t = now ?? DateTime.now();
    final sorted = recipes
        .where((r) => matcher.evaluate(r, profile, overrideCalories: overrideCalories).visible)
        .toList();
    sorted.sort((a, b) => totalScore(b, profile, matcher, t, lastCookedAt, overrideCalories)
        .compareTo(totalScore(a, profile, matcher, t, lastCookedAt, overrideCalories)));
    return sorted;
  }

  /// Base matching score + time-aware + staleness bonuses.
  int totalScore(
    Recipe recipe,
    Profile profile,
    Matcher matcher,
    DateTime now, [
    Map<String, DateTime>? lastCookedAt,
    bool overrideCalories = false,
  ]) {
    final base = matcher.score(recipe, profile, overrideCalories: overrideCalories);
    if (base < 0) return base;

    var bonus = 0;
    if (isMorning(now) && recipe.mealTypes.contains('breakfast')) bonus += 200;
    if (isEvening(now) && recipe.mealTypes.contains('dinner')) bonus += 90;
    if (isWeekend(now) && (recipe.effort == 'medium' || recipe.effort == 'hard')) {
      bonus += 90;
    }
    final last = lastCookedAt?[recipe.id];
    if (last != null) {
      if (now.difference(last).inDays > 30) bonus += 50;
    }
    return base + bonus;
  }

  /// Staleness bonus alone (for tests/UI).
  int stalenessBonus(Recipe recipe, DateTime now, Map<String, DateTime>? lastCookedAt) {
    final last = lastCookedAt?[recipe.id];
    if (last != null && now.difference(last).inDays > 30) return 50;
    return 0;
  }
}
