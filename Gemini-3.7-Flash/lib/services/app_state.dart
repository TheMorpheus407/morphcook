import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/localized_string.dart';
import '../models/profile.dart';
import '../models/dish.dart';
import '../models/recipe.dart';
import '../models/cooking_history_item.dart';
import '../models/shopping_item.dart';
import '../models/meal_plan.dart';
import '../models/backup_data.dart';
import 'corpus_service.dart';
import 'matching_engine.dart';
import 'backup_service.dart';

class ActiveCookSession {
  final String recipeId;
  int currentStepIndex;
  int elapsedSeconds;
  bool isPaused;
  int servings;

  ActiveCookSession({
    required this.recipeId,
    this.currentStepIndex = 0,
    this.elapsedSeconds = 0,
    this.isPaused = false,
    this.servings = 2,
  });

  Map<String, dynamic> toJson() => {
    'recipe_id': recipeId,
    'current_step_index': currentStepIndex,
    'elapsed_seconds': elapsedSeconds,
    'is_paused': isPaused,
    'servings': servings,
  };

  factory ActiveCookSession.fromJson(Map<String, dynamic> json) => ActiveCookSession(
    recipeId: json['recipe_id'] as String? ?? '',
    currentStepIndex: json['current_step_index'] as int? ?? 0,
    elapsedSeconds: json['elapsed_seconds'] as int? ?? 0,
    isPaused: json['is_paused'] as bool? ?? false,
    servings: json['servings'] as int? ?? 2,
  );
}

class AppState extends ChangeNotifier {
  final CorpusService corpus = CorpusService();
  UserProfile profile = UserProfile.defaultProfile();

  Set<String> savedRecipeIds = {};
  Map<String, WeeklyMealPlan> mealPlans = {};
  List<CookingHistoryItem> cookingHistory = [];
  List<ShoppingItem> shoppingList = [];
  List<String> contentRequests = [];
  ActiveCookSession? activeCookSession;

  bool isInitialized = false;

  // Selected week for meal planner (default current ISO week)
  String currentSelectedWeek = WeeklyMealPlan.getIsoWeekId(DateTime.now());

  Future<void> init() async {
    if (isInitialized) return;

    await corpus.init();
    await _loadFromPrefs();

    isInitialized = true;
    notifyListeners();
  }

  // Language helper
  String get lang => profile.lang;

  void setLanguage(String newLang) {
    if (profile.lang != newLang) {
      profile.lang = newLang;
      saveProfile();
      notifyListeners();
    }
  }

  // --- Persistence with SharedPreferences ---
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // Profile
    final profStr = prefs.getString('user_profile');
    if (profStr != null) {
      try {
        profile = UserProfile.fromJson(jsonDecode(profStr) as Map<String, dynamic>);
      } catch (_) {}
    }

    // Saved recipes
    final savedList = prefs.getStringList('saved_recipes');
    if (savedList != null) {
      savedRecipeIds = savedList.toSet();
    }

    // Meal plans
    final mpStr = prefs.getString('meal_plans');
    if (mpStr != null) {
      try {
        final map = jsonDecode(mpStr) as Map<String, dynamic>;
        map.forEach((wId, slotsJson) {
          if (slotsJson is Map) {
            mealPlans[wId] = WeeklyMealPlan.fromJson(wId, slotsJson as Map<String, dynamic>);
          }
        });
      } catch (_) {}
    }

