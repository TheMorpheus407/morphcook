import '../models/profile.dart';
import '../models/recipe.dart';

/// Ranking — when several variants of a dish pass the filter, pick the best;
/// and order the home feed. Pure and injectable (clock + history passed in) so
/// it is fully testable.
class Ranker {
  Ranker({required this.profile, DateTime? now, Map<String, DateTime>? lastCooked})
      : now = now ?? DateTime.now(),
        lastCooked = lastCooked ?? const {};

  final Profile profile;
  final DateTime now;

  /// recipeId -> most recent cook timestamp. Drives staleness bonus.
  final Map<String, DateTime> lastCooked;

  /// Base score per spec ordering:
  /// match_count(required_attributes) → effort_match → time_closeness →
  /// calorie_closeness. Encoded as a weighted sum where each later term can
  /// never outrank an earlier one.
  double baseScore(Recipe recipe) {
    final requiredMatches =
        profile.requiredAttributes.where(recipe.attributes.contains).length;

    final effortMatch =
        recipe.variantAxes['effort'] == profile.preferredEffort ? 1 : 0;

    // closeness terms normalised to 0..1 (1 = perfect).
    final timeCloseness = profile.maxTimeMinutes == null
        ? 0.5
        : (1 - (recipe.timeMinutes / profile.maxTimeMinutes!)).clamp(0.0, 1.0);

    final calorieCloseness = profile.calorieTarget == null
        ? 0.5
        : (1 -
                (recipe.calories - profile.calorieTarget!).abs() /
                    (profile.calorieTarget! == 0 ? 1 : profile.calorieTarget!))
            .clamp(0.0, 1.0);

    return requiredMatches * 10000.0 +
        effortMatch * 1000.0 +
        timeCloseness * 100.0 +
        calorieCloseness * 10.0;
  }

  /// Contextual bonuses applied AFTER the base score.
  double contextBonus(Recipe recipe) {
    var bonus = 0.0;

    // Time-aware ranking.
    final hour = now.hour;
    final isMorning = hour >= 5 && hour < 11;
    final isEvening = hour >= 17 && hour < 21;
    final isWeekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;

    if (isMorning && recipe.mealType == 'breakfast') bonus += 200;
    if (isEvening && recipe.mealType == 'dinner') bonus += 90;
    if (isWeekend &&
        (recipe.variantAxes['effort'] == 'medium' ||
            recipe.variantAxes['effort'] == 'hard')) {
      bonus += 90;
    }

    // Staleness-aware ranking: not cooked in 30+ days → +50.
    final last = lastCooked[recipe.id];
    if (last != null && now.difference(last).inDays >= 30) {
      bonus += 50;
    }

    return bonus;
  }

  double score(Recipe recipe) => baseScore(recipe) + contextBonus(recipe);

  /// Among visible variants of a dish, return the highest-scoring one.
  Recipe? bestVariant(Iterable<Recipe> visibleVariants) {
    Recipe? best;
    double bestScore = double.negativeInfinity;
    for (final r in visibleVariants) {
      final s = score(r);
      if (s > bestScore) {
        bestScore = s;
        best = r;
      }
    }
    return best;
  }

  /// Sort recipes by descending score (stable for ties on id).
  List<Recipe> rank(List<Recipe> recipes) {
    final copy = [...recipes];
    copy.sort((a, b) {
      final cmp = score(b).compareTo(score(a));
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });
    return copy;
  }
}
