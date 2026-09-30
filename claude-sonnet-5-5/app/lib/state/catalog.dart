import '../data/corpus.dart';
import '../data/models/dish.dart';
import '../data/models/profile.dart';
import '../data/models/recipe.dart';
import '../domain/ranking.dart';
import '../domain/variants.dart';
import 'controllers/history_controller.dart';
import 'controllers/profile_controller.dart';

typedef Clock = DateTime Function();

/// A dish shown through the variant that suits this person best right now.
class DishPick {
  const DishPick({required this.dish, required this.recipe, required this.score});

  final Dish dish;
  final Recipe recipe;
  final double score;
}

class FeedSection {
  const FeedSection({required this.id, required this.picks, this.cuisine});

  /// `morning`, `midday`, `afternoon`, `evening`, `late`, `quick`, `back` or `cuisine`.
  final String id;
  final List<DishPick> picks;
  final String? cuisine;
}

class Feed {
  const Feed({required this.featured, required this.sections});

  final DishPick? featured;
  final List<FeedSection> sections;

  bool get isEmpty => featured == null;
}

/// Everything a dish page needs: all variants, the ones that pass the profile
/// and the resolver behind the variant switchers.
class DishBundle {
  const DishBundle({required this.dish, required this.all, required this.visible, required this.resolver});

  final Dish dish;
  final List<Recipe> all;
  final List<Recipe> visible;
  final VariantResolver resolver;

  bool get hasVisible => visible.isNotEmpty;
}

/// Combines the corpus with the profile, the cooking history and the ranking.
class Catalog {
  Catalog({
    required this.corpus,
    required this.profileController,
    required this.history,
    this.ranking = const Ranking(),
    Clock? clock,
  }) : clock = clock ?? DateTime.now;

  final Corpus corpus;
  final ProfileController profileController;
  final HistoryController history;
  final Ranking ranking;
  final Clock clock;

  Profile get profile => profileController.profile;

  RankingContext get context => RankingContext(now: clock(), lastCooked: history.lastCooked);

  /// `morning`, `afternoon`, `evening` or `night`, for greetings.
  String dayPart([DateTime? at]) {
    final hour = (at ?? clock()).hour;
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 22) return 'evening';
    return 'night';
  }

  /// Variants of [dish] that pass the profile filters. The per-dish calorie
  /// override lifts only the calorie rule.
  List<Recipe> visibleVariants(Dish dish, {bool? ignoreCalories}) {
    final ignore = ignoreCalories ?? profileController.calorieOverrideFor(dish.id);
    final filter = profileController.filter;
    return [
      for (final recipe in corpus.recipesOfDishSync(dish.id))
        if (filter.isVisible(recipe, ignoreCalories: ignore)) recipe,
    ];
  }

  DishPick? pickFor(Dish dish, {RankingContext? context}) {
    final ctx = context ?? this.context;
    final best = ranking.bestOf(visibleVariants(dish), profile, ctx);
    if (best == null) return null;
    return DishPick(dish: dish, recipe: best, score: ranking.score(best, profile, ctx));
  }

  /// Picks for every dish whose recipes are in memory, best first.
  List<DishPick> rankedPicks(Iterable<Dish> dishes) {
    final ctx = context;
    final picks = <DishPick>[];
    for (final dish in dishes) {
      if (!corpus.isPartitionLoaded(dish.partitionId)) continue;
      final pick = pickFor(dish, context: ctx);
      if (pick != null) picks.add(pick);
    }
    picks.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.dish.id.compareTo(b.dish.id);
    });
    return picks;
  }

  /// The launch feed: featured dish plus the sections that need no extra
  /// partition. Cuisine sections follow through [cuisineSections].
  Feed buildFeed() {
    final all = rankedPicks(corpus.dishes.values);
    if (all.isEmpty) return const Feed(featured: null, sections: <FeedSection>[]);
    final featured = all.first;
    final used = <String>{featured.dish.id};

    final moment = all.skip(1).take(4).toList();
    used.addAll(moment.map((p) => p.dish.id));

    final ctx = context;
    final quickAll = [
      for (final p in all)
        if (p.recipe.timeMinutes <= 30) p,
    ];
    var quick = [
      for (final p in quickAll)
        if (!used.contains(p.dish.id)) p,
    ].take(4).toList();
    if (quick.length < 2) quick = quickAll.take(4).toList();

    final threshold = ranking.config.stalenessDays;
    final back = [
      for (final p in all)
        if (ctx.lastCooked[p.recipe.id] != null && ctx.now.difference(ctx.lastCooked[p.recipe.id]!).inDays >= threshold)
          p,
    ].take(4).toList();

    return Feed(
      featured: featured,
      sections: [
        if (moment.isNotEmpty) FeedSection(id: _momentId(ctx.now), picks: moment),
        if (quick.isNotEmpty) FeedSection(id: 'quick', picks: quick),
        if (back.isNotEmpty) FeedSection(id: 'back', picks: back),
      ],
    );
  }

  String _momentId(DateTime now) {
    final hour = now.hour;
    if (hour >= 5 && hour < 11) return 'morning';
    if (hour >= 11 && hour < 15) return 'midday';
    if (hour >= 15 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 21) return 'evening';
    return 'late';
  }

  /// Discovery sections per cuisine partition. Loads the partitions on demand.
  Future<List<FeedSection>> cuisineSections({int perSection = 4}) async {
    final sections = <FeedSection>[];
    for (final partition in corpus.manifest.partitions) {
      if (partition.kind != 'cuisine' || partition.cuisine == null) continue;
      await corpus.ensurePartition(partition.id);
      final dishes = corpus.dishesInCuisine(partition.cuisine!);
      // Also surface dishes stored in the partition itself.
      final all = {...dishes, ...corpus.dishesInPartition(partition.id)}.toList();
      final picks = rankedPicks(all).take(perSection).toList();
      if (picks.isNotEmpty) sections.add(FeedSection(id: 'cuisine', picks: picks, cuisine: partition.cuisine));
    }
    return sections;
  }

  /// Loads a dish and builds its switcher. [include] keeps one specific
  /// variant reachable even if the profile filters it out (a saved recipe that
  /// no longer fits after the profile changed).
  Future<DishBundle> openDish(String dishId, {String? include}) async {
    final dish = corpus.dishes[dishId]!;
    final all = await corpus.loadDish(dishId);
    return bundleOf(dish, all, include: include);
  }

  DishBundle bundleOf(Dish dish, List<Recipe> all, {String? include}) {
    final visible = visibleVariants(dish);
    final candidates = [...visible];
    if (include != null && !visible.any((r) => r.id == include)) {
      for (final recipe in all) {
        if (recipe.id == include) candidates.add(recipe);
      }
    }
    final basis = candidates.isNotEmpty ? candidates : all;
    return DishBundle(
      dish: dish,
      all: all,
      visible: visible,
      resolver: VariantResolver(
        ontology: corpus.ontology,
        candidates: basis,
        ranking: ranking,
        profile: profile,
        context: context,
      ),
    );
  }
}
