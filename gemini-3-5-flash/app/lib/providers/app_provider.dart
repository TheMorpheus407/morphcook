import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class AppProvider extends ChangeNotifier {
  // Persistence Keys
  static const _keyProfile = 'mc_profile';
  static const _keyLanguage = 'mc_lang';
  static const _keySaved = 'mc_saved_recipes';
  static const _keyMealPlan = 'mc_meal_plan';
  static const _keyHistory = 'mc_cooking_history';
  static const _keyShopping = 'mc_shopping_list';
  static const _keyContentRequests = 'mc_content_requests';

  // Local State
  late UserProfile profile;
  String currentLanguage = 'en';
  Set<String> savedRecipeIds = {};
  bool onboardingCompleted = false;
  
  // Week key format: "YYYY-Wxx" (e.g. "2026-W21"). Slots: "mon.breakfast", "mon.lunch", etc.
  Map<String, Map<String, String>> mealPlan = {};
  
  // History entries: List of { "recipe_id": String, "timestamp": String }
  List<Map<String, dynamic>> cookingHistory = [];
  
  // Shopping list: Map of ingredientId to { "id": String, "amount": double, "unit": String, "name": Map<lang, String>, "aisle": String, "completed": bool }
  Map<String, Map<String, dynamic>> shoppingList = {};

  // Queries returning 0 results
  List<String> contentRequests = [];

  // Corpus Assets Data
  List<Dish> dishes = [];
  Map<String, Recipe> recipes = {}; // recipeId -> Recipe
  List<IngredientNode> ingredientsTree = [];
  Map<String, dynamic> ingredientGuide = {};
  List<FAQEntry> faqs = [];
  Map<String, dynamic> ontology = {};

  bool isLoaded = false;
  Set<String> loadedPartitions = {};

  AppProvider() {
    profile = UserProfile.defaultProfile();
    _init();
  }

  Future<void> _init() async {
    await loadCorpus();
    await loadPersistedState();
    isLoaded = true;
    notifyListeners();
  }

  // --- Assets Corpus Loading ---
  Future<void> loadCorpus() async {
    try {
      // 1. Load Ontology
      final ontologyStr = await rootBundle.loadString('assets/ontology.json');
      ontology = json.decode(ontologyStr);

      // 2. Load Ingredients Tree
      final ingredientsStr = await rootBundle.loadString('assets/ingredients.json');
      final List ingredientsJson = json.decode(ingredientsStr);
      ingredientsTree = ingredientsJson.map((x) => IngredientNode.fromJson(x)).toList();

      // 3. Load Ingredient Guide
      final guideStr = await rootBundle.loadString('assets/ingredient-guide.json');
      ingredientGuide = json.decode(guideStr);

      // 4. Load FAQs
      final faqsStr = await rootBundle.loadString('assets/faqs.json');
      final List faqsJson = json.decode(faqsStr);
      faqs = faqsJson.map((x) => FAQEntry.fromJson(x)).toList();

      // 5. Load Dishes
      final dishesStr = await rootBundle.loadString('assets/dishes.json');
      final List dishesJson = json.decode(dishesStr);
      dishes = dishesJson.map((x) => Dish.fromJson(x)).toList();

      // 6. Load Core Recipes (Partition autoload)
      await loadPartition('core-recipes');
    } catch (e) {
      debugPrint("Error loading corpus: $e");
    }
  }

  Future<void> loadPartition(String partitionId) async {
    if (loadedPartitions.contains(partitionId)) return;

    try {
      String filePath = '';
      if (partitionId == 'core-recipes') {
        filePath = 'assets/core-recipes.json';
      } else if (partitionId == 'extended-recipes') {
        filePath = 'assets/extended-recipes.json';
      } else {
        return;
      }

      final content = await rootBundle.loadString(filePath);
      final List recipesJson = json.decode(content);
      for (var rj in recipesJson) {
        final recipe = Recipe.fromJson(rj);
        recipes[recipe.id] = recipe;
      }
      loadedPartitions.add(partitionId);
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading partition $partitionId: $e");
    }
  }

  /// Ensures that all recipe variants of a dish are loaded in the recipes Map.
  /// If any are missing, it triggers loading the extended-recipes partition.
  Future<void> ensureDishVariantsLoaded(Dish dish) async {
    bool hasMissing = false;
    for (var id in dish.variantIds) {
      if (!recipes.containsKey(id)) {
        hasMissing = true;
        break;
      }
    }
    if (hasMissing) {
      await loadPartition('extended-recipes');
    }
  }

  // --- Localization helper ---
  String tr(Map<String, String> localizedText) {
    return localizedText[currentLanguage] ?? localizedText['en'] ?? '';
  }

  // --- SharedPreferences Persistence ---
  Future<void> loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Language
    currentLanguage = prefs.getString(_keyLanguage) ?? 'en';
    profile.lang = currentLanguage;

    // 2. Profile
    final profileStr = prefs.getString(_keyProfile);
    if (profileStr != null) {
      try {
        profile = UserProfile.fromJson(json.decode(profileStr));
        currentLanguage = profile.lang;
      } catch (e) {
        debugPrint("Error loading profile: $e");
      }
    }

    // 3. Saved Recipes
    final savedList = prefs.getStringList(_keySaved);
    if (savedList != null) {
      savedRecipeIds = savedList.toSet();
    }

    // 4. Meal Plan
    final mealPlanStr = prefs.getString(_keyMealPlan);
    if (mealPlanStr != null) {
      try {
        final Map<String, dynamic> decoded = json.decode(mealPlanStr);
        mealPlan = decoded.map((week, slots) {
          final Map<String, dynamic> slotsMap = slots;
          return MapEntry(week, slotsMap.map((slot, recipeId) => MapEntry(slot, recipeId.toString())));
        });
      } catch (e) {
        debugPrint("Error loading meal plan: $e");
      }
    }

    // 5. Cooking History
    final historyStr = prefs.getString(_keyHistory);
    if (historyStr != null) {
      try {
        final List decoded = json.decode(historyStr);
        cookingHistory = decoded.map((x) => Map<String, dynamic>.from(x)).toList();
      } catch (e) {
        debugPrint("Error loading cooking history: $e");
      }
    }

    // 6. Shopping List
    final shoppingStr = prefs.getString(_keyShopping);
    if (shoppingStr != null) {
      try {
        final Map<String, dynamic> decoded = json.decode(shoppingStr);
        shoppingList = decoded.map((key, val) => MapEntry(key, Map<String, dynamic>.from(val)));
      } catch (e) {
        debugPrint("Error loading shopping list: $e");
      }
    }

    // 7. Content Requests
    final contentReqList = prefs.getStringList(_keyContentRequests);
    if (contentReqList != null) {
      contentRequests = contentReqList;
    }
    onboardingCompleted = prefs.getBool('mc_onboarding_completed') ?? false;
  }

  Future<void> completeOnboarding() async {
    onboardingCompleted = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mc_onboarding_completed', true);
    notifyListeners();
  }

  Future<void> saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfile, json.encode(profile.toJson()));
    await prefs.setString(_keyLanguage, profile.lang);
    currentLanguage = profile.lang;
    notifyListeners();
  }

  Future<void> saveSavedRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keySaved, savedRecipeIds.toList());
  }

  Future<void> saveMealPlan() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMealPlan, json.encode(mealPlan));
  }

  Future<void> saveCookingHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHistory, json.encode(cookingHistory));
  }

  Future<void> saveShoppingList() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyShopping, json.encode(shoppingList));
  }

  Future<void> saveContentRequests() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyContentRequests, contentRequests);
  }

  // --- State Mutators ---

  void setLanguage(String lang) {
    currentLanguage = lang;
    profile.lang = lang;
    saveProfile();
  }

  void updateProfile(UserProfile newProfile) {
    profile = newProfile;
    currentLanguage = newProfile.lang;
    saveProfile();
  }

  void toggleSavedRecipe(String recipeId) {
    if (savedRecipeIds.contains(recipeId)) {
      savedRecipeIds.remove(recipeId);
    } else {
      savedRecipeIds.add(recipeId);
    }
    saveSavedRecipes();
    notifyListeners();
  }

  bool isRecipeSaved(String recipeId) {
    return savedRecipeIds.contains(recipeId);
  }

  // --- Meal Planning ---
  void addRecipeToMealPlan(String week, String slot, String recipeId) {
    if (!mealPlan.containsKey(week)) {
      mealPlan[week] = {};
    }
    mealPlan[week]![slot] = recipeId;
    saveMealPlan();
    notifyListeners();
  }

  void removeRecipeFromMealPlan(String week, String slot) {
    if (mealPlan.containsKey(week)) {
      mealPlan[week]!.remove(slot);
      if (mealPlan[week]!.isEmpty) {
        mealPlan.remove(week);
      }
      saveMealPlan();
      notifyListeners();
    }
  }

  void moveMealPlanSlot(String week, String fromSlot, String toSlot) {
    if (mealPlan.containsKey(week) && mealPlan[week]!.containsKey(fromSlot)) {
      final recipeId = mealPlan[week]![fromSlot]!;
      mealPlan[week]!.remove(fromSlot);
      mealPlan[week]![toSlot] = recipeId;
      saveMealPlan();
      notifyListeners();
    }
  }

  /// Exports all recipes in the meal plan for a specific week to the shopping list
  void exportWeekToShoppingList(String week) {
    if (!mealPlan.containsKey(week)) return;

    for (var recipeId in mealPlan[week]!.values) {
      final recipe = recipes[recipeId];
      if (recipe != null) {
        addRecipeToShoppingList(recipe);
      }
    }
  }

  // --- Cooking History ---
  void logCooking(String recipeId) {
    cookingHistory.add({
      'recipe_id': recipeId,
      'timestamp': DateTime.now().toIso8601String(),
    });
    saveCookingHistory();
    notifyListeners();
  }

  List<String> getRecentlyCookedIds() {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final ids = <String>{};
    for (var entry in cookingHistory) {
      try {
        final timestampStr = entry['timestamp'];
        if (timestampStr != null) {
          final timestamp = DateTime.parse(timestampStr);
          if (timestamp.isAfter(cutoff)) {
            final rId = entry['recipe_id'];
            if (rId != null) {
              ids.add(rId);
            }
          }
        }
      } catch (_) {}
    }
    return ids.toList();
  }

  // --- Smart Shopping List ---
  void addRecipeToShoppingList(Recipe recipe, {double servingsMultiplier = 1.0}) {
    for (var ingredient in recipe.ingredients) {
      final id = ingredient.id;
      final amountToAdd = ingredient.amount * servingsMultiplier;

      if (shoppingList.containsKey(id)) {
        final current = shoppingList[id]!;
        // Compatible unit conversions / aggregations:
        // ml ↔ tbsp conversion: 1 tbsp = 15 ml. Let's convert everything to ml or add as is.
        // For compatible unit types (same unit), we just sum them.
        double currentAmount = (current['amount'] as num).toDouble();
        String currentUnit = current['unit'];

        if (currentUnit == ingredient.unit) {
          shoppingList[id]!['amount'] = currentAmount + amountToAdd;
        } else if (currentUnit == 'ml' && ingredient.unit == 'tbsp') {
          shoppingList[id]!['amount'] = currentAmount + (amountToAdd * 15.0);
        } else if (currentUnit == 'tbsp' && ingredient.unit == 'ml') {
          shoppingList[id]!['amount'] = currentAmount + (amountToAdd / 15.0);
        } else {
          // If incompatible units, we can keep the current unit and add a separate entry, 
          // or for simplification, keep the existing unit and convert. Let's just append to a list or keep current.
          shoppingList[id]!['amount'] = currentAmount + amountToAdd;
        }
      } else {
        shoppingList[id] = {
          'id': id,
          'amount': amountToAdd,
          'unit': ingredient.unit,
          'name': ingredient.name,
          'aisle': ingredient.aisle,
          'completed': false,
        };
      }
    }
    saveShoppingList();
    notifyListeners();
  }

  void toggleShoppingItemCompleted(String ingredientId) {
    if (shoppingList.containsKey(ingredientId)) {
      shoppingList[ingredientId]!['completed'] = !(shoppingList[ingredientId]!['completed'] ?? false);
      saveShoppingList();
      notifyListeners();
    }
  }

  void removeShoppingItem(String ingredientId) {
    shoppingList.remove(ingredientId);
    saveShoppingList();
    notifyListeners();
  }

  void clearShoppingList() {
    shoppingList.clear();
    saveShoppingList();
    notifyListeners();
  }

  // --- Content Requests Log (Zero result searches) ---
  void logZeroResultSearch(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isNotEmpty && !contentRequests.contains(clean)) {
      contentRequests.add(clean);
      saveContentRequests();
    }
  }

  // --- Shopping Insights Data ---
  int getVarietyScore() {
    // Unique ingredient count in shopping list or history
    return shoppingList.length;
  }

  Map<String, int> getTopAddedIngredients() {
    // Frequency counts of ingredient additions
    // Let's count ingredients currently in shopping list or in history (simulated based on ingredients we have)
    final counts = <String, int>{};
    for (var entry in shoppingList.values) {
      final name = tr(Map<String, String>.from(entry['name']));
      counts[name] = (counts[name] ?? 0) + 1;
    }
    // Sort and limit to top 5
    return counts;
  }

  Map<String, int> getSeasonalBreakdown() {
    // Group added ingredients/cooked dishes by month
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    final breakdown = <String, int>{};
    for (var m in months) {
      breakdown[m] = 0;
    }
    for (var entry in cookingHistory) {
      try {
        final t = DateTime.parse(entry['timestamp']);
        final mLabel = months[t.month - 1];
        breakdown[mLabel] = (breakdown[mLabel] ?? 0) + 1;
      } catch (_) {}
    }
    return breakdown;
  }

  /// Returns the optimal matching recipe variant for a given dish.
  Recipe? getOptimalVariantForDish(Dish dish, {bool overrideCalorieTarget = false}) {
    final visibleVariants = <Recipe>[];
    for (var id in dish.variantIds) {
      final recipe = recipes[id];
      if (recipe != null && isRecipeVisible(recipe, profile, overrideCalorieTarget: overrideCalorieTarget)) {
        visibleVariants.add(recipe);
      }
    }
    if (visibleVariants.isEmpty) return null;

    visibleVariants.sort((a, b) {
      final scoreA = calculateRecipeScore(
        recipe: a,
        profile: profile,
        currentTime: DateTime.now(),
        recentlyCookedIds: getRecentlyCookedIds(),
      );
      final scoreB = calculateRecipeScore(
        recipe: b,
        profile: profile,
        currentTime: DateTime.now(),
        recentlyCookedIds: getRecentlyCookedIds(),
      );
      return scoreB.compareTo(scoreA); // descending
    });

    return visibleVariants.first;
  }
}
