import 'package:flutter/foundation.dart';

import '../core/data/corpus.dart';
import '../core/matching/matcher.dart';
import '../core/matching/ranking.dart';
import '../core/models/dish.dart';
import '../core/models/localized_text.dart';
import '../core/models/profile.dart';
import '../core/models/recipe.dart';
import '../core/models/user_data.dart';
import '../core/services/collection_store.dart';
import '../core/services/profile_store.dart';
import '../core/shopping/aggregator.dart';
import '../core/shopping/insights.dart';

/// Root app state — one ChangeNotifier wiring corpus, profile and the
/// persisted collections together (SPEC: "keep it boring").
class AppState extends ChangeNotifier {
  AppState({
    required this.corpus,
    required this.profileStore,
    required this.collections,
  })  : profile = profileStore.load(),
        onboardingDone = profileStore.onboardingDone {
    _ontologyRef = OntologyRef.fromCorpus(corpus);
  }

  final Corpus corpus;
  final ProfileStore profileStore;
  final CollectionStore collections;

  final Matcher matcher = const Matcher();
  final Ranking ranking = const Ranking();

  Profile profile;
  bool onboardingDone;

  List<SavedEntry> saved = [];
  List<HistoryEntry> history = [];
  MealPlan mealPlan = MealPlan();
  List<ShoppingItem> shoppingItems = [];
  List<ShoppingAddition> shoppingAdditions = [];
  List<ContentRequest> contentRequests = [];

  late OntologyRef _ontologyRef;

  /// Loads persisted collections + all corpus partitions (on-demand fetch).
  Future<void> load() async {
    await corpus.ensureAll();
    saved = collections.loadSaved();
    history = collections.loadHistory();
    mealPlan = collections.loadMealPlan();
    shoppingItems = collections.loadShoppingItems();
    shoppingAdditions = collections.loadShoppingAdditions();
    contentRequests = collections.loadContentRequests();
    notifyListeners();
  }

  OntologyRef get ontologyRef => _ontologyRef;

  String get lang => profile.lang;

  // ---------------- profile ----------------

  Future<void> updateProfile(Profile updated) async {
    profile = updated;
    await profileStore.save(profile);
    notifyListeners();
  }

  Future<void> completeOnboarding(Profile done) async {
    await updateProfile(done);
    onboardingDone = true;
    await profileStore.setOnboardingDone();
    notifyListeners();
  }

  // ---------------- visibility ----------------

  bool isVisible(Recipe recipe, {String? dishId}) {
    final override = dishId != null && profileStore.calorieOverrides().contains(dishId);
    return matcher.isVisible(recipe, profile, ontologyRef, ignoreCalorieFilter: override);
  }

  /// The profile-default variant of a dish (null when nothing fits).
  Recipe? bestVariantFor(Dish dish) =>
      matcher.pickBest(corpus.loadedVariantsOf(dish), profile, ontologyRef);

  /// All variants of a dish for the switcher rows (loaded partitions only).
  List<Recipe> allVariantsOf(Dish dish) => corpus.loadedVariantsOf(dish);

  bool isSaved(String recipeId) => saved.any((e) => e.recipeId == recipeId);

  /// Feeds the home page: dish + its best visible variant, ranked by the
  /// time-aware + staleness-aware score.
  List<MapEntry<Dish, Recipe>> feedDishes({String? cuisine}) {
    final lastCooked = collections.lastCookedByRecipe();
    final entries = <MapEntry<Dish, Recipe>>[];
    for (final dish in corpus.allDishes) {
      if (cuisine != null && !dish.cuisineTags.contains(cuisine)) continue;
      final best = bestVariantFor(dish);
      if (best == null) continue;
      entries.add(MapEntry(dish, best));
    }
    final now = DateTime.now();
    entries.sort((a, b) {
      final scoreA = ranking.feedScore(
          dish: a.key, recipe: a.value, now: now, lastCookedAt: lastCooked[a.value.id]);
      final scoreB = ranking.feedScore(
          dish: b.key, recipe: b.value, now: now, lastCookedAt: lastCooked[b.value.id]);
      return scoreB != scoreA ? scoreB.compareTo(scoreA) : a.key.id.compareTo(b.key.id);
    });
    return entries;
  }
  // ---------------- cookbook ----------------

  Future<void> toggleSaved(String recipeId) async {
    if (isSaved(recipeId)) {
      await collections.unsaveRecipe(recipeId);
    } else {
      await collections.saveRecipe(recipeId);
    }
    saved = collections.loadSaved();
    notifyListeners();
  }

  /// Saved entries, newest first.
  List<SavedEntry> get savedNewestFirst {
    final list = [...saved]..sort((a, b) => b.at.compareTo(a.at));
    return list;
  }

  Recipe? recipeFor(SavedEntry entry) => corpus.recipe(entry.recipeId);

