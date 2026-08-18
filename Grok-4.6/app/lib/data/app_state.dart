import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../logic/backup.dart';
import '../logic/cook.dart';
import '../logic/matching.dart';
import '../logic/ranking.dart';
import '../logic/shopping.dart';
import '../models/collections.dart';
import '../models/dish.dart';
import '../models/profile.dart';
import '../models/recipe.dart';
import 'corpus.dart';
import 'store.dart';

class AppState extends ChangeNotifier {
  final PersistenceStore store;
  final CorpusRepository corpus;

  AppState({required this.store, required this.corpus});

  Profile _profile = const Profile();
  bool _onboarded = false;
  List<SavedRecipe> _saved = [];
  List<HistoryEntry> _history = [];
  MealPlanData _mealPlan = {};
  List<ShoppingItem> _shoppingList = [];
  List<ShoppingItem> _shoppingHistory = [];
  List<String> _contentRequests = [];
  CookProgress? _cookProgress;

  Profile get profile => _profile;
  bool get onboarded => _onboarded;
  List<SavedRecipe> get saved => List.unmodifiable(_saved);
  List<HistoryEntry> get history => List.unmodifiable(_history);
  MealPlanData get mealPlan => _mealPlan;
  List<ShoppingItem> get shoppingList => List.unmodifiable(_shoppingList);
  List<ShoppingItem> get shoppingHistory => List.unmodifiable(_shoppingHistory);
  List<String> get contentRequests => List.unmodifiable(_contentRequests);
  CookProgress? get cookProgress => _cookProgress;

  String get lang => _profile.lang;

  Matcher get matcher =>
      Matcher(ontology: corpus.ontology, dictionary: corpus.dictionary);
  final Ranker ranker = Ranker();

  Future<void> load() async {
    await store.open();
    _profile = store.loadProfile() ?? const Profile();
    _onboarded = store.onboardingComplete;
    _saved = _readList('saved', SavedRecipe.fromJson);
    _history = _readList('history', HistoryEntry.fromJson);
    _shoppingList = _readList('shopping_list', ShoppingItem.fromJson);
    _shoppingHistory = _readList('shopping_history', ShoppingItem.fromJson);
    _mealPlan = _readMealPlan();
    _contentRequests = _readStrings('content_requests');
    final progressRaw = store.getCollection('cook_progress');
    if (progressRaw != null && progressRaw != 'null') {
      try {
        _cookProgress = CookProgress.fromJson(
          json.decode(progressRaw) as Map<String, dynamic>,
        );
      } catch (_) {}
    }
    notifyListeners();
  }

