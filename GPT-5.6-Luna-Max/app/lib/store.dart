import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'data.dart';
import 'models.dart';

class AppStore extends ChangeNotifier {
  AppStore()
    : profile = const Profile(
        name: 'Luna',
        lang: 'en',
        dietPreference: 'flexible',
        avoidFlags: <String>{},
        avoidIngredients: <String>{},
        requiredAttributes: <String>{},
        maxTimeMinutes: 45,
        calorieTarget: 600,
        preferredEffort: 'easy',
        showVariantTags: true,
        reduceMotion: false,
        visualAlertEnabled: true,
        quickNextTapEnabled: false,
      ) {
    savedIds.addAll(<String>{'doener-vegan', 'alfredo-vegan', 'golden-soup'});
    shoppingRecipeIds.addAll(<String>{'doener-vegan', 'golden-soup'});
    mealPlan.addAll(<String, String>{
      'mon.dinner': 'doener-vegan',
      'wed.lunch': 'golden-soup',
      'fri.dinner': 'alfredo-vegan',
    });
    history.addAll(<HistoryEntry>[
      HistoryEntry(
        recipeId: 'doener-vegan',
        cookedAt: DateTime.now().subtract(const Duration(days: 8)),
      ),
      HistoryEntry(
        recipeId: 'golden-soup',
        cookedAt: DateTime.now().subtract(const Duration(days: 36)),
      ),
    ]);
  }

  Profile profile;
  AppRoute route = AppRoute.home;
  AppTab currentTab = AppTab.home;
  String? activeRecipeId;
  String? activeDishId;
  String searchQuery = '';
  String searchTag = 'all';
  bool showOutsideTarget = false;
  bool onboardingFromSettings = false;
  int onboardingStep = 0;

  final Set<String> savedIds = <String>{};
  final Set<String> shoppingRecipeIds = <String>{};
  final Set<String> checkedShoppingIds = <String>{};
  final Map<String, String> mealPlan = <String, String>{};
  final Map<String, String> selectedVariants = <String, String>{};
  final Map<String, int> cookProgress = <String, int>{};
  final List<HistoryEntry> history = <HistoryEntry>[];
  final List<String> contentRequests = <String>[];
  final Map<String, int> ingredientAddCounts = <String, int>{
    'garlic': 8,
    'lemon': 6,
    'cucumber': 5,
    'tomato': 4,
    'red-lentils': 3,
  };

  String get lang => profile.lang;

  Recipe? get activeRecipe {
    if (activeRecipeId == null) return null;
    return recipes.where((recipe) => recipe.id == activeRecipeId).firstOrNull;
  }

  Dish? get activeDish {
    if (activeDishId == null) return null;
    return dishes.where((dish) => dish.id == activeDishId).firstOrNull;
  }

  void goToTab(AppTab tab) {
    currentTab = tab;
    route = switch (tab) {
      AppTab.home => AppRoute.home,
      AppTab.cookbook => AppRoute.cookbook,
      AppTab.plan => AppRoute.plan,
      AppTab.search => AppRoute.search,
      AppTab.settings => AppRoute.settings,
    };
    activeRecipeId = null;
    activeDishId = null;
    notifyListeners();
  }

  void goToRoute(AppRoute next) {
    route = next;
    notifyListeners();
  }

  void openRecipe(String recipeId) {
    activeRecipeId = recipeId;
    activeDishId = recipeFor(recipeId).dishId;
    route = AppRoute.recipe;
    notifyListeners();
  }

  void openDish(String dishId) {
    final dish = dishFor(dishId);
    activeDishId = dishId;
    activeRecipeId = recipeForDish(dish).id;
    route = AppRoute.recipe;
    notifyListeners();
  }

  void back() {
    route = switch (route) {
      AppRoute.recipe => _mainRouteForTab(currentTab),
      AppRoute.shopping ||
      AppRoute.insights ||
      AppRoute.help ||
      AppRoute.profileEditor ||
      AppRoute.backup => AppRoute.settings,
      AppRoute.cook => AppRoute.recipe,
      AppRoute.onboarding =>
        onboardingFromSettings ? AppRoute.settings : AppRoute.home,
      _ => _mainRouteForTab(currentTab),
    };
    if (route != AppRoute.recipe) {
      activeRecipeId = null;
      activeDishId = null;
    }
    notifyListeners();
  }

