import '../data/corpus.dart';
import '../logic/matching.dart';
import '../models/models.dart';

/// One dish in a feed slot with its chosen (best visible) recipe.
class FeedEntry {
  final Dish dish;
  final Recipe recipe;
  final double score;
  final DateTime? lastCookedAt;

  FeedEntry({
    required this.dish,
    required this.recipe,
    required this.score,
    this.lastCookedAt,
  });
}

/// All home-feed sections, computed deterministically from pure inputs:
/// corpus, matcher, profile, history, and "now". Ui turns ids into cards.
class FeedSnapshot {
  final DateTime now;
  final Corpus corpus;
  final RecipeMatcher matcher;
  final UserProfile profile;
  final Map<String, DateTime> lastCooked;

  FeedSnapshot({
    required this.now,
    required this.corpus,
    required this.matcher,
    required this.profile,
    required this.lastCooked,
  });

  late final RankingContext ctx = RankingContext(
    now: now,
    lastCookedByRecipe: lastCooked,
  );

  /// Ranks every dish by the best-visible variant's homeScore. Dishes with no
  /// visible variant are dropped from the feed.
  List<FeedEntry> get rankedAll {
    final out = <FeedEntry>[];
    for (final dish in corpus.dishesAll) {
      final variant = matcher.bestForDish(dish, profile);
      if (variant == null) continue;
      final score = homeScore(variant, ctx, profile, matcher);
      out.add(FeedEntry(
        dish: dish,
        recipe: variant,
        score: score,
        lastCookedAt: lastCooked[variant.id],
      ));
    }
    out.sort((a, b) => b.score.compareTo(a.score));
    return out;
  }

  FeedEntry? get featured => rankedAll.isEmpty ? null : rankedAll.first;

  /// Warmly rank without calendar influence (for tests/backups of logic).
  List<FeedEntry> rankedBase() {
    final list = rankedAll;
    list.sort((a, b) =>
        matcher.rankScore(b.recipe, profile).compareTo(
            matcher.rankScore(a.recipe, profile)));
    return list;
  }

  /// "right now": the most recently cooked recipe (resume it) if it still
  /// matches; otherwise null.
  FeedEntry? get rightNow {
    if (lastCooked.isEmpty) return null;
    final latestId = lastCooked.entries.fold<String>(
      '',
      (acc, e) =>
          (acc == '' || e.value.isAfter(lastCooked[acc]!)) ? e.key : acc,
    );
    final recipe = corpus.recipeById(latestId);
    if (recipe == null) return null;
    final dish = corpus.dishById(recipe.dishId);
    if (dish == null) return null;
    if (!matcher.visible(recipe, profile)) return null;
    return FeedEntry(dish: dish, recipe: recipe, score: 0, lastCookedAt: lastCooked[latestId]);
  }

  /// Dishes saved in the cookbook (ordered by save date desc).
  List<FeedEntry> fromCookbook(List<SavedEntry> saved) {
    final out = <FeedEntry>[];
    for (final s in saved) {
      final recipe = corpus.recipeById(s.recipeId);
      if (recipe == null) continue;
      final dish = corpus.dishById(recipe.dishId);
      if (dish == null) continue;
      if (!matcher.visible(recipe, profile)) continue;
      out.add(FeedEntry(
          dish: dish,
          recipe: recipe,
          score: homeScore(recipe, ctx, profile, matcher),
          lastCookedAt: lastCooked[recipe.id]));
    }
    return out;
  }

  /// Quick & easy: dishes with an easy visible variant, top-ranked.
  List<FeedEntry> get quickAndEasy =>
      rankedAll.where((e) => e.recipe.effort == 'easy').take(6).toList();

  /// Rediscover: dishes cooked more than [staleDays] ago, oldest first.
  List<FeedEntry> rediscover({int staleDays = 30}) {
    final list = rankedAll.where((e) {
      final last = e.lastCookedAt;
      if (last == null) return false;
      return now.difference(last).inDays > staleDays;
    }).toList();
    list.sort((a, b) {
      final ad = a.lastCookedAt!;
      final bd = b.lastCookedAt!;
      return ad.compareTo(bd);
    });
    return list.take(6).toList();
  }
}