  List<T> _readList<T>(String key, T Function(Map<String, dynamic>) parse) {
    final raw = store.getCollection(key);
    if (raw == null) return [];
    try {
      return (json.decode(raw) as List)
          .map((e) => parse(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<String> _readStrings(String key) {
    final raw = store.getCollection(key);
    if (raw == null) return [];
    try {
      return List<String>.from(json.decode(raw) as List);
    } catch (_) {
      return [];
    }
  }

  MealPlanData _readMealPlan() {
    final raw = store.getCollection('meal_plan');
    if (raw == null) return {};
    try {
      return (json.decode(raw) as Map<String, dynamic>).map(
        (week, slots) => MapEntry(
          week,
          (slots as Map<String, dynamic>).map(
            (slot, id) => MapEntry(slot, id as String),
          ),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeJson(String key, Object value) =>
      store.putCollection(key, json.encode(value));

  Future<void> updateProfile(Profile profile) async {
    _profile = profile;
    await store.saveProfile(profile);
    notifyListeners();
  }

  Future<void> completeOnboarding(Profile profile) async {
    await store.saveProfile(profile);
    await store.setOnboardingComplete(true);
    _profile = profile;
    _onboarded = true;
    notifyListeners();
  }

  bool isSaved(String recipeId) => _saved.any((s) => s.recipeId == recipeId);

  Future<void> toggleSaved(String recipeId) async {
    if (isSaved(recipeId)) {
      _saved.removeWhere((s) => s.recipeId == recipeId);
    } else {
      _saved.add(SavedRecipe(recipeId: recipeId, savedAt: DateTime.now()));
    }
    await _writeJson('saved', _saved.map((s) => s.toJson()).toList());
    notifyListeners();
  }

  Future<void> logCooked(String recipeId) async {
    _history.add(HistoryEntry(recipeId: recipeId, cookedAt: DateTime.now()));
    await _writeJson('history', _history.map((h) => h.toJson()).toList());
    notifyListeners();
  }

  Future<void> assignMeal(String weekKey, String slot, String recipeId) async {
    _mealPlan.putIfAbsent(weekKey, () => {})[slot] = recipeId;
    await _writeJson('meal_plan', _mealPlan);
    notifyListeners();
  }

  Future<void> clearMeal(String weekKey, String slot) async {
    _mealPlan[weekKey]?.remove(slot);
    if (_mealPlan[weekKey]?.isEmpty ?? false) _mealPlan.remove(weekKey);
    await _writeJson('meal_plan', _mealPlan);
    notifyListeners();
  }

  Future<void> moveMeal(String weekKey, String fromSlot, String toSlot) async {
    final week = _mealPlan[weekKey];
    if (week == null || !week.containsKey(fromSlot)) return;
    final moving = week.remove(fromSlot)!;
    final displaced = week[toSlot];
    week[toSlot] = moving;
    if (displaced != null) week[fromSlot] = displaced;
    await _writeJson('meal_plan', _mealPlan);
    notifyListeners();
  }

  Future<void> addToShoppingList(Iterable<(Recipe, double)> recipes) async {
    final aggregated = aggregate(recipes, corpus.dictionary);
    final now = DateTime.now();
    _shoppingList = mergeIntoList(_shoppingList, aggregated, now);
    _shoppingHistory = [
      ..._shoppingHistory,
      ...aggregated.map(
        (a) => ShoppingItem(
          ingredientId: a.ingredientId,
          qty: a.quantity.amount,
          unit: a.quantity.unit,
          aisle: a.aisle,
          addedAt: now,
        ),
      ),
    ];
    await _writeJson(
      'shopping_list',
      _shoppingList.map((s) => s.toJson()).toList(),
    );
    await _writeJson(
      'shopping_history',
      _shoppingHistory.map((s) => s.toJson()).toList(),
    );
    notifyListeners();
  }

  Future<void> toggleShoppingItem(int index) async {
    if (index < 0 || index >= _shoppingList.length) return;
    _shoppingList[index] = _shoppingList[index].copyWith(
      checked: !_shoppingList[index].checked,
    );
    await _writeJson(
      'shopping_list',
      _shoppingList.map((s) => s.toJson()).toList(),
    );
    notifyListeners();
  }

  Future<void> clearCheckedShoppingItems() async {
    _shoppingList.removeWhere((s) => s.checked);
    await _writeJson(
      'shopping_list',
      _shoppingList.map((s) => s.toJson()).toList(),
    );
    notifyListeners();
  }

  Future<void> clearShoppingList() async {
    _shoppingList = [];
    await _writeJson('shopping_list', const []);
    notifyListeners();
  }

  Future<void> logContentRequest(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty || _contentRequests.contains(q)) return;
    _contentRequests.add(q);
    await _writeJson('content_requests', _contentRequests);
  }

  Future<void> persistCookProgress(CookProgress? progress) async {
    _cookProgress = progress;
    if (progress == null) {
      await store.putCollection('cook_progress', 'null');
    } else {
      await _writeJson('cook_progress', progress.toJson());
    }
  }

  BackupData buildBackup() => BackupData(
        profile: _profile,
        saved: _saved,
        mealPlan: _mealPlan,
        history: _history,
        shoppingHistory: _shoppingHistory,
        contentRequests: _contentRequests,
      );

  Future<void> applyBackup(BackupData incoming, {required bool merge}) async {
    final data = merge ? BackupService.merge(buildBackup(), incoming) : incoming;
    _profile = data.profile;
    _saved = List.of(data.saved);
    _mealPlan = {
      for (final e in data.mealPlan.entries) e.key: Map<String, String>.of(e.value),
    };
    _history = List.of(data.history);
    _shoppingHistory = List.of(data.shoppingHistory);
    _contentRequests = List.of(data.contentRequests);
    if (!merge) {
      _shoppingList = [];
      _cookProgress = null;
    }
    await store.saveProfile(_profile);
    await store.setOnboardingComplete(true);
    _onboarded = true;
    await store.putCollections({
      'saved': json.encode(_saved.map((s) => s.toJson()).toList()),
      'meal_plan': json.encode(_mealPlan),
      'history': json.encode(_history.map((h) => h.toJson()).toList()),
      'shopping_history':
          json.encode(_shoppingHistory.map((s) => s.toJson()).toList()),
      'shopping_list':
          json.encode(_shoppingList.map((s) => s.toJson()).toList()),
      'content_requests': json.encode(_contentRequests),
      'cook_progress':
          _cookProgress == null ? 'null' : json.encode(_cookProgress!.toJson()),
    });
    notifyListeners();
  }

  Future<void> resetAll() async {
    await store.clearAll();
    _profile = const Profile();
    _onboarded = false;
    _saved = [];
    _history = [];
    _mealPlan = {};
    _shoppingList = [];
    _shoppingHistory = [];
    _contentRequests = [];
    _cookProgress = null;
    notifyListeners();
  }

  List<Recipe> visibleRecipes({bool ignoreCalories = false}) {
    return corpus.loadedRecipes
        .where(
          (r) => matcher.isVisible(
            r,
            _profile,
            ignoreCalories: ignoreCalories,
          ),
        )
        .toList();
  }

  Recipe? bestForDish(Dish dish, {bool ignoreCalories = false}) {
    final variants = dish.recipeIds
        .map(corpus.loadedRecipeById)
        .whereType<Recipe>()
        .where(
          (r) => matcher.isVisible(
            r,
            _profile,
            ignoreCalories: ignoreCalories,
          ),
        );
    return ranker.pickBest(variants, _profile, _history);
  }
}
