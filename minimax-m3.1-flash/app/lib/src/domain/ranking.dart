import '../models/recipe.dart';

/// Ranking with temporal awareness.
///
/// Two extra passes sit on top of the base relevance score:
///
///  * **Time-aware** — breakfast dishes surface in the morning, dinner
///    dishes in the evening, and weekend cooking leans towards more effort.
///  * **Staleness-aware** — recipes you have not cooked in a while get a
///    nudge, so the cookbook keeps surprising you.
abstract final class Ranking {
  const Ranking._();

  static const int morningStartHour = 5;
  static const int morningEndHour = 11;
  static const int eveningStartHour = 17;
  static const int eveningEndHour = 21;

  static const int breakfastBonus = 200;
  static const int dinnerBonus = 90;
  static const int weekendEffortBonus = 90;

  static const int staleAfterDays = 30;
  static const int staleBonus = 50;

  /// True between 05:00 and 11:00.
  static bool isMorningContext(DateTime now) {
    final hour = now.hour;
    return hour >= morningStartHour && hour < morningEndHour;
  }

  /// True between 17:00 and 21:00.
  static bool isEveningContext(DateTime now) {
    final hour = now.hour;
    return hour >= eveningStartHour && hour < eveningEndHour;
  }

  /// Saturday or Sunday.
  static bool isWeekend(DateTime now) => now.weekday >= DateTime.saturday;

  /// The bonus a recipe earns purely because of the time of day.
  static int timeContextBonus(Recipe recipe, DateTime now) {
    var bonus = 0;
    if (isMorningContext(now) && recipe.isBreakfast) {
      bonus += breakfastBonus;
    }
    if (isEveningContext(now) && recipe.isDinner) {
      bonus += dinnerBonus;
    }
    if (isWeekend(now) && (recipe.effort == 'medium' || recipe.effort == 'hard')) {
      bonus += weekendEffortBonus;
    }
    return bonus;
  }

  /// The bonus a recipe earns because it has been neglected.
  ///
  /// Recipes that were never cooked, or cooked recently, get nothing.
  static int stalenessBonus(
    Recipe recipe,
    Map<String, DateTime> lastCookedAt,
    DateTime now,
  ) {
    final lastCooked = lastCookedAt[recipe.id];
    if (lastCooked == null) return 0;
    final days = now.difference(lastCooked).inDays;
    if (days >= staleAfterDays) return staleBonus;
    return 0;
  }

  /// The full score used to order recipes.
  static int score(
    Recipe recipe, {
    required DateTime now,
    Map<String, DateTime> lastCookedAt = const <String, DateTime>{},
    int baseScore = 0,
  }) {
    return baseScore +
        timeContextBonus(recipe, now) +
        stalenessBonus(recipe, lastCookedAt, now);
  }

  /// Sorts a list of recipes with the full ranking applied.
  static List<Recipe> sort(
    List<Recipe> recipes, {
    required DateTime now,
    Map<String, DateTime> lastCookedAt = const <String, DateTime>{},
    int Function(Recipe recipe)? baseScore,
  }) {
    final scored = recipes.map((recipe) {
      final base = baseScore?.call(recipe) ?? 0;
      return (
        recipe: recipe,
        score: score(
          recipe,
          now: now,
          lastCookedAt: lastCookedAt,
          baseScore: base,
        ),
      );
    }).toList();

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.recipe.title
          .resolve('en')
          .compareTo(b.recipe.title.resolve('en'));
    });

    return scored.map((entry) => entry.recipe).toList(growable: false);
  }
}
