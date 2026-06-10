import '../models/profile.dart';
import '../models/recipe.dart';
import '../util/time_context.dart';
import 'matching.dart';

/// Time-aware and staleness-aware ranking adjustments applied on top of
/// [baseScore]. Encapsulates the bonuses described in SPEC.md.
class RankingContext {
  final DateTime now;
  final Map<String, DateTime> lastCookedByRecipeId;

  const RankingContext({required this.now, required this.lastCookedByRecipeId});

  factory RankingContext.fromHistory(
    Iterable<MapEntry<String, DateTime>> history, {
    DateTime? now,
  }) {
    final map = <String, DateTime>{};
    for (final e in history) {
      final cur = map[e.key];
      if (cur == null || cur.isBefore(e.value)) {
        map[e.key] = e.value;
      }
    }
    return RankingContext(
      now: now ?? DateTime.now(),
      lastCookedByRecipeId: map,
    );
  }
}

int rank(Recipe recipe, Profile profile, RankingContext ctx) {
  var score = baseScore(recipe, profile);
  score += _timeContextBonus(recipe, ctx.now);
  score += _stalenessBonus(recipe, ctx);
  return score;
}

/// +200 for breakfast in mornings, +90 for dinner in evenings,
/// +90 for medium/hard on weekends.
int _timeContextBonus(Recipe recipe, DateTime now) {
  final ctx = TimeContext.from(now);
  var bonus = 0;
  final isBreakfast = recipe.attributes.contains('breakfast');
  final isDinner = recipe.attributes.contains('dinner');
  if (ctx.isMorning && isBreakfast) bonus += 200;
  if (ctx.isEvening && isDinner) bonus += 90;
  if (ctx.isWeekend &&
      (recipe.effort == 'medium' || recipe.effort == 'hard')) {
    bonus += 90;
  }
  return bonus;
}

/// +50 if not cooked in ≥30 days. Never-cooked or recently-cooked: 0.
int _stalenessBonus(Recipe recipe, RankingContext ctx) {
  final lastCooked = ctx.lastCookedByRecipeId[recipe.id];
  if (lastCooked == null) return 0;
  final daysSince = ctx.now.difference(lastCooked).inDays;
  if (daysSince >= 30) return 50;
  return 0;
}
