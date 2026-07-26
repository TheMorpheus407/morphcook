import 'models.dart';
import 'profile.dart';

/// Bonus weights from SPEC.md, kept as named constants so the tests can assert
/// on the numbers rather than on magic literals buried in an expression.
class RankingBonuses {
  static const int morningBreakfast = 200;
  static const int eveningDinner = 90;
  static const int weekendEffort = 90;
  static const int staleRecipe = 50;

  static const int stalenessThresholdDays = 30;
}

/// Base weights. Deliberately spaced by an order of magnitude each so the
/// ordering stays lexicographic: attribute matches always beat effort, effort
/// always beats time closeness, time always beats calorie closeness.
class _Weights {
  static const double attribute = 10000;
  static const double effortExact = 1000;
  static const double effortAdjacent = 400;
  static const double timeSpan = 300;
  static const double calorieSpan = 100;
}

const List<String> _effortOrder = ['easy', 'medium', 'hard'];

class RankedRecipe {
  const RankedRecipe(this.recipe, this.score, this.breakdown);

  final Recipe recipe;
  final double score;
  final Map<String, double> breakdown;
}

class Ranker {
  const Ranker();

  /// [now] and [lastCookedAt] are injected rather than read from the clock so
  /// the ranking stays a pure function and the tests stay deterministic.
  double score(
    Recipe recipe,
    Profile profile, {
    required DateTime now,
    DateTime? lastCookedAt,
  }) => _score(recipe, profile, now: now, lastCookedAt: lastCookedAt).$1;

  Map<String, double> breakdown(
    Recipe recipe,
    Profile profile, {
    required DateTime now,
    DateTime? lastCookedAt,
  }) => _score(recipe, profile, now: now, lastCookedAt: lastCookedAt).$2;

  (double, Map<String, double>) _score(
    Recipe recipe,
    Profile profile, {
    required DateTime now,
    DateTime? lastCookedAt,
  }) {
    final parts = <String, double>{};

    // 1. attribute match count
    final matched = profile.requiredAttributes
        .where(recipe.attributes.contains)
        .length;
    parts['attributes'] = matched * _Weights.attribute;

    // 2. effort match
    final wanted = _effortOrder.indexOf(profile.preferredEffort);
    final actual = _effortOrder.indexOf(recipe.effort);
    if (wanted >= 0 && actual >= 0) {
      final distance = (wanted - actual).abs();
      parts['effort'] = switch (distance) {
        0 => _Weights.effortExact,
        1 => _Weights.effortAdjacent,
        _ => 0.0,
      };
    } else {
      parts['effort'] = 0;
    }

    // 3. time closeness — under budget is good, closer to the budget ceiling is
    //    neutral; we reward recipes that fit comfortably.
    final budget = profile.maxTimeMinutes;
    if (budget > 0) {
      final ratio = (recipe.timeMinutes / budget).clamp(0.0, 1.0);
      parts['time'] = _Weights.timeSpan * (1.0 - ratio);
    } else {
      parts['time'] = 0;
    }

    // 4. calorie closeness
    final target = profile.calorieTarget;
    if (target != null && target > 0) {
      final delta = (recipe.caloriesPerServing - target).abs();
      final ratio = (delta / target).clamp(0.0, 1.0);
      parts['calories'] = _Weights.calorieSpan * (1.0 - ratio);
    } else {
      parts['calories'] = 0;
    }

    // --- time-aware bonuses, applied after the base calculation -------------
    var contextual = 0.0;
    final hour = now.hour;
    if (hour >= 5 && hour < 11 && recipe.mealSlots.contains('breakfast')) {
      contextual += RankingBonuses.morningBreakfast;
    }
    if (hour >= 17 && hour < 21 && recipe.mealSlots.contains('dinner')) {
      contextual += RankingBonuses.eveningDinner;
    }
    final isWeekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    if (isWeekend && (recipe.effort == 'medium' || recipe.effort == 'hard')) {
      contextual += RankingBonuses.weekendEffort;
    }
    parts['context'] = contextual;

    // --- staleness ----------------------------------------------------------
    var staleness = 0.0;
    if (lastCookedAt != null) {
      final days = now.difference(lastCookedAt).inDays;
      if (days >= RankingBonuses.stalenessThresholdDays) {
        staleness = RankingBonuses.staleRecipe.toDouble();
      }
    }
    parts['staleness'] = staleness;

    final total = parts.values.fold<double>(0, (a, b) => a + b);
    return (total, parts);
  }

  /// Highest-scoring recipe first. Ties break on the dish's authored default,
  /// then on id, so ordering is stable across rebuilds.
  List<Recipe> sort(
    Iterable<Recipe> recipes,
    Profile profile, {
    required DateTime now,
    Map<String, DateTime> lastCookedByRecipe = const {},
  }) {
    final scored = recipes
        .map(
          (r) => RankedRecipe(
            r,
            score(r, profile, now: now, lastCookedAt: lastCookedByRecipe[r.id]),
            const {},
          ),
        )
        .toList();
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      if (a.recipe.isDishDefault != b.recipe.isDishDefault) {
        return a.recipe.isDishDefault ? -1 : 1;
      }
      return a.recipe.id.compareTo(b.recipe.id);
    });
    return scored.map((e) => e.recipe).toList(growable: false);
  }

  /// "When multiple variants of a dish pass, pick the one scoring highest."
  Recipe? best(
    Iterable<Recipe> recipes,
    Profile profile, {
    required DateTime now,
    Map<String, DateTime> lastCookedByRecipe = const {},
  }) {
    final sorted = sort(
      recipes,
      profile,
      now: now,
      lastCookedByRecipe: lastCookedByRecipe,
    );
    return sorted.isEmpty ? null : sorted.first;
  }
}
