// The one boring ChangeNotifier that owns profile, collections and the
// corpus handle. Screens read it with Provider; ephemeral state
// (pagination, cook sessions) lives in per-screen controllers.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/week.dart';
import '../data/corpus_repository.dart';
import '../data/local_store.dart';
import '../data/models/dish.dart';
import '../data/models/history_entry.dart';
import '../data/models/meal_plan.dart';
import '../data/models/profile.dart';
import '../data/models/recipe.dart';
import '../data/models/shopping.dart';
import '../domain/backup_codec.dart';
import '../domain/cook_session.dart';
import '../domain/matching.dart';
import '../domain/ranking.dart';
import '../domain/search_engine.dart';
import '../domain/shopping_aggregator.dart';
import '../domain/shopping_insights.dart';
import '../domain/variant_lattice.dart';

/// A dish paired with the variant the profile would open first.
class DishCard {
  const DishCard({required this.dish, required this.recipe, required this.score});
  final Dish dish;
  final Recipe recipe;
  final int score;
}

class FeedSection {
  const FeedSection({required this.id, required this.cards, this.arg});
  final String id;
  final List<DishCard> cards;
  final String? arg;
}

class FeedModel {
  const FeedModel({required this.featured, required this.sections, required this.hiddenDishCount, required this.visibleDishCount, required this.moment});
  final DishCard? featured;
  final List<FeedSection> sections;
  final int hiddenDishCount;
  final int visibleDishCount;

  /// morning | evening | day
  final String moment;
  bool get isEmpty => featured == null && sections.every((s) => s.cards.isEmpty);
}

