import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/content.dart';
import '../models/profile.dart';
import '../models/recipe.dart';
import '../models/user_data.dart';
import '../services/backup_service.dart';
import '../services/content_repository.dart';
import '../services/local_store.dart';
import '../services/matching_service.dart';
import '../services/ontology_service.dart';
import '../services/shopping_aggregator.dart';

class AppController extends ChangeNotifier {
  AppController({ContentRepository? content, LocalStore? store})
    : content = content ?? ContentRepository(),
      store = store ?? LocalStore();

  final ContentRepository content;
  final LocalStore store;
  final BackupService backupService = BackupService();

  UserProfile profile = const UserProfile();
  Map<String, DateTime> savedAt = {};
  Map<String, String> mealPlan = {};
  List<CookingHistoryEntry> history = [];
  List<ShoppingItem> shopping = [];
  List<ShoppingAddition> shoppingLog = [];
  Set<String> contentRequests = {};
  bool initialized = false;
  bool loadingCorpus = false;
  Future<void>? _corpusLoad;

  String get language => profile.language;
  OntologyService get ontology => content.ontology;
  Set<String> get savedIds => savedAt.keys.toSet();

  Future<void> initialize() async {
    await Future.wait([content.loadCore(), store.initialize()]);
    profile = store.loadProfile();
    savedAt = store.loadSaved();
    mealPlan = store.loadMealPlan();
    history = store.loadHistory();
    shopping = store.loadShopping();
    shoppingLog = store.loadShoppingLog();
    contentRequests = store.loadContentRequests();
    initialized = true;
    notifyListeners();
  }

  Future<void> ensureAllContent() async {
    if (content.allLoaded) return;
    final active = _corpusLoad;
    if (active != null) return active;
    loadingCorpus = true;
    notifyListeners();
    final load = content.loadAll();
    _corpusLoad = load;
    try {
      await load;
    } finally {
      _corpusLoad = null;
      loadingCorpus = false;
      notifyListeners();
    }
  }

  Future<void> ensureDish(String dishId) async {
    await content.ensureDish(dishId);
    notifyListeners();
  }

  Set<String> get expandedAvoidFlags =>
      ontology.expandFlags(profile.avoidFlags);
  Set<String> get expandedAvoidIngredients =>
      ontology.expandIngredients(profile.avoidIngredients);

  bool isVisible(Recipe recipe, {bool ignoreCalories = false}) =>
      RecipeMatcher.visible(
        recipe,
        profile,
        expandedAvoidFlags: expandedAvoidFlags,
        expandedAvoidIngredients: expandedAvoidIngredients,
        ignoreCalories: ignoreCalories,
      );

  Map<String, DateTime> get lastCookedByRecipe {
    final result = <String, DateTime>{};
    for (final item in history) {
      final existing = result[item.recipeId];
      if (existing == null || item.cookedAt.isAfter(existing)) {
        result[item.recipeId] = item.cookedAt;
      }
    }
    return result;
  }

  List<Recipe> get visibleRecipes => RecipeMatcher.ranked(
    content.recipes.where(isVisible),
    profile,
    lastCooked: lastCookedByRecipe,
  );

  List<Dish> get visibleDishes {
    final visibleDishIds = visibleRecipes.map((item) => item.dishId).toSet();
    return content.dishes
        .where((dish) => visibleDishIds.contains(dish.id))
        .toList(growable: false);
  }

  List<Recipe> variantsForDish(String dishId, {bool ignoreCalories = false}) =>
      RecipeMatcher.ranked(
        content
            .recipesForDish(dishId)
            .where(
              (recipe) => isVisible(recipe, ignoreCalories: ignoreCalories),
            ),
        profile,
        lastCooked: lastCookedByRecipe,
      );

  Recipe? preferredRecipeForDish(String dishId, {bool ignoreCalories = false}) {
    final variants = variantsForDish(dishId, ignoreCalories: ignoreCalories);
    return variants.isEmpty ? null : variants.first;
  }

  Future<List<Recipe>> search(
    String query, {
    Set<String> tags = const {},
  }) async {
    await ensureAllContent();
    final results = content
        .search(query, language, tags)
        .where(isVisible)
        .toList(growable: false);
    final ranked = RecipeMatcher.ranked(
      results,
      profile,
      lastCooked: lastCookedByRecipe,
    );
    if (ranked.isEmpty && query.trim().isNotEmpty) {
      final normalized = query.trim().toLowerCase();
      contentRequests.add(normalized);
      unawaited(store.addContentRequest(normalized));
    }
    return ranked;
  }

  Future<void> updateProfile(UserProfile value) async {
    profile = value;
    notifyListeners();
    await store.saveProfile(value);
  }

  Future<void> finishOnboarding(UserProfile value) =>
      updateProfile(value.copyWith(onboardingComplete: true));

  Future<void> toggleSaved(String recipeId) async {
    final isSaved = savedAt.containsKey(recipeId);
    if (isSaved) {
      savedAt.remove(recipeId);
    } else {
      savedAt[recipeId] = DateTime.now();
    }
    notifyListeners();
    await store.setSaved(recipeId, !isSaved);
  }

