import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data.dart';
import 'models.dart';
import 'services.dart';

String dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String mealPlanKey(DateTime date, String meal) => '${dayKey(date)}.$meal';

class MorphCookState extends ChangeNotifier {
  MorphCookState._({
    required this.repository,
    required SharedPreferences preferences,
    required Box<String> box,
    required this.profile,
    required this.onboardingComplete,
    required this.savedRecipeIds,
    required this.mealPlan,
    required this.history,
    required this.shoppingEvents,
    required this.shoppingRecipeIds,
    required this.contentRequests,
    required this.cookProgress,
  }) : _preferences = preferences,
       _box = box;

  @visibleForTesting
  factory MorphCookState.forTesting({
    required RecipeRepository repository,
    required SharedPreferences preferences,
    required Box<String> box,
    Profile? profile,
    bool onboardingComplete = false,
  }) => MorphCookState._(
    repository: repository,
    preferences: preferences,
    box: box,
    profile: profile ?? Profile.fresh(),
    onboardingComplete: onboardingComplete,
    savedRecipeIds: <String>{},
    mealPlan: <String, String>{},
    history: <HistoryEntry>[],
    shoppingEvents: <ShoppingEvent>[],
    shoppingRecipeIds: <String>{},
    contentRequests: <String>[],
    cookProgress: <String, CookProgress>{},
  );

  static Future<MorphCookState> bootstrap() async {
    final repository = await RecipeRepository.load();
    final preferences = await SharedPreferences.getInstance();
    await Hive.initFlutter();
    final box = await Hive.openBox<String>('morphcook-local-state');
    Map<String, dynamic>? profileMap;
    final rawProfile = preferences.getString('profile');
    if (rawProfile != null) {
      try {
        profileMap = (jsonDecode(rawProfile) as Map).map(
          (key, value) => MapEntry('$key', value),
        );
      } catch (_) {
        profileMap = null;
      }
    }
    return MorphCookState._(
      repository: repository,
      preferences: preferences,
      box: box,
      profile: profileMap == null
          ? Profile.fresh()
          : Profile.fromJson(profileMap),
      onboardingComplete: preferences.getBool('onboardingComplete') ?? false,
      savedRecipeIds: _stringSet(box.get('saved')),
      mealPlan: _stringMap(box.get('mealPlan')),
      history: _historyList(box.get('history')),
      shoppingEvents: _shoppingEvents(box.get('shoppingEvents')),
      shoppingRecipeIds: _stringSet(box.get('shoppingRecipeIds')),
      contentRequests: _stringList(box.get('contentRequests')),
      cookProgress: _cookProgress(box.get('cookProgress')),
    );
  }

  final RecipeRepository repository;
  final SharedPreferences _preferences;
  final Box<String> _box;
  Profile profile;
  bool onboardingComplete;
  final Set<String> savedRecipeIds;
  final Map<String, String> mealPlan;
  final List<HistoryEntry> history;
  final List<ShoppingEvent> shoppingEvents;
  final Set<String> shoppingRecipeIds;
  final List<String> contentRequests;
  final Map<String, CookProgress> cookProgress;

  String get lang => profile.lang;
  List<Recipe> get allRecipes => repository.recipes.values.toList();
  List<Recipe> get savedRecipes => savedRecipeIds
      .map((id) => repository.recipes[id])
      .whereType<Recipe>()
      .toList();
  List<Recipe> get shoppingRecipes => shoppingRecipeIds
      .map((id) => repository.recipes[id])
      .whereType<Recipe>()
      .toList();

  bool isVisible(Recipe recipe, {bool ignoreCalories = false}) =>
      RecipeMatcher.isVisible(
        recipe,
        profile,
        repository,
        ignoreCalories: ignoreCalories,
      );

  List<Recipe> rankedVisibleRecipes({DateTime? now}) => RecipeRanker.rank(
    allRecipes.where(isVisible),
    profile,
    history,
    now: now,
  );

  List<Recipe> recipesForDish(String dishId) =>
      repository.recipesForDish(dishId);
  Recipe? recipeById(String id) => repository.recipes[id];
  Dish? dishById(String id) => repository.dishes[id];

  Future<void> prepareDish(String dishId) async {
    final dish = repository.dishes[dishId];
    if (dish == null) return;
    await repository.ensurePartition(dish.partitionId);
    for (final partition in dish.secondaryPartitions) {
      await repository.ensurePartition(partition);
    }
    notifyListeners();
  }

