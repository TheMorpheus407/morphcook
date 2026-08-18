import '../models/dish.dart';
import '../models/recipe.dart';

/// Time-aware + staleness-aware ranking bonuses (SPEC):
///
/// - Morning context (5am–11am): breakfast dishes get +200.
/// - Evening context (5pm–9pm): dinner dishes get +90.
/// - Weekend: medium/hard effort recipes get +90.
/// - Not cooked in 30+ days: +50 (recently cooked or never cooked: none).
class Ranking {
  const Ranking();

  static const double morningBreakfastBonus = 200;
  static const double eveningDinnerBonus = 90;
  static const double weekendEffortBonus = 90;
  static const double stalenessBonus = 50;

  /// Temporal context bonus for a dish/recipe pair.
  double timeBonus(Dish dish, Recipe recipe, DateTime now) {
    double bonus = 0;
    final hour = now.hour;
    final weekend = now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    if (hour >= 5 && hour < 11 && dish.isBreakfast) {
      bonus += morningBreakfastBonus;
    }
    if (hour >= 17 && hour < 21 && dish.isDinner) {
      bonus += eveningDinnerBonus;
    }
    if (weekend && (recipe.effort == 'medium' || recipe.effort == 'hard')) {
      bonus += weekendEffortBonus;
    }
    return bonus;
  }

  /// Staleness bonus: recipes not cooked in 30+ days get a nudge to
  /// encourage variety and serendipitous rediscovery.
  double stalenessBonusFor(String recipeId, DateTime? lastCookedAt, DateTime now) {
    if (lastCookedAt == null) return 0;
    final days = now.difference(lastCookedAt).inDays;
    return days >= 30 ? stalenessBonus : 0;
  }

  /// Full feed score for a dish's chosen variant.
  double feedScore({
    required Dish dish,
    required Recipe recipe,
    required DateTime now,
    required DateTime? lastCookedAt,
  }) =>
      100 + timeBonus(dish, recipe, now) + stalenessBonusFor(recipe.id, lastCookedAt, now);
}
