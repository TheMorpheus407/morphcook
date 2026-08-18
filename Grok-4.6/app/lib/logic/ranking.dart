import '../models/collections.dart';
import '../models/profile.dart';
import '../models/recipe.dart';

class Ranker {
  final DateTime Function() now;

  Ranker({DateTime Function()? now}) : now = now ?? DateTime.now;

  static const morningBonus = 200;
  static const eveningBonus = 90;
  static const weekendBonus = 90;
  static const staleBoost = 50;
  static const stalenessDays = 30;

  int baseScore(Recipe recipe, Profile profile) {
    final attrMatches = profile.requiredAttributes
        .where((a) => recipe.attributes.contains(a))
        .length;
    final effortMatch = recipe.variant.effort == profile.preferredEffort ? 1 : 0;

    final maxTime = profile.maxTimeMinutes;
    final timeCloseness = maxTime == null
        ? 50
        : (99 - ((recipe.timeMinutes - maxTime).abs()).clamp(0, 99));
    final target = profile.calorieTarget;
    final calorieCloseness = target == null
        ? 50
        : (99 -
            ((recipe.caloriesPerServing - target).abs() ~/ 10).clamp(0, 99));

    return attrMatches * 10000000 +
        effortMatch * 1000000 +
        timeCloseness * 1000 +
        calorieCloseness;
  }

  int contextBonus(Recipe recipe, {DateTime? at}) {
    final t = at ?? now();
    var bonus = 0;
    if (t.hour >= 5 && t.hour < 11 && recipe.meal.contains('breakfast')) {
      bonus += morningBonus;
    }
    if (t.hour >= 17 && t.hour < 21 && recipe.meal.contains('dinner')) {
      bonus += eveningBonus;
    }
    final isWeekend =
        t.weekday == DateTime.saturday || t.weekday == DateTime.sunday;
    if (isWeekend &&
        (recipe.variant.effort == 'medium' || recipe.variant.effort == 'hard')) {
      bonus += weekendBonus;
    }
    return bonus;
  }

  int stalenessBonus(
    Recipe recipe,
    List<HistoryEntry> history, {
    DateTime? at,
  }) {
    final t = at ?? now();
    DateTime? lastCooked;
    for (final entry in history) {
      if (entry.recipeId != recipe.id) continue;
      if (lastCooked == null || entry.cookedAt.isAfter(lastCooked)) {
        lastCooked = entry.cookedAt;
      }
    }
    if (lastCooked == null) return 0;
    return t.difference(lastCooked).inDays >= stalenessDays ? staleBoost : 0;
  }

  int totalScore(
    Recipe recipe,
    Profile profile,
    List<HistoryEntry> history, {
    DateTime? at,
  }) =>
      baseScore(recipe, profile) +
      contextBonus(recipe, at: at) +
      stalenessBonus(recipe, history, at: at);

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

  List<Recipe> rank(
    Iterable<Recipe> recipes,
    Profile profile,
    List<HistoryEntry> history, {
    DateTime? at,
  }) {
    final list = recipes.toList();
    list.sort((a, b) {
      final byScore = totalScore(b, profile, history, at: at)
          .compareTo(totalScore(a, profile, history, at: at));
      if (byScore != 0) return byScore;
      return a.title.of(profile.lang).compareTo(b.title.of(profile.lang));
    });
    return list;
  }
}