    // Cooking history
    final histStr = prefs.getString('cooking_history');
    if (histStr != null) {
      try {
        final list = jsonDecode(histStr) as List<dynamic>;
        cookingHistory = list.map((e) => CookingHistoryItem.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    // Shopping list
    final shopStr = prefs.getString('shopping_list');
    if (shopStr != null) {
      try {
        final list = jsonDecode(shopStr) as List<dynamic>;
        shoppingList = list.map((e) => ShoppingItem.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    // Content requests
    final reqs = prefs.getStringList('content_requests');
    if (reqs != null) {
      contentRequests = reqs;
    }

    // Active cook session
    final cookStr = prefs.getString('active_cook_session');
    if (cookStr != null) {
      try {
        activeCookSession = ActiveCookSession.fromJson(jsonDecode(cookStr) as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  Future<void> saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile', jsonEncode(profile.toJson()));
    notifyListeners();
  }

  Future<void> _saveSavedRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_recipes', savedRecipeIds.toList());
  }

  Future<void> _saveMealPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, dynamic>{};
    mealPlans.forEach((w, plan) {
      map[w] = plan.toJson();
    });
    await prefs.setString('meal_plans', jsonEncode(map));
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cooking_history', jsonEncode(cookingHistory.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveShoppingList() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shopping_list', jsonEncode(shoppingList.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveContentRequests() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('content_requests', contentRequests);
  }

  Future<void> _saveActiveCookSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (activeCookSession != null) {
      await prefs.setString('active_cook_session', jsonEncode(activeCookSession!.toJson()));
    } else {
      await prefs.remove('active_cook_session');
    }
  }

  // --- Saved Recipes (Cookbook) ---
  bool isRecipeSaved(String recipeId) => savedRecipeIds.contains(recipeId);

  void toggleSaveRecipe(String recipeId) {
    if (savedRecipeIds.contains(recipeId)) {
      savedRecipeIds.remove(recipeId);
    } else {
      savedRecipeIds.add(recipeId);
    }
    _saveSavedRecipes();
    notifyListeners();
  }

  // --- Shopping List Operations ---
  void addRecipeIngredientsToShoppingList(Recipe recipe, int servings) {
    final scaledIngredients = recipe.getScaledIngredients(servings);
    for (final ing in scaledIngredients) {
      final item = ShoppingItem(
        id: '${recipe.id}_${ing.id}_${DateTime.now().millisecondsSinceEpoch}',
        ingredientId: ing.id,
        name: ing.name,
        amount: ing.amount,
        unit: ing.unit,
        aisle: ing.aisle,
        sourceRecipeIds: {recipe.id},
      );
      ShoppingItem.aggregateInto(shoppingList, item);
    }
    _saveShoppingList();
    notifyListeners();
  }

  void addCustomShoppingItem(String nameEn, String nameDe, double amount, String unit, String aisle) {
    final item = ShoppingItem(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      ingredientId: nameEn.toLowerCase().replaceAll(' ', '-'),
      name: LocalizedString({'en': nameEn, 'de': nameDe}),
      amount: amount,
      unit: unit,
      aisle: aisle,
    );
    ShoppingItem.aggregateInto(shoppingList, item);
    _saveShoppingList();
    notifyListeners();
  }

  void toggleShoppingItemChecked(String id) {
    final index = shoppingList.indexWhere((i) => i.id == id);
    if (index >= 0) {
      shoppingList[index].isChecked = !shoppingList[index].isChecked;
      _saveShoppingList();
      notifyListeners();
    }
  }

  void removeShoppingItem(String id) {
    shoppingList.removeWhere((i) => i.id == id);
    _saveShoppingList();
    notifyListeners();
  }

  void clearCheckedShoppingItems() {
    shoppingList.removeWhere((i) => i.isChecked);
    _saveShoppingList();
    notifyListeners();
  }

  void clearAllShoppingItems() {
    shoppingList.clear();
    _saveShoppingList();
    notifyListeners();
  }

  // --- Meal Planner Operations ---
  WeeklyMealPlan getMealPlan(String weekId) {
    if (!mealPlans.containsKey(weekId)) {
      mealPlans[weekId] = WeeklyMealPlan(weekId: weekId);
    }
    return mealPlans[weekId]!;
  }

  void assignRecipeToMealSlot(String weekId, String day, String mealType, String? recipeId) {
    final plan = getMealPlan(weekId);
    plan.setRecipeId(day, mealType, recipeId);
    _saveMealPlans();
    notifyListeners();
  }

  void moveMealSlot(String weekId, String fromDay, String fromMeal, String toDay, String toMeal) {
    final plan = getMealPlan(weekId);
    plan.moveSlot(fromDay, fromMeal, toDay, toMeal);
    _saveMealPlans();
    notifyListeners();
  }

  void exportWeekToShoppingList(String weekId) {
    final plan = getMealPlan(weekId);
    for (final recipeId in plan.slots.values) {
      final recipe = corpus.getRecipe(recipeId);
      if (recipe != null) {
        addRecipeIngredientsToShoppingList(recipe, recipe.servings);
      }
    }
  }

  // --- Cook Session & History ---
  void startCookSession(String recipeId, int servings) {
    activeCookSession = ActiveCookSession(
      recipeId: recipeId,
      servings: servings,
      currentStepIndex: 0,
      elapsedSeconds: 0,
    );
    _saveActiveCookSession();
    notifyListeners();
  }

  void updateCookSession({int? stepIndex, int? elapsedSeconds, bool? isPaused}) {
    if (activeCookSession != null) {
      if (stepIndex != null) activeCookSession!.currentStepIndex = stepIndex;
      if (elapsedSeconds != null) activeCookSession!.elapsedSeconds = elapsedSeconds;
      if (isPaused != null) activeCookSession!.isPaused = isPaused;
      _saveActiveCookSession();
      notifyListeners();
    }
  }

  void completeCookSession(String recipeId, int timeSpentMinutes, int servings) {
    final recipe = corpus.getRecipe(recipeId);
    if (recipe != null) {
      cookingHistory.insert(
        0,
        CookingHistoryItem(
          recipeId: recipeId,
          dishId: recipe.dishId,
          cookedAt: DateTime.now(),
          timeSpentMinutes: timeSpentMinutes,
          servingsCooked: servings,
        ),
      );
      _saveHistory();
    }
    activeCookSession = null;
    _saveActiveCookSession();
    notifyListeners();
  }

  void cancelCookSession() {
    activeCookSession = null;
    _saveActiveCookSession();
    notifyListeners();
  }

  // --- Content Requests (0-result search logging) ---
  void logContentRequest(String query) {
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty && !contentRequests.contains(q)) {
      contentRequests.add(q);
      _saveContentRequests();
    }
  }

  // --- Backup & Restore ---
  BackupData generateBackupData() {
    final mp = <String, Map<String, String>>{};
    mealPlans.forEach((k, v) => mp[k] = Map<String, String>.from(v.toJson()));

    return BackupData(
      schemaVersion: 1,
      exportedAt: DateTime.now().toIso8601String(),
      profile: profile,
      saved: savedRecipeIds.toList(),
      mealPlan: mp,
      history: cookingHistory,
      shoppingList: shoppingList,
      contentRequests: contentRequests,
    );
  }

  Future<void> restoreBackupData(BackupData data, {bool replace = false}) async {
    if (replace) {
      profile = data.profile;
      savedRecipeIds = data.saved.toSet();
      mealPlans.clear();
      data.mealPlan.forEach((wId, slots) {
        mealPlans[wId] = WeeklyMealPlan.fromJson(wId, slots);
      });
      cookingHistory = List.from(data.history);
      shoppingList = List.from(data.shoppingList);
      contentRequests = List.from(data.contentRequests);
    } else {
      final current = generateBackupData();
      final merged = BackupService.mergeData(current: current, incoming: data);
      profile = merged.profile;
      savedRecipeIds = merged.saved.toSet();
      mealPlans.clear();
      merged.mealPlan.forEach((wId, slots) {
        mealPlans[wId] = WeeklyMealPlan.fromJson(wId, slots);
      });
      cookingHistory = List.from(merged.history);
      shoppingList = List.from(merged.shoppingList);
      contentRequests = List.from(merged.contentRequests);
    }

    await saveProfile();
    await _saveSavedRecipes();
    await _saveMealPlans();
    await _saveHistory();
    await _saveShoppingList();
    await _saveContentRequests();
    notifyListeners();
  }

  // --- Matching Helpers ---
  Recipe? getBestVariantForDish(Dish dish, {bool overrideCalorie = false}) {
    if (corpus.ontology == null || corpus.ingredientDictionary == null) return null;
    return MatchingEngine.pickBestVariantForDish(
      dish: dish,
      allRecipes: corpus.recipes,
      profile: profile,
      ontology: corpus.ontology!,
      ingredientDict: corpus.ingredientDictionary!,
      overrideCalorieFilter: overrideCalorie,
    );
  }

  bool isRecipeVisible(Recipe recipe, {bool overrideCalorie = false}) {
    if (corpus.ontology == null || corpus.ingredientDictionary == null) return true;
    return MatchingEngine.isRecipeVisible(
      recipe: recipe,
      profile: profile,
      ontology: corpus.ontology!,
      ingredientDict: corpus.ingredientDictionary!,
      overrideCalorieFilter: overrideCalorie,
    );
  }

  List<Dish> getRankedDishes() {
    if (corpus.ontology == null || corpus.ingredientDictionary == null) return corpus.dishes;

    final scored = <Dish, double>{};
    for (final dish in corpus.dishes) {
      final best = getBestVariantForDish(dish);
      if (best != null && isRecipeVisible(best)) {
        scored[dish] = MatchingEngine.rankDish(
          dish: dish,
          bestVariant: best,
          profile: profile,
          history: cookingHistory,
        );
      }
    }

    final ranked = scored.keys.toList();
    ranked.sort((a, b) => (scored[b] ?? 0).compareTo(scored[a] ?? 0));
    return ranked;
  }
}
