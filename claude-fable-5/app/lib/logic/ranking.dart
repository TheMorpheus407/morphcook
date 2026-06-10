import '../models/collections.dart';
import '../models/profile.dart';
import '../models/recipe.dart';

/// Variant ranking per SPEC.md: when several variants of a dish pass the
/// filter, pick the highest score on
/// match_count(required_attributes) → effort_match → time_closeness →
/// calorie_closeness — then apply time-aware and staleness-aware bonuses.
class Ranker {
  /// Clock injected for testability; defaults to the wall clock.
  final DateTime Function() now;

  Ranker({DateTime Function()? now}) : now = now ?? DateTime.now;

  static const _morningBonus = 200;
  static const _eveningBonus = 90;
  static const _weekendBonus = 90;
  static const _stalenessBonus = 50;
  static const _stalenessDays = 30;

  /// Base lexicographic score, packed into one comparable int.
  int baseScore(Recipe recipe, Profile profile) {
    final attrMatches = profile.requiredAttributes
        .where((a) => recipe.attributes.contains(a))
        .length;
    final effortMatch =
        recipe.variant.effort == profile.preferredEffort ? 1 : 0;

    // Closeness terms normalized to 0..99 so tiers never bleed into
    // each other: attr matches dominate, then effort, then time, calories.
    final maxTime = profile.maxTimeMinutes;
    final timeCloseness = maxTime == null
        ? 50
        : (99 - ((recipe.timeMinutes - maxTime).abs()).clamp(0, 99));
    final target = profile.calorieTarget;
    final calorieCloseness = target == null
        ? 50
        : (99 - ((recipe.caloriesPerServing - target).abs() ~/ 10).clamp(0, 99));

    return attrMatches * 10000000 +
        effortMatch * 1000000 +
        timeCloseness * 1000 +
        calorieCloseness;
  }

  /// Time-aware context bonus: breakfast recipes in the morning (5–11),
  /// dinner recipes in the evening (17–21), weekend boost for medium/hard.
  int contextBonus(Recipe recipe, {DateTime? at}) {
    final t = at ?? now();
    var bonus = 0;
    if (t.hour >= 5 && t.hour < 11 && recipe.meal.contains('breakfast')) {
      bonus += _morningBonus;
    }
    if (t.hour >= 17 && t.hour < 21 && recipe.meal.contains('dinner')) {
      bonus += _eveningBonus;
    }
    final isWeekend =
        t.weekday == DateTime.saturday || t.weekday == DateTime.sunday;
    if (isWeekend &&
        (recipe.variant.effort == 'medium' ||
            recipe.variant.effort == 'hard')) {
      bonus += _weekendBonus;
    }
    return bonus;
  }

  /// Staleness bonus: cooked before, but not within the last 30 days.
  /// Never-cooked and recently-cooked recipes get nothing.
  int stalenessBonus(Recipe recipe, List<HistoryEntry> history,
      {DateTime? at}) {
    final t = at ?? now();
    DateTime? lastCooked;
    for (final entry in history) {
      if (entry.recipeId != recipe.id) continue;
      if (lastCooked == null || entry.cookedAt.isAfter(lastCooked)) {
        lastCooked = entry.cookedAt;
      }
    }
    if (lastCooked == null) return 0;
    return t.difference(lastCooked).inDays >= _stalenessDays
        ? _stalenessBonus
        : 0;
  }

  int totalScore(Recipe recipe, Profile profile, List<HistoryEntry> history,
          {DateTime? at}) =>
      baseScore(recipe, profile) +
      contextBonus(recipe, at: at) +
      stalenessBonus(recipe, history, at: at);

  /// Picks the best visible variant of a dish for the profile.
  Recipe? pickBest(
    Iterable<Recipe> visibleVariants,
    Profile profile,
    List<HistoryEntry> history, {
    DateTime? at,
  }) {
    Recipe? best;
    var bestScore = -1;
    for (final recipe in visibleVariants) {
      final score = totalScore(recipe, profile, history, at: at);
      if (score > bestScore) {
        best = recipe;
        bestScore = score;
      }
    }
    return best;
  }
}