  AppRoute _mainRouteForTab(AppTab tab) => switch (tab) {
    AppTab.home => AppRoute.home,
    AppTab.cookbook => AppRoute.cookbook,
    AppTab.plan => AppRoute.plan,
    AppTab.search => AppRoute.search,
    AppTab.settings => AppRoute.settings,
  };

  List<Recipe> variantsFor(Dish dish) {
    return dish.recipeIds.map(recipeFor).toList();
  }

  Recipe recipeForDish(Dish dish) {
    final selected = selectedVariants[dish.id];
    if (selected != null) return recipeFor(selected);
    final preferredDiet = profile.dietPreference;
    final candidates = variantsFor(dish);
    final preferred = candidates.where((recipe) {
      return preferredDiet != 'flexible' && recipe.diet == preferredDiet;
    }).toList();
    final pool = preferred.isNotEmpty ? preferred : candidates;
    final matching = pool
        .where((recipe) => matchesProfile(recipe, profile))
        .toList();
    final sorted = matching.isEmpty ? pool : matching;
    sorted.sort(
      (a, b) => recipeScore(b, profile).compareTo(recipeScore(a, profile)),
    );
    return sorted.first;
  }

  void selectVariant(Dish dish, String dimension, String value) {
    final candidates = variantsFor(dish).where((recipe) {
      return switch (dimension) {
        'diet' => recipe.diet == value,
        'effort' => recipe.effort == value,
        'calorie' => recipe.calorieBucket() == value,
        _ => false,
      };
    }).toList();
    if (candidates.isEmpty) return;
    final visible = candidates
        .where(
          (recipe) => matchesProfile(
            recipe,
            profile,
            ignoreCalories: dimension == 'calorie',
          ),
        )
        .toList();
    final next = visible.isNotEmpty ? visible.first : candidates.first;
    selectedVariants[dish.id] = next.id;
    activeRecipeId = next.id;
    activeDishId = dish.id;
    notifyListeners();
  }

  bool variantAvailable(Recipe recipe, {bool ignoreCalories = false}) {
    return matchesProfile(recipe, profile, ignoreCalories: ignoreCalories);
  }

  List<Recipe> get visibleRecipes {
    final result = recipes
        .where(
          (recipe) => matchesProfile(
            recipe,
            profile,
            ignoreCalories: showOutsideTarget,
          ),
        )
        .toList();
    result.sort((a, b) => _rank(b).compareTo(_rank(a)));
    return result;
  }

  double _rank(Recipe recipe) {
    var score = recipeScore(recipe, profile);
    final lastCooked = history
        .where((entry) => entry.recipeId == recipe.id)
        .fold<DateTime?>(null, (oldest, entry) {
          if (oldest == null || entry.cookedAt.isBefore(oldest)) {
            return entry.cookedAt;
          }
          return oldest;
        });
    if (lastCooked != null &&
        DateTime.now().difference(lastCooked).inDays >= 30) {
      score += 50;
    }
    return score;
  }

  List<Recipe> get searchResults {
    final needle = searchQuery.trim().toLowerCase();
    final result = visibleRecipes
        .where((recipe) {
          final tagMatch =
              searchTag == 'all' || recipe.tags.contains(searchTag);
          if (!tagMatch) return false;
          if (needle.isEmpty) return true;
          final haystack = <String>[
            recipe.name('en'),
            recipe.name('de'),
            recipe.subline('en'),
            recipe.tags.join(' '),
            ...recipe.ingredients.expand((item) => item.name.values),
          ].join(' ').toLowerCase();
          return haystack.contains(needle);
        })
        .take(50)
        .toList();
    return result;
  }

  List<Recipe> get savedRecipes {
    return savedIds
        .map((id) => recipes.where((recipe) => recipe.id == id).firstOrNull)
        .whereType<Recipe>()
        .toList();
  }

  List<HistoryEntry> get recentHistory {
    final copy = List<HistoryEntry>.from(history)
      ..sort((a, b) => b.cookedAt.compareTo(a.cookedAt));
    return copy.take(50).toList();
  }

