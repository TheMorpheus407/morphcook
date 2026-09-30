import '../models/profile.dart';
import '../models/recipe.dart';
import 'matching.dart';
import 'ranking.dart';

class FeedItem {
  const FeedItem(this.dish, this.recipe, this.score);
  final Dish dish;
  final Recipe recipe;
  final int score;
}

class Feed {
  const Feed({
    required this.featured,
    required this.now,
    required this.quick,
    required this.fromCookbook,
    required this.rediscover,
    required this.byCuisine,
    required this.all,
  });

  final FeedItem? featured;
  final List<FeedItem> now;
  final List<FeedItem> quick;
  final List<FeedItem> fromCookbook;
  final List<FeedItem> rediscover;
  final Map<String, List<FeedItem>> byCuisine;
  final List<FeedItem> all;

  bool get isEmpty => all.isEmpty;
}

/// Builds the home feed: one best-fitting variant per dish, ranked with the
/// time-of-day, weekend and staleness bonuses.
Feed buildFeed({
  required Iterable<Dish> dishes,
  required List<Recipe> Function(String dishId) variantsOf,
  required Recipe? Function(String recipeId) recipeById,
  required Profile profile,
  required MatchContext ctx,
  required DateTime now,
  required Map<String, DateTime> lastCooked,
  required List<String> savedNewestFirst,
  required bool Function(String dishId) calorieOverride,
  required String lang,
  int sectionSize = 4,
}) {
  final items = <FeedItem>[];
  for (final dish in dishes) {
    final variants = variantsOf(dish.id);
    if (variants.isEmpty) continue;
    final best = bestVisibleVariant(variants, profile, ctx, ignoreCalories: calorieOverride(dish.id));
    if (best == null) continue;
    items.add(FeedItem(dish, best, rankScore(best, profile, now, lastCooked: lastCooked[best.id])));
  }
  int byScore(FeedItem a, FeedItem b) =>
      a.score != b.score ? b.score.compareTo(a.score) : a.dish.id.compareTo(b.dish.id);
  final ranked = [...items]..sort(byScore);

  FeedItem? featured;
  if (ranked.isNotEmpty) {
    final pool = ranked.take(3).toList();
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    featured = pool[dayOfYear % pool.length];
  }
  final rest = ranked.where((i) => i != featured).toList();

  final nowItems = rest.where((i) => timeContextBonus(i.recipe, now) > 0).take(sectionSize).toList();
  final quick = rest.where((i) => i.recipe.timeMinutes <= 30).take(sectionSize).toList();

  final fromCookbook = <FeedItem>[];
  for (final id in savedNewestFirst) {
    final r = recipeById(id);
    if (r == null) continue;
    final dish = dishes.where((d) => d.id == r.dishId).firstOrNull;
    if (dish == null || !isVisible(r, ctx, ignoreCalories: calorieOverride(dish.id))) continue;
    fromCookbook.add(FeedItem(dish, r, rankScore(r, profile, now, lastCooked: lastCooked[r.id])));
    if (fromCookbook.length >= sectionSize) break;
  }

  final rediscover = <FeedItem>[];
  final stale = lastCooked.entries.where((e) => isStale(e.value, now)).toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  for (final e in stale) {
    final r = recipeById(e.key);
    if (r == null) continue;
    final dish = dishes.where((d) => d.id == r.dishId).firstOrNull;
    if (dish == null || !isVisible(r, ctx, ignoreCalories: calorieOverride(dish.id))) continue;
    rediscover.add(FeedItem(dish, r, rankScore(r, profile, now, lastCooked: e.value)));
    if (rediscover.length >= sectionSize) break;
  }

  final byCuisine = <String, List<FeedItem>>{};
  for (final i in ranked) {
    byCuisine.putIfAbsent(i.dish.cuisine, () => []).add(i);
  }

  final all = [...items]..sort((a, b) => a.dish.name.of(lang).compareTo(b.dish.name.of(lang)));
  return Feed(
    featured: featured,
    now: nowItems,
    quick: quick,
    fromCookbook: fromCookbook,
    rediscover: rediscover,
    byCuisine: byCuisine,
    all: all,
  );
}