  Future<List<Recipe>> search(
    String query, {
    Set<String> tags = const {},
  }) async {
    final results = await repository.search(query, lang, tags: tags);
    final visible = results.where(isVisible).toList();
    if (query.trim().isNotEmpty &&
        visible.isEmpty &&
        !contentRequests.contains(query.trim())) {
      contentRequests.add(query.trim());
      unawaited(_put('contentRequests', jsonEncode(contentRequests)));
      notifyListeners();
    }
    return RecipeRanker.rank(visible, profile, history);
  }

  Future<void> completeOnboarding(Profile value) async {
    profile = value;
    onboardingComplete = true;
    await _persistProfile();
    await _preferences.setBool('onboardingComplete', true);
    notifyListeners();
  }

  Future<void> updateProfile(Profile value) async {
    profile = value;
    await _persistProfile();
    notifyListeners();
  }

  Future<void> toggleSaved(String recipeId) async {
    if (!savedRecipeIds.add(recipeId)) savedRecipeIds.remove(recipeId);
    await _put('saved', jsonEncode(savedRecipeIds.toList()..sort()));
    notifyListeners();
  }

  Future<void> assignMeal(DateTime day, String meal, String? recipeId) async {
    final key = mealPlanKey(day, meal);
    if (recipeId == null) {
      mealPlan.remove(key);
    } else {
      mealPlan[key] = recipeId;
    }
    await _put('mealPlan', jsonEncode(mealPlan));
    notifyListeners();
  }

  String? mealAt(DateTime day, String meal) => mealPlan[mealPlanKey(day, meal)];

  Future<void> addRecipesToShopping(Iterable<String> recipeIds) async {
    shoppingRecipeIds.addAll(
      recipeIds.where((id) => repository.recipes.containsKey(id)),
    );
    await _put(
      'shoppingRecipeIds',
      jsonEncode(shoppingRecipeIds.toList()..sort()),
    );
    notifyListeners();
  }

  Future<void> toggleShoppingRecipe(String recipeId) async {
    if (!shoppingRecipeIds.add(recipeId)) shoppingRecipeIds.remove(recipeId);
    await _put(
      'shoppingRecipeIds',
      jsonEncode(shoppingRecipeIds.toList()..sort()),
    );
    notifyListeners();
  }

  Future<void> completeShoppingTrip() async {
    final ingredientIds = shoppingRecipes
        .expand(
          (recipe) => recipe.ingredients.map((ingredient) => ingredient.id),
        )
        .toList();
    if (ingredientIds.isNotEmpty) {
      shoppingEvents.add(
        ShoppingEvent(ingredientIds: ingredientIds, createdAt: DateTime.now()),
      );
    }
    shoppingRecipeIds.clear();
    await Future.wait([
      _put(
        'shoppingEvents',
        jsonEncode(shoppingEvents.map((event) => event.toJson()).toList()),
      ),
      _put('shoppingRecipeIds', jsonEncode(<String>[])),
    ]);
    notifyListeners();
  }