  void toggleSaved(String recipeId) {
    if (!savedIds.add(recipeId)) savedIds.remove(recipeId);
    notifyListeners();
  }

  bool isSaved(String recipeId) => savedIds.contains(recipeId);

  void addToShopping(String recipeId) {
    final added = shoppingRecipeIds.add(recipeId);
    final recipe = recipeFor(recipeId);
    for (final ingredient in recipe.ingredients) {
      ingredientAddCounts.update(
        ingredient.id,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    if (added) notifyListeners();
  }

  void removeFromShopping(String recipeId) {
    if (shoppingRecipeIds.remove(recipeId)) notifyListeners();
  }

  void addMealPlanToShopping() {
    for (final recipeId in mealPlan.values) {
      shoppingRecipeIds.add(recipeId);
      final recipe = recipeFor(recipeId);
      for (final ingredient in recipe.ingredients) {
        ingredientAddCounts.update(
          ingredient.id,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }
    notifyListeners();
  }

  List<ShoppingItem> get shoppingItems {
    final accumulators = <String, _ShoppingAccumulator>{};
    for (final recipeId in shoppingRecipeIds) {
      final recipe = recipeFor(recipeId);
      for (final ingredient in recipe.ingredients) {
        final existing = accumulators[ingredient.id];
        if (existing == null) {
          accumulators[ingredient.id] = _ShoppingAccumulator(
            id: ingredient.id,
            name: ingredient.label(lang),
            amount: ingredient.amount,
            unit: ingredient.unit,
            aisle: ingredient.aisle,
            recipeCount: 1,
          );
        } else {
          existing.add(ingredient.amount, ingredient.unit);
          existing.recipeCount += 1;
        }
      }
    }
    final items = accumulators.values.map((item) {
      return ShoppingItem(
        id: item.id,
        name: item.name,
        amount: item.amount,
        unit: item.unit,
        aisle: item.aisle,
        recipeCount: item.recipeCount,
        checked: checkedShoppingIds.contains(item.id),
      );
    }).toList();
    items.sort(
      (a, b) => '${a.aisle}${a.name}'.compareTo('${b.aisle}${b.name}'),
    );
    return items;
  }

  Map<String, List<ShoppingItem>> get groupedShoppingItems {
    final grouped = <String, List<ShoppingItem>>{};
    for (final item in shoppingItems) {
      grouped.putIfAbsent(item.aisle, () => <ShoppingItem>[]).add(item);
    }
    return grouped;
  }

  void toggleShoppingItem(String id) {
    if (!checkedShoppingIds.add(id)) checkedShoppingIds.remove(id);
    notifyListeners();
  }

  void assignMeal(String key, String? recipeId) {
    if (recipeId == null) {
      mealPlan.remove(key);
    } else {
      mealPlan[key] = recipeId;
    }
    notifyListeners();
  }

  void setSearch(String value) {
    searchQuery = value;
    if (value.trim().isEmpty) return notifyListeners();
    notifyListeners();
  }

  void setSearchTag(String value) {
    searchTag = value;
    notifyListeners();
  }

  void updateProfile(Profile next) {
    profile = next;
    notifyListeners();
  }

  void startOnboarding({bool fromSettings = false}) {
    onboardingFromSettings = fromSettings;
    onboardingStep = 0;
    route = AppRoute.onboarding;
    notifyListeners();
  }

  void finishOnboarding(Profile next) {
    profile = next;
    route = onboardingFromSettings ? AppRoute.settings : AppRoute.home;
    onboardingFromSettings = false;
    notifyListeners();
  }

  void startCooking(String recipeId) {
    activeRecipeId = recipeId;
    activeDishId = recipeFor(recipeId).dishId;
    route = AppRoute.cook;
    notifyListeners();
  }

  void setCookProgress(String recipeId, int step) {
    cookProgress[recipeId] = step;
    notifyListeners();
  }

  void finishCooking(String recipeId) {
    history.removeWhere(
      (entry) =>
          entry.recipeId == recipeId &&
          DateTime.now().difference(entry.cookedAt).inMinutes < 2,
    );
    history.add(HistoryEntry(recipeId: recipeId, cookedAt: DateTime.now()));
    cookProgress.remove(recipeId);
    route = AppRoute.recipe;
    notifyListeners();
  }

  void toggleCalorieOverride() {
    showOutsideTarget = !showOutsideTarget;
    notifyListeners();
  }

  void logContentRequest() {
    final query = searchQuery.trim();
    if (query.isEmpty || contentRequests.contains(query)) return;
    contentRequests.add(query);
    notifyListeners();
  }

  String backupJson() {
    final payload = <String, Object>{
      'schema_version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'profile': profile.toJson(),
      'saved': savedIds.toList(),
      'meal_plan': mealPlan,
      'history': history.map((entry) => entry.toJson()).toList(),
      'content_requests': contentRequests,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  void restoreBackup(Map<String, dynamic> payload, {bool replace = false}) {
    final rawProfile = payload['profile'];
    if (rawProfile is Map<String, dynamic>) {
      profile = profile.copyWith(
        name: rawProfile['name'] as String?,
        lang: rawProfile['lang'] as String?,
        dietPreference: rawProfile['diet_preference'] as String?,
        avoidFlags: _stringSet(rawProfile['avoid_flags']) ?? profile.avoidFlags,
        avoidIngredients:
            _stringSet(rawProfile['avoid_ingredients']) ??
            profile.avoidIngredients,
        requiredAttributes:
            _stringSet(rawProfile['required_attributes']) ??
            profile.requiredAttributes,
        maxTimeMinutes: rawProfile['max_time_minutes'] as int?,
        calorieTarget: rawProfile['calorie_target'] as int?,
        preferredEffort: rawProfile['preferred_effort'] as String?,
        showVariantTags: rawProfile['show_variant_tags'] as bool?,
        reduceMotion: rawProfile['reduce_motion'] as bool?,
        visualAlertEnabled: rawProfile['visual_alert_enabled'] as bool?,
        quickNextTapEnabled: rawProfile['quick_next_tap_enabled'] as bool?,
      );
    }
    if (replace) {
      savedIds.clear();
      mealPlan.clear();
      history.clear();
      contentRequests.clear();
    }
    final saved = _stringSet(payload['saved']);
    if (saved != null) savedIds.addAll(saved);
    final rawMealPlan = payload['meal_plan'];
    if (rawMealPlan is Map) {
      rawMealPlan.forEach((key, value) {
        if (key is String &&
            value is String &&
            recipes.any((recipe) => recipe.id == value)) {
          mealPlan[key] = value;
        }
      });
    }
    final rawHistory = payload['history'];
    if (rawHistory is List) {
      for (final entry in rawHistory) {
        if (entry is Map &&
            entry['recipe_id'] is String &&
            entry['cooked_at'] is String) {
          final cookedAt = DateTime.tryParse(entry['cooked_at'] as String);
          if (cookedAt != null &&
              recipes.any((recipe) => recipe.id == entry['recipe_id'])) {
            history.add(
              HistoryEntry(
                recipeId: entry['recipe_id'] as String,
                cookedAt: cookedAt,
              ),
            );
          }
        }
      }
    }
    final requests = _stringSet(payload['content_requests']);
    if (requests != null) contentRequests.addAll(requests);
    notifyListeners();
  }

  Set<String>? _stringSet(dynamic value) {
    if (value is! List) return null;
    return value.whereType<String>().toSet();
  }
}

class _ShoppingAccumulator {
  _ShoppingAccumulator({
    required this.id,
    required this.name,
    required this.amount,
    required this.unit,
    required this.aisle,
    required this.recipeCount,
  });

  final String id;
  final String name;
  double amount;
  String unit;
  final String aisle;
  int recipeCount;

  void add(double nextAmount, String nextUnit) {
    if (unit == nextUnit) {
      amount += nextAmount;
      return;
    }
    if (unit == 'ml' && nextUnit == 'tbsp') {
      amount += nextAmount * 15;
      return;
    }
    if (unit == 'tbsp' && nextUnit == 'ml') {
      amount = amount * 15 + nextAmount;
      unit = 'ml';
      return;
    }
    if (unit == 'ml' && nextUnit == 'tsp') {
      amount += nextAmount * 5;
      return;
    }
    // Incompatible units stay readable instead of pretending precision.
    amount += nextAmount;
  }
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