class AppController extends ChangeNotifier {
  AppController({
    required this.repo,
    required this.store,
    required this.profileStore,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final CorpusRepository repo;
  final KeyValueStore store;
  final ProfileStore profileStore;
  final DateTime Function() _clock;

  static const _kSaved = 'saved';
  static const _kHistory = 'history';
  static const _kMealPlan = 'meal_plan';
  static const _kShopping = 'shopping';
  static const _kCookProgress = 'cook_progress';
  static const _kContentRequests = 'content_requests';

  Profile _profile = const Profile();
  Profile get profile => _profile;
  String get lang => _profile.lang;

  bool _initialized = false;
  bool get initialized => _initialized;
  Object? _initError;
  Object? get initError => _initError;

  Map<String, DateTime> _saved = {};
  List<HistoryEntry> _history = [];
  MealPlan _mealPlan = MealPlan();
  ShoppingState _shopping = ShoppingState();
  Map<String, CookProgress> _cookProgress = {};
  List<String> _contentRequests = [];

  MatchContext? _matchCtx;
  Profile? _matchProfile;
  late final SearchEngine search = SearchEngine(repo);
  StreamSubscription<String>? _partitionSub;

  DateTime now() => _clock();

  // ---------------------------------------------------------------- init

  Future<void> init() async {
    try {
      await store.init();
      final pj = await profileStore.load();
      if (pj != null) _profile = Profile.fromJson(pj);
      _loadCollections();
      await repo.load();
      _partitionSub = repo.onPartitionLoaded.listen((_) => notifyListeners());
      _initialized = true;
      notifyListeners();
      // Warm the rarely used partition once the first frame is out.
      unawaited(Future<void>.delayed(const Duration(milliseconds: 600), () => repo.prefetchIdle().catchError((_) {})));
    } catch (e, st) {
      _initError = e;
      debugPrint('init failed: $e\n$st');
      notifyListeners();
    }
  }

  void _loadCollections() {
    final saved = store.get(_kSaved);
    _saved = {
      if (saved is Map)
        for (final e in saved.entries)
          if (DateTime.tryParse(e.value.toString()) != null) e.key.toString(): DateTime.parse(e.value.toString()).toLocal(),
    };
    final hist = store.get(_kHistory);
    _history = [
      if (hist is List)
        for (final h in hist.whereType<Map>()) HistoryEntry.fromJson(h.cast<String, dynamic>()),
    ]..sort((a, b) => b.cookedAt.compareTo(a.cookedAt));
    final plan = store.get(_kMealPlan);
    _mealPlan = MealPlan.fromJson(plan is Map ? plan.cast<String, dynamic>() : null);
    final shop = store.get(_kShopping);
    _shopping = ShoppingState.fromJson(shop is Map ? shop.cast<String, dynamic>() : null);
    final prog = store.get(_kCookProgress);
    _cookProgress = {
      if (prog is Map)
        for (final e in prog.entries)
          if (e.value is Map) e.key.toString(): CookProgress.fromJson((e.value as Map).cast<String, dynamic>()),
    };
    final cr = store.get(_kContentRequests);
    _contentRequests = [if (cr is List) ...cr.map((e) => e.toString())];
  }

  @override
  void dispose() {
    _partitionSub?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------- profile

  Future<void> updateProfile(Profile p) async {
    _profile = p;
    _matchCtx = null;
    await profileStore.save(p.toJson());
    notifyListeners();
  }

  Future<void> setLang(String lang) => updateProfile(_profile.copyWith(lang: lang));

  MatchContext get matchContext {
    if (_matchCtx == null || _matchProfile != _profile) {
      _matchCtx = MatchContext.from(_profile, repo.ontology, repo.ingredients);
      _matchProfile = _profile;
    }
    return _matchCtx!;
  }

  RankContext rankContext({DateTime? at}) => RankContext(now: at ?? now(), lastCookedByRecipe: lastCookedByRecipe);

  // -------------------------------------------------------------- corpus

  Dish? dish(String id) => repo.dish(id);
  Recipe? recipeIfLoaded(String id) => repo.recipeIfLoaded(id);
  Future<Recipe?> recipe(String id) => repo.recipe(id);
  Future<List<Recipe>> variantsOf(String dishId) => repo.variantsOf(dishId);

  VariantLattice latticeFor(Dish d) => VariantLattice(dish: d, recipes: repo.variantsIfLoaded(d.id), ontology: repo.ontology);

  /// Best variant for the profile, or null when nothing in the dish is
  /// visible (or the partition is not loaded yet).
  DishCard? cardFor(Dish d, {DateTime? at, bool includeOutsideCalories = false}) {
    final variants = repo.variantsIfLoaded(d.id);
    if (variants.isEmpty) return null;
    final ctx = matchContext;
    final visible = visibleRecipes(variants, ctx, ignoreCalories: includeOutsideCalories);
    if (visible.isEmpty) return null;
    final rank = rankContext(at: at);
    final best = pickBest(visible, _profile, rank)!;
    return DishCard(dish: d, recipe: best, score: score(best, _profile, rank));
  }

  List<DishCard> visibleCards({DateTime? at, bool includeOutsideCalories = false}) {
    final cards = <DishCard>[];
    for (final d in repo.dishes) {
      final c = cardFor(d, at: at, includeOutsideCalories: includeOutsideCalories);
      if (c != null) cards.add(c);
    }
    cards.sort((a, b) {
      final c = b.score.compareTo(a.score);
      return c != 0 ? c : a.dish.id.compareTo(b.dish.id);
    });
    return cards;
  }

  String momentOf(DateTime t) {
    final h = t.hour;
    if (h >= 5 && h < 11) return 'morning';
    if (h >= 17 && h < 21) return 'evening';
    return 'day';
  }

  FeedModel buildFeed({DateTime? at}) {
    final t = at ?? now();
    final moment = momentOf(t);
    final cards = visibleCards(at: t);
    final loadedDishes = repo.dishes.where((d) => repo.variantsIfLoaded(d.id).isNotEmpty).length;
    final hidden = loadedDishes - cards.length;
    if (cards.isEmpty) {
      return FeedModel(featured: null, sections: const [], hiddenDishCount: hidden, visibleDishCount: 0, moment: moment);
    }
    final featured = cards.first;
    final rest = cards.skip(1).toList();
    final sections = <FeedSection>[];

    final nowMeal = switch (moment) { 'morning' => 'breakfast', 'evening' => 'dinner', _ => 'lunch' };
    final nowCards = rest.where((c) => c.recipe.mealTypes.contains(nowMeal) || c.dish.mealTypes.contains(nowMeal)).take(6).toList();
    if (nowCards.isNotEmpty) sections.add(FeedSection(id: 'now', cards: nowCards, arg: moment));

    final quick = rest.where((c) => c.recipe.timeMinutes <= 30 && !nowCards.contains(c)).take(6).toList();
    if (quick.isNotEmpty) sections.add(FeedSection(id: 'quick', cards: quick));

    final savedDishIds = <String>{};
    final savedCards = <DishCard>[];
    for (final id in savedIdsNewestFirst) {
      final r = repo.recipeIfLoaded(id);
      final d = r == null ? null : repo.dish(r.dishId);
      if (r == null || d == null || !savedDishIds.add(d.id)) continue;
      savedCards.add(DishCard(dish: d, recipe: r, score: 0));
      if (savedCards.length >= 6) break;
    }
    if (savedCards.isNotEmpty) sections.add(FeedSection(id: 'saved', cards: savedCards));

    final again = <DishCard>[];
    final last = lastCookedByRecipe;
    for (final c in cards) {
      final lc = last[c.recipe.id];
      if (lc != null && t.difference(lc).inDays >= kStalenessDays) again.add(c);
      if (again.length >= 6) break;
    }
    if (again.isNotEmpty) sections.add(FeedSection(id: 'again', cards: again));

    for (final cuisine in const ['italian', 'asian', 'middle-eastern']) {
      final partition = 'cuisine-$cuisine';
      final cs = cards.where((c) => c.dish.secondaryPartitions.contains(partition)).take(6).toList();
      if (cs.isNotEmpty) sections.add(FeedSection(id: 'cuisine', cards: cs, arg: cuisine));
    }
    sections.add(FeedSection(id: 'all', cards: cards));
    return FeedModel(featured: featured, sections: sections, hiddenDishCount: hidden, visibleDishCount: cards.length, moment: moment);
  }

  // --------------------------------------------------------------- saved

  bool isSaved(String recipeId) => _saved.containsKey(recipeId);
  DateTime? savedAt(String recipeId) => _saved[recipeId];
  int get savedCount => _saved.length;

  List<String> get savedIdsNewestFirst {
    final entries = _saved.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in entries) e.key];
  }

  Future<void> toggleSaved(String recipeId) async {
    if (_saved.containsKey(recipeId)) {
      _saved.remove(recipeId);
    } else {
      _saved[recipeId] = now();
    }
    await _persistSaved();
    notifyListeners();
  }

  Future<void> _persistSaved() =>
      store.put(_kSaved, {for (final e in _saved.entries) e.key: e.value.toUtc().toIso8601String()});

  // ------------------------------------------------------------- history

  List<HistoryEntry> get history => List.unmodifiable(_history);

  Map<String, DateTime> get lastCookedByRecipe {
    final out = <String, DateTime>{};
    for (final h in _history) {
      final cur = out[h.recipeId];
      if (cur == null || h.cookedAt.isAfter(cur)) out[h.recipeId] = h.cookedAt;
    }
    return out;
  }

  int timesCooked(String recipeId) => _history.where((h) => h.recipeId == recipeId).length;

  Future<void> addHistory(HistoryEntry e) async {
    _history.insert(0, e);
    _history.sort((a, b) => b.cookedAt.compareTo(a.cookedAt));
    await store.put(_kHistory, _history.map((h) => h.toJson()).toList());
    notifyListeners();
  }

  // ----------------------------------------------------------- meal plan

  MealPlan get mealPlan => _mealPlan;

  Future<void> _persistPlan() => store.put(_kMealPlan, _mealPlan.toJson());

  Future<void> assignMeal(String weekKey, String slot, String recipeId) async {
    _mealPlan.assign(weekKey, slot, recipeId);
    await _persistPlan();
    notifyListeners();
  }

  Future<void> clearMeal(String weekKey, String slot) async {
    _mealPlan.clear(weekKey, slot);
    await _persistPlan();
    notifyListeners();
  }

  Future<void> moveMeal(String fromWeek, String fromSlot, String toWeek, String toSlot) async {
    _mealPlan.move(fromWeek, fromSlot, toWeek, toSlot);
    await _persistPlan();
    notifyListeners();
  }

  /// One-tap export: every planned recipe of the week onto the list.
  Future<int> exportWeekToShopping(String weekKey) async {
    var n = 0;
    for (final id in _mealPlan.recipeIdsInWeek(weekKey)) {
      final r = await repo.recipe(id);
      if (r == null) continue;
      await addToShopping(r, notify: false);
      n++;
    }
    notifyListeners();
    return n;
  }

  String get currentWeekKey => weekKeyOf(now());

  // ------------------------------------------------------------ shopping

  ShoppingState get shopping => _shopping;

  Future<void> _persistShopping() => store.put(_kShopping, _shopping.toJson());

  bool isOnShoppingList(String recipeId) => _shopping.sources.any((s) => s.recipeId == recipeId);

  Future<void> addToShopping(Recipe r, {int? servings, bool notify = true}) async {
    final idx = _shopping.sources.indexWhere((s) => s.recipeId == r.id);
    final t = now();
    final src = ShoppingSource(recipeId: r.id, servings: servings ?? r.servings, addedAt: t);
    if (idx >= 0) {
      _shopping.sources[idx] = src;
    } else {
      _shopping.sources.add(src);
      for (final i in r.ingredients) {
        _shopping.log.add(ShoppingLogEntry(ingredientId: i.id, addedAt: t));
      }
    }
    await _persistShopping();
    if (notify) notifyListeners();
  }

  Future<void> removeFromShopping(String recipeId) async {
    _shopping.sources.removeWhere((s) => s.recipeId == recipeId);
    await _persistShopping();
    notifyListeners();
  }

  Future<void> setShoppingServings(String recipeId, int servings) async {
    final idx = _shopping.sources.indexWhere((s) => s.recipeId == recipeId);
    if (idx < 0) return;
    final s = _shopping.sources[idx];
    _shopping.sources[idx] = ShoppingSource(recipeId: s.recipeId, servings: servings.clamp(1, 24), addedAt: s.addedAt);
    await _persistShopping();
    notifyListeners();
  }

  Future<void> toggleChecked(String key) async {
    if (!_shopping.checked.remove(key)) _shopping.checked.add(key);
    await _persistShopping();
    notifyListeners();
  }

  Future<void> addManualItem(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    _shopping.manual.add(ManualItem(id: 'm${now().microsecondsSinceEpoch}', text: t));
    await _persistShopping();
    notifyListeners();
  }

  Future<void> removeManualItem(String id) async {
    _shopping.manual.removeWhere((m) => m.id == id);
    _shopping.checked.remove(id);
    await _persistShopping();
    notifyListeners();
  }

  /// Removes ticked manual items and un-ticks everything else; recipe
  /// lines come back when the recipe is still on the list.
  Future<void> clearChecked() async {
    _shopping.manual.removeWhere((m) => _shopping.checked.contains(m.id));
    _shopping.checked.clear();
    await _persistShopping();
    notifyListeners();
  }

  Future<void> clearShopping() async {
    _shopping = ShoppingState(log: _shopping.log);
    await _persistShopping();
    notifyListeners();
  }

  List<ShoppingInput> get shoppingInputs => [
        for (final s in _shopping.sources)
          if (repo.recipeIfLoaded(s.recipeId) != null) ShoppingInput(recipe: repo.recipeIfLoaded(s.recipeId)!, servings: s.servings),
      ];

  ShoppingAggregator get aggregator => ShoppingAggregator(ontology: repo.ontology, dictionary: repo.ingredients);

  List<AggregatedLine> aggregatedShopping() => aggregator.aggregate(shoppingInputs, lang: lang);

  List<AisleGroup> shoppingByAisle() => aggregator.groupByAisle(aggregatedShopping());

  Future<void> ensureShoppingRecipesLoaded() async {
    for (final s in _shopping.sources) {
      await repo.ensureRecipe(s.recipeId);
    }
  }

  ShoppingInsights get insights => computeInsights(_shopping.log);

  // ---------------------------------------------------- content requests

  List<String> get contentRequests => List.unmodifiable(_contentRequests);

  Future<void> logContentRequest(String query) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2 || _contentRequests.contains(q)) return;
    _contentRequests.add(q);
    if (_contentRequests.length > 200) _contentRequests.removeAt(0);
    await store.put(_kContentRequests, _contentRequests);
  }

  // ------------------------------------------------------- cook progress

  CookProgress? progressFor(String recipeId) => _cookProgress[recipeId];

  Future<void> saveProgress(CookProgress p) async {
    _cookProgress[p.recipeId] = p;
    await store.put(_kCookProgress, {for (final e in _cookProgress.entries) e.key: e.value.toJson()});
  }

  Future<void> clearProgress(String recipeId) async {
    _cookProgress.remove(recipeId);
    await store.put(_kCookProgress, {for (final e in _cookProgress.entries) e.key: e.value.toJson()});
    notifyListeners();
  }

  // -------------------------------------------------------------- backup

  BackupData buildBackup() => BackupData(
        exportedAt: now(),
        profile: _profile,
        saved: savedIdsNewestFirst,
        mealPlan: MealPlan.fromJson(_mealPlan.toJson()),
        history: List.of(_history),
        contentRequests: List.of(_contentRequests),
        savedAt: Map.of(_saved),
        shopping: ShoppingState.fromJson(_shopping.toJson()),
      );

  Future<void> applyBackup(BackupData incoming, MergeMode mode) async {
    final merged = BackupCodec.merge(buildBackup(), incoming, mode);
    _profile = merged.profile.copyWith(onboardingComplete: true);
    _matchCtx = null;
    await profileStore.save(_profile.toJson());
    _saved = {
      for (final id in merged.saved) id: merged.savedAt[id] ?? now(),
    };
    await _persistSaved();
    _history = List.of(merged.history)..sort((a, b) => b.cookedAt.compareTo(a.cookedAt));
    await store.put(_kHistory, _history.map((h) => h.toJson()).toList());
    _mealPlan = merged.mealPlan;
    await _persistPlan();
    if (merged.shopping != null) {
      _shopping = merged.shopping!;
      await _persistShopping();
    }
    _contentRequests = List.of(merged.contentRequests);
    await store.put(_kContentRequests, _contentRequests);
    notifyListeners();
  }
}
