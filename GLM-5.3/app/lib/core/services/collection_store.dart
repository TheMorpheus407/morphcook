import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/user_data.dart';
import '../shopping/aggregator.dart';
import 'backup_service.dart';

/// Hive-backed persistence for the user collections (SPEC: Hive for
/// saved/history/meal-plan collections). Everything is stored as JSON
/// strings inside a single box — no code generation required.
class CollectionStore {
  CollectionStore(this._box);

  static const _keySaved = 'saved';
  static const _keyHistory = 'history';
  static const _keyMealPlan = 'meal_plan';
  static const _keyShoppingItems = 'shopping_items';
  static const _keyShoppingAdditions = 'shopping_additions';
  static const _keyContentRequests = 'content_requests';

  final Box _box;

  // ---------- cookbook (saved variants) ----------

  List<SavedEntry> loadSaved() => _loadList(_keySaved, SavedEntry.fromJson);

  Future<void> saveRecipe(String recipeId) async {
    final saved = loadSaved();
    if (saved.any((e) => e.recipeId == recipeId)) return;
    saved.add(SavedEntry(recipeId: recipeId, at: DateTime.now()));
    await _box.put(_keySaved, jsonEncode(saved.map((e) => e.toJson()).toList()));
  }

  Future<void> unsaveRecipe(String recipeId) async {
    final saved = loadSaved().where((e) => e.recipeId != recipeId).toList();
    await _box.put(_keySaved, jsonEncode(saved.map((e) => e.toJson()).toList()));
  }

  // ---------- cooking history ----------

  List<HistoryEntry> loadHistory() => _loadList(_keyHistory, HistoryEntry.fromJson);

  Future<void> addHistory(String recipeId, {int servings = 2}) async {
    final history = loadHistory();
    history.add(HistoryEntry(recipeId: recipeId, at: DateTime.now(), servings: servings));
    await _box.put(_keyHistory, jsonEncode(history.map((e) => e.toJson()).toList()));
  }

  /// The most recent cook date per recipe id (drives staleness ranking).
  Map<String, DateTime> lastCookedByRecipe() {
    final result = <String, DateTime>{};
    for (final entry in loadHistory()) {
      final existing = result[entry.recipeId];
      if (existing == null || entry.at.isAfter(existing)) {
        result[entry.recipeId] = entry.at;
      }
    }
    return result;
  }

  // ---------- meal plan ----------

  MealPlan loadMealPlan() {
    final raw = _box.get(_keyMealPlan);
    if (raw is! String) return MealPlan();
    try {
      return MealPlan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return MealPlan();
    }
  }

  Future<void> saveMealPlan(MealPlan plan) =>
      _box.put(_keyMealPlan, jsonEncode(plan.toJson()));

  // ---------- shopping list ----------

  List<ShoppingItem> loadShoppingItems() => _loadList(_keyShoppingItems, ShoppingItem.fromJson);

  Future<void> saveShoppingItems(List<ShoppingItem> items) async {
    await _box.put(
        _keyShoppingItems, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  List<ShoppingAddition> loadShoppingAdditions() =>
      _loadList(_keyShoppingAdditions, ShoppingAddition.fromJson);

  Future<void> addShoppingAddition(ShoppingAddition addition) async {
    final additions = loadShoppingAdditions();
    additions.add(addition);
    await _box.put(_keyShoppingAdditions,
        jsonEncode(additions.map((e) => e.toJson()).toList()));
  }

  // ---------- content requests (zero-result searches) ----------

  List<ContentRequest> loadContentRequests() =>
      _loadList(_keyContentRequests, ContentRequest.fromJson);

  Future<void> addContentRequest(String query) async {
    final requests = loadContentRequests();
    requests.add(ContentRequest(query: query, at: DateTime.now()));
    await _box.put(_keyContentRequests,
        jsonEncode(requests.map((e) => e.toJson()).toList()));
  }

  // ---------- import merge/replace ----------

  Future<void> importData({
    required ImportMode mode,
    required List<String> saved,
    required Map<String, dynamic> mealPlan,
    required List<HistoryEntry> history,
    required List<ContentRequest> contentRequests,
  }) async {
    if (mode == ImportMode.replace) {
      await _box.put(_keySaved, jsonEncode(saved.map((id) => SavedEntry(
            recipeId: id,
            at: DateTime.now(),
          ).toJson()).toList()));
      await _box.put(_keyHistory, jsonEncode(history.map((e) => e.toJson()).toList()));
      await _box.put(_keyContentRequests,
          jsonEncode(contentRequests.map((e) => e.toJson()).toList()));
    } else {
      final existingSaved = loadSaved().map((e) => e.recipeId).toSet();
      for (final id in saved) {
        if (!existingSaved.contains(id)) {
          await saveRecipe(id);
        }
      }
      final existingHistory = loadHistory();
      final merged = [...existingHistory, ...history]..sort((a, b) => a.at.compareTo(b.at));
      await _box.put(_keyHistory, jsonEncode(merged.map((e) => e.toJson()).toList()));
      final existingRequests = loadContentRequests();
      final mergedRequests = [...existingRequests, ...contentRequests]
        ..sort((a, b) => a.at.compareTo(b.at));
      await _box.put(_keyContentRequests,
          jsonEncode(mergedRequests.map((e) => e.toJson()).toList()));
    }
    await saveMealPlan(MealPlan.fromJson(mealPlan));
  }

  // ---------- helpers ----------

  List<T> _loadList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final raw = _box.get(key);
    if (raw is! String) return <T>[];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => fromJson((e as Map).cast<String, dynamic>())).toList();
    } catch (_) {
      return <T>[];
    }
  }
}