  Future<void> recordCooked(String recipeId) async {
    history.add(HistoryEntry(recipeId: recipeId, cookedAt: DateTime.now()));
    if (history.length > 350) history.removeRange(0, history.length - 350);
    await _put(
      'history',
      jsonEncode(history.map((event) => event.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<void> saveCookProgress(CookProgress progress) async {
    cookProgress[progress.recipeId] = progress;
    await _put(
      'cookProgress',
      jsonEncode(
        cookProgress.map((key, value) => MapEntry(key, value.toJson())),
      ),
    );
  }

  Future<void> clearCookProgress(String recipeId) async {
    cookProgress.remove(recipeId);
    await _put(
      'cookProgress',
      jsonEncode(
        cookProgress.map((key, value) => MapEntry(key, value.toJson())),
      ),
    );
  }

  Map<String, dynamic> exportData() => {
    'schema_version': 1,
    'exported_at': DateTime.now().toUtc().toIso8601String(),
    'profile': profile.toJson(),
    'saved': savedRecipeIds.toList()..sort(),
    'meal_plan': mealPlan,
    'history': history.map((entry) => entry.toJson()).toList(),
    'content_requests': contentRequests,
    'shopping_events': shoppingEvents.map((entry) => entry.toJson()).toList(),
    'shopping_selection': shoppingRecipeIds.toList()..sort(),
    'cook_progress': cookProgress.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
  };

  Future<void> restore(
    Map<String, dynamic> payload, {
    required bool merge,
  }) async {
    final importedProfile = payload['profile'] is Map
        ? Profile.fromJson(
            (payload['profile'] as Map).map(
              (key, value) => MapEntry('$key', value),
            ),
          )
        : null;
    final importedSaved = stringSet(payload['saved']);
    final importedPlan = payload['meal_plan'] is Map
        ? (payload['meal_plan'] as Map).map(
            (key, value) => MapEntry('$key', '$value'),
          )
        : <String, String>{};
    final importedHistory = (payload['history'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => HistoryEntry.fromJson(
            item.map((key, value) => MapEntry('$key', value)),
          ),
        )
        .toList();
    final importedRequests = stringList(payload['content_requests']);
    final importedEvents = (payload['shopping_events'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => ShoppingEvent.fromJson(
            item.map((key, value) => MapEntry('$key', value)),
          ),
        )
        .toList();
    final importedSelection = stringSet(payload['shopping_selection']);
    final importedProgress = _progressFromRaw(payload['cook_progress']);

    if (!merge) {
      if (importedProfile != null) profile = importedProfile;
      savedRecipeIds
        ..clear()
        ..addAll(importedSaved);
      mealPlan
        ..clear()
        ..addAll(importedPlan);
      history
        ..clear()
        ..addAll(importedHistory);
      shoppingEvents
        ..clear()
        ..addAll(importedEvents);
      shoppingRecipeIds
        ..clear()
        ..addAll(importedSelection);
      contentRequests
        ..clear()
        ..addAll(importedRequests);
      cookProgress
        ..clear()
        ..addAll(importedProgress);
    } else {
      if (importedProfile != null) profile = importedProfile;
      savedRecipeIds.addAll(importedSaved);
      mealPlan.addAll(importedPlan);
      history.addAll(importedHistory);
      shoppingEvents.addAll(importedEvents);
      shoppingRecipeIds.addAll(importedSelection);
      for (final request in importedRequests) {
        if (!contentRequests.contains(request)) contentRequests.add(request);
      }
      cookProgress.addAll(importedProgress);
    }
    onboardingComplete = true;
    await _persistEverything();
    await _preferences.setBool('onboardingComplete', true);
    notifyListeners();
  }

  Future<void> _persistEverything() async {
    await _persistProfile();
    await Future.wait([
      _put('saved', jsonEncode(savedRecipeIds.toList()..sort())),
      _put('mealPlan', jsonEncode(mealPlan)),
      _put(
        'history',
        jsonEncode(history.map((entry) => entry.toJson()).toList()),
      ),
      _put(
        'shoppingEvents',
        jsonEncode(shoppingEvents.map((entry) => entry.toJson()).toList()),
      ),
      _put('shoppingRecipeIds', jsonEncode(shoppingRecipeIds.toList()..sort())),
      _put('contentRequests', jsonEncode(contentRequests)),
      _put(
        'cookProgress',
        jsonEncode(
          cookProgress.map((key, value) => MapEntry(key, value.toJson())),
        ),
      ),
    ]);
  }

  Future<void> _persistProfile() =>
      _preferences.setString('profile', jsonEncode(profile.toJson()));

  Future<void> _put(String key, String value) => _box.put(key, value);

  static dynamic _decode(String? source, dynamic fallback) {
    if (source == null) return fallback;
    try {
      return jsonDecode(source);
    } catch (_) {
      return fallback;
    }
  }

  static Set<String> _stringSet(String? source) =>
      stringSet(_decode(source, const []));
  static List<String> _stringList(String? source) =>
      stringList(_decode(source, const []));
  static Map<String, String> _stringMap(String? source) {
    final decoded = _decode(source, const <String, dynamic>{});
    if (decoded is! Map) return {};
    return decoded.map((key, value) => MapEntry('$key', '$value'));
  }

  static List<HistoryEntry> _historyList(String? source) {
    final decoded = _decode(source, const []);
    return (decoded as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => HistoryEntry.fromJson(
            item.map((key, value) => MapEntry('$key', value)),
          ),
        )
        .toList();
  }

  static List<ShoppingEvent> _shoppingEvents(String? source) {
    final decoded = _decode(source, const []);
    return (decoded as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => ShoppingEvent.fromJson(
            item.map((key, value) => MapEntry('$key', value)),
          ),
        )
        .toList();
  }

  static Map<String, CookProgress> _cookProgress(String? source) =>
      _progressFromRaw(_decode(source, const <String, dynamic>{}));

  static Map<String, CookProgress> _progressFromRaw(dynamic raw) {
    if (raw is! Map) return {};
    return {
      for (final entry in raw.entries)
        if (entry.value is Map)
          '${entry.key}': CookProgress.fromJson(
            (entry.value as Map).map((key, value) => MapEntry('$key', value)),
          ),
    };
  }
}