  List<Recipe> get savedRecipes {
    final items = savedAt.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return items
        .map((entry) => content.recipeById(entry.key))
        .whereType<Recipe>()
        .toList(growable: false);
  }

  String slotKey(DateTime date, String meal) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}.$meal';

  Future<void> assignMeal(DateTime date, String meal, String? recipeId) async {
    final key = slotKey(date, meal);
    if (recipeId == null) {
      mealPlan.remove(key);
    } else {
      mealPlan[key] = recipeId;
    }
    notifyListeners();
    await store.setMeal(key, recipeId);
  }

  Future<void> moveMeal(String fromKey, String toKey) async {
    if (fromKey == toKey) return;
    final moving = mealPlan[fromKey];
    if (moving == null) return;
    final displaced = mealPlan[toKey];
    mealPlan[toKey] = moving;
    if (displaced == null) {
      mealPlan.remove(fromKey);
    } else {
      mealPlan[fromKey] = displaced;
    }
    notifyListeners();
    await store.replaceMealPlan(mealPlan);
  }

  Future<int> exportWeekToShopping(DateTime weekStart) async {
    final recipeIds = <String>[];
    for (var day = 0; day < 7; day++) {
      final date = weekStart.add(Duration(days: day));
      for (final meal in const ['breakfast', 'lunch', 'dinner']) {
        final id = mealPlan[slotKey(date, meal)];
        if (id != null) recipeIds.add(id);
      }
    }
    final recipes = recipeIds
        .map(content.recipeById)
        .whereType<Recipe>()
        .toList(growable: false);
    await addRecipesToShopping(recipes);
    return recipes.length;
  }

  Future<void> addRecipesToShopping(Iterable<Recipe> recipes) async {
    final recipeList = recipes.toList(growable: false);
    if (recipeList.isEmpty) return;
    shopping = ShoppingAggregator.addRecipes(shopping, recipeList);
    final event = ShoppingAddition(
      ingredientIds: recipeList
          .expand((recipe) => recipe.ingredientIds)
          .toList(),
      addedAt: DateTime.now(),
    );
    shoppingLog.add(event);
    notifyListeners();
    await Future.wait([
      store.saveShopping(shopping),
      store.addShoppingLog(event),
    ]);
  }

  Future<void> toggleShoppingItem(String ingredientId, String unit) async {
    shopping = shopping
        .map(
          (item) => item.ingredientId == ingredientId && item.unit == unit
              ? item.copyWith(checked: !item.checked)
              : item,
        )
        .toList(growable: false);
    notifyListeners();
    await store.saveShopping(shopping);
  }

  Future<void> removeShoppingItem(String ingredientId, String unit) async {
    shopping = shopping
        .where((item) => item.ingredientId != ingredientId || item.unit != unit)
        .toList(growable: false);
    notifyListeners();
    await store.saveShopping(shopping);
  }

  Future<void> clearCheckedShopping() async {
    shopping = shopping.where((item) => !item.checked).toList(growable: false);
    notifyListeners();
    await store.saveShopping(shopping);
  }

  Future<void> completeCook(Recipe recipe, int servings) async {
    final item = CookingHistoryEntry(
      id: '${recipe.id}-${DateTime.now().microsecondsSinceEpoch}',
      recipeId: recipe.id,
      cookedAt: DateTime.now(),
      servings: servings,
    );
    history.insert(0, item);
    notifyListeners();
    await Future.wait([
      store.addHistory(item),
      store.clearCookProgress(recipe.id),
    ]);
  }

  Map<String, int> get topIngredientFrequency {
    final result = <String, int>{};
    for (final event in shoppingLog) {
      for (final id in event.ingredientIds) {
        result[id] = (result[id] ?? 0) + 1;
      }
    }
    return result;
  }

  int get varietyScore =>
      shoppingLog.expand((event) => event.ingredientIds).toSet().length;

  Map<int, int> get seasonalBreakdown {
    final result = <int, int>{};
    for (final event in shoppingLog) {
      result[event.addedAt.month] =
          (result[event.addedAt.month] ?? 0) + event.ingredientIds.length;
    }
    return result;
  }

  Future<BackupBundle> createBackup({String? password}) =>
      backupService.create(store.backupData(profile), password: password);

  Future<void> restoreBackup(
    List<int> bytes, {
    String? password,
    required bool merge,
  }) async {
    final data = await backupService.read(bytes, password: password);
    profile = await store.restore(data, merge: merge);
    savedAt = store.loadSaved();
    mealPlan = store.loadMealPlan();
    history = store.loadHistory();
    shopping = store.loadShopping();
    shoppingLog = store.loadShoppingLog();
    contentRequests = store.loadContentRequests();
    notifyListeners();
  }

  IngredientGuideEntry? guideFor(String ingredientId) =>
      content.guideFor(ingredientId);
}