  // ---------------- history ----------------

  Future<void> recordCooked(String recipeId, {int servings = 2}) async {
    await collections.addHistory(recipeId, servings: servings);
    history = collections.loadHistory();
    notifyListeners();
  }

  /// History, newest first.
  List<HistoryEntry> get historyNewestFirst {
    final list = [...history]..sort((a, b) => b.at.compareTo(a.at));
    return list;
  }

  Recipe? recipeForHistory(HistoryEntry entry) => corpus.recipe(entry.recipeId);

  // ---------------- meal plan ----------------

  Future<void> assignSlot(String weekKey, String slot, String recipeId) async {
    mealPlan.assign(weekKey, slot, recipeId);
    await collections.saveMealPlan(mealPlan);
    notifyListeners();
  }

  Future<void> clearSlot(String weekKey, String slot) async {
    mealPlan.clear(weekKey, slot);
    await collections.saveMealPlan(mealPlan);
    notifyListeners();
  }

  Future<void> moveSlot(String fromWeek, String fromSlot, String toWeek, String toSlot) async {
    mealPlan.move(fromWeek, fromSlot, toWeek, toSlot);
    await collections.saveMealPlan(mealPlan);
    notifyListeners();
  }

  /// One-tap export of a planned week to the shopping list (SPEC).
  Future<int> exportWeekToShoppingList(String weekKey) async {
    final recipeIds = mealPlan.recipesOfWeek(weekKey);
    final recipes = recipeIds.map(corpus.recipe).whereType<Recipe>().toList();
    if (recipes.isEmpty) return 0;
    return addRecipesToShopping(recipes);
  }
  // ---------------- shopping ----------------

  /// Adds the ingredients of [recipes] (aggregated, merged into the current
  /// list) and logs a shopping-addition event for the insights. Returns the
  /// number of distinct ingredients added.
  Future<int> addRecipesToShopping(List<Recipe> recipes) async {
    if (recipes.isEmpty) return 0;
    final incoming = ShoppingAggregator.aggregate(recipes);
    shoppingItems = ShoppingAggregator.mergeInto(shoppingItems, incoming);
    await collections.saveShoppingItems(shoppingItems);
    await collections.addShoppingAddition(ShoppingAddition(
      at: DateTime.now(),
      ingredientIds: incoming.map((e) => e.ingredientId).toList(),
    ));
    shoppingAdditions = collections.loadShoppingAdditions();
    notifyListeners();
    return incoming.length;
  }

  Future<void> toggleShoppingItem(String ingredientId) async {
    for (final item in shoppingItems) {
      if (item.ingredientId == ingredientId) item.checked = !item.checked;
    }
    await collections.saveShoppingItems(shoppingItems);
    notifyListeners();
  }

  Future<void> removeShoppingItem(String ingredientId) async {
    shoppingItems =
        shoppingItems.where((item) => item.ingredientId != ingredientId).toList();
    await collections.saveShoppingItems(shoppingItems);
    notifyListeners();
  }

  Future<void> clearCheckedShoppingItems() async {
    shoppingItems = shoppingItems.where((item) => !item.checked).toList();
    await collections.saveShoppingItems(shoppingItems);
    notifyListeners();
  }

  ShoppingInsights get shoppingInsights => ShoppingInsights.fromAdditions(shoppingAdditions);

  /// Shopping items grouped by aisle (ordered), ready for the list view.
  Map<String, List<ShoppingItem>> get itemsByAisle {
    final map = <String, List<ShoppingItem>>{};
    for (final item in shoppingItems) {
      final aisle = corpus.ingredients.aisleOf(item.ingredientId);
      map.putIfAbsent(aisle, () => []).add(item);
    }
    final keys = map.keys.toList()
      ..sort((a, b) {
        final order =
            corpus.ontology.aisleOrder(a).compareTo(corpus.ontology.aisleOrder(b));
        return order != 0 ? order : a.compareTo(b);
      });
    return {for (final k in keys) k: map[k]!};
  }

  // ---------------- content requests ----------------

  Future<void> logContentRequest(String query) async {
    if (query.trim().isEmpty) return;
    await collections.addContentRequest(query.trim());
    contentRequests = collections.loadContentRequests();
    notifyListeners();
  }

  // ---------------- calorie override ----------------

  bool calorieOverride(String dishId) => profileStore.calorieOverrides().contains(dishId);

  Future<void> setCalorieOverride(String dishId, bool enabled) async {
    await profileStore.setCalorieOverride(dishId, enabled);
    notifyListeners();
  }

  // ---------------- helpers ----------------

  String localized(LocalizedText text) => lt(text, lang);

  /// Cook-mode progress persistence (pause/resume across sessions).
  CookProgressStore get cookProgress => profileStore.cook;
}
