import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Hive-backed collections: saved recipes, cooking history, meal plan,
/// shopping list, shopping events (insights), content requests, cook progress.
///
/// Everything is stored as plain JSON strings — no codegen, no adapters.
class LocalStore extends ChangeNotifier {
  static const _boxName = 'morphcook';

  Box<String>? _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    _saved.addAll(_readJsonList('saved')
        .map((e) => SavedRecipe.fromJson(e as Map<String, dynamic>)));
    _history.addAll(_readJsonList('history')
        .map((e) => CookEvent.fromJson(e as Map<String, dynamic>)));
    _mealPlan.addAll((_readJsonMap('meal_plan'))
        .map((k, v) => MapEntry(k, (v as Map).cast<String, String>())));
    _shoppingChecked.addAll(
        (jsonDecode(_box!.get('shopping_checked') ?? '[]') as List)
            .cast<String>());
    _shoppingRecipes.addAll(
        (jsonDecode(_box!.get('shopping_recipes') ?? '[]') as List)
            .cast<String>());
    _shoppingEvents.addAll(_readJsonList('shopping_events')
        .map((e) => ShoppingEvent.fromJson(e as Map<String, dynamic>)));
    _contentRequests.addAll(
        (jsonDecode(_box!.get('content_requests') ?? '[]') as List)
            .cast<String>());
    _cookProgress.addAll((_readJsonMap('cook_progress'))
        .map((k, v) => MapEntry(k, (v as num).toInt())));
  }

  List<dynamic> _readJsonList(String key) =>
      jsonDecode(_box!.get(key) ?? '[]') as List;

  Map<String, dynamic> _readJsonMap(String key) =>
      jsonDecode(_box!.get(key) ?? '{}') as Map<String, dynamic>;

  Future<void> _write(String key, Object value) =>
      _box!.put(key, jsonEncode(value));

  // ---- saved (cookbook) -------------------------------------------------

  final List<SavedRecipe> _saved = [];
  List<SavedRecipe> get saved => List.unmodifiable(_saved);

  bool isSaved(String recipeId) => _saved.any((s) => s.recipeId == recipeId);

  Future<void> toggleSaved(String recipeId) async {
    final idx = _saved.indexWhere((s) => s.recipeId == recipeId);
    if (idx >= 0) {
      _saved.removeAt(idx);
    } else {
      _saved.insert(
          0,
          SavedRecipe(
              recipeId: recipeId,
              savedAt: DateTime.now().millisecondsSinceEpoch));
    }
    await _write('saved', _saved.map((s) => s.toJson()).toList());
    notifyListeners();
  }

  // ---- history ----------------------------------------------------------

  final List<CookEvent> _history = [];
  List<CookEvent> get history => List.unmodifiable(_history);

  Future<void> logCooked(String recipeId) async {
    _history.insert(
        0,
        CookEvent(
            recipeId: recipeId,
            cookedAt: DateTime.now().millisecondsSinceEpoch));
    await _write('history', _history.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  /// recipeId → last cooked timestamp (millis).
  Map<String, int> get lastCookedAtByRecipe {
    final out = <String, int>{};
    for (final e in _history) {
      final prev = out[e.recipeId];
      if (prev == null || e.cookedAt > prev) out[e.recipeId] = e.cookedAt;
    }
    return out;
  }

  // ---- meal plan ----------------------------------------------------------

  /// ISO week key ('2026-W16') → {'mon.dinner': recipeId}
  final Map<String, Map<String, String>> _mealPlan = {};
  Map<String, Map<String, String>> get mealPlan => _mealPlan;

  Map<String, String> weekPlan(String weekKey) =>
      _mealPlan[weekKey] ?? const {};

  Future<void> assignSlot(String weekKey, String slot, String? recipeId) async {
    final week = _mealPlan.putIfAbsent(weekKey, () => {});
    if (recipeId == null) {
      week.remove(slot);
    } else {
      week[slot] = recipeId;
    }
    if (week.isEmpty) _mealPlan.remove(weekKey);
    await _write('meal_plan', _mealPlan);
    notifyListeners();
  }

  // ---- shopping list -------------------------------------------------------

  /// Recipe ids currently on the shopping list (aggregation sources).
  final Set<String> _shoppingRecipes = {};
  List<String> get shoppingRecipes => List.unmodifiable(_shoppingRecipes);

  bool onShoppingList(String recipeId) => _shoppingRecipes.contains(recipeId);

  Future<void> addToShoppingList(String recipeId,
      {Iterable<String>? ingredientIds}) async {
    if (!_shoppingRecipes.add(recipeId)) return;
    await _write('shopping_recipes', _shoppingRecipes);
    if (ingredientIds != null) {
      await logShoppingAddAll(ingredientIds);
    }
    notifyListeners();
  }

  Future<void> addAllToShoppingList(Map<String, Iterable<String>> recipes) async {
    var changed = false;
    for (final entry in recipes.entries) {
      if (_shoppingRecipes.add(entry.key)) {
        changed = true;
        await logShoppingAddAll(entry.value);
      }
    }
    if (changed) {
      await _write('shopping_recipes', _shoppingRecipes);
      notifyListeners();
    }
  }

  Future<void> removeFromShoppingList(String recipeId) async {
    if (_shoppingRecipes.remove(recipeId)) {
      await _write('shopping_recipes', _shoppingRecipes);
      notifyListeners();
    }
  }

  Future<void> clearShoppingList() async {
    _shoppingRecipes.clear();
    _shoppingChecked.clear();
    await _write('shopping_recipes', <String>[]);
    await _write('shopping_checked', <String>[]);
    notifyListeners();
  }

  /// Checked-off shopping line keys ('ingredientId|unit').
  final Set<String> _shoppingChecked = {};
  Set<String> get shoppingChecked => _shoppingChecked;

  Future<void> toggleShoppingChecked(String lineKey) async {
    if (!_shoppingChecked.add(lineKey)) _shoppingChecked.remove(lineKey);
    await _write('shopping_checked', _shoppingChecked.toList());
    notifyListeners();
  }

  Future<void> clearShoppingChecked() async {
    _shoppingChecked.clear();
    await _write('shopping_checked', <String>[]);
    notifyListeners();
  }

  /// Ingredient-add events, for Shopping Insights.
  final List<ShoppingEvent> _shoppingEvents = [];
  List<ShoppingEvent> get shoppingEvents => List.unmodifiable(_shoppingEvents);

  Future<void> logShoppingAdd(String ingredientId) async {
    _shoppingEvents.add(ShoppingEvent(
        ingredientId: ingredientId,
        at: DateTime.now().millisecondsSinceEpoch));
    await _write(
        'shopping_events', _shoppingEvents.map((e) => e.toJson()).toList());
  }

  Future<void> logShoppingAddAll(Iterable<String> ingredientIds) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    _shoppingEvents.addAll(
        ingredientIds.map((id) => ShoppingEvent(ingredientId: id, at: now)));
    await _write(
        'shopping_events', _shoppingEvents.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  // ---- content requests -----------------------------------------------------

  final List<String> _contentRequests = [];
  List<String> get contentRequests => List.unmodifiable(_contentRequests);

  Future<void> logContentRequest(String query) async {
    final q = query.trim();
    if (q.isEmpty || _contentRequests.contains(q)) return;
    _contentRequests.add(q);
    await _write('content_requests', _contentRequests);
  }

  // ---- cook-mode progress -----------------------------------------------------

  /// recipeId → step index (pause/resume persistence).
  final Map<String, int> _cookProgress = {};
  Map<String, int> get cookProgress => _cookProgress;

  Future<void> saveCookProgress(String recipeId, int stepIndex) async {
    _cookProgress[recipeId] = stepIndex;
    await _write('cook_progress', _cookProgress);
  }

  Future<void> clearCookProgress(String recipeId) async {
    _cookProgress.remove(recipeId);
    await _write('cook_progress', _cookProgress);
    notifyListeners();
  }

  // ---- backup payloads -------------------------------------------------------

  Map<String, dynamic> exportData() => {
        'saved': _saved.map((s) => s.recipeId).toList(),
        'meal_plan': _mealPlan,
        'history': _history.map((e) => e.toJson()).toList(),
        'content_requests': _contentRequests,
        'shopping_events': _shoppingEvents.map((e) => e.toJson()).toList(),
        'cook_progress': _cookProgress,
      };

  /// [merge] = union with existing; otherwise replace.
  Future<void> importData(Map<String, dynamic> data, {required bool merge}) async {
    if (!merge) {
      _saved.clear();
      _history.clear();
      _mealPlan.clear();
      _shoppingEvents.clear();
      _contentRequests.clear();
      _cookProgress.clear();
    }
    for (final id in (data['saved'] as List? ?? []).cast<String>()) {
      if (!isSaved(id)) {
        _saved.add(SavedRecipe(
            recipeId: id, savedAt: DateTime.now().millisecondsSinceEpoch));
      }
    }
    _history.addAll((data['history'] as List? ?? []).map(
        (e) => CookEvent.fromJson((e as Map).cast<String, dynamic>())));
    (data['meal_plan'] as Map? ?? {}).forEach((week, slots) {
      final target = _mealPlan.putIfAbsent(week as String, () => {});
      (slots as Map).forEach((slot, recipe) {
        target[slot as String] = recipe as String;
      });
    });
    _shoppingEvents.addAll((data['shopping_events'] as List? ?? []).map(
        (e) => ShoppingEvent.fromJson((e as Map).cast<String, dynamic>())));
    for (final q in (data['content_requests'] as List? ?? []).cast<String>()) {
      if (!_contentRequests.contains(q)) _contentRequests.add(q);
    }
    (data['cook_progress'] as Map? ?? {}).forEach((k, v) {
      _cookProgress[k as String] = (v as num).toInt();
    });

    await _write('saved', _saved.map((s) => s.toJson()).toList());
    await _write('history', _history.map((e) => e.toJson()).toList());
    await _write('meal_plan', _mealPlan);
    await _write(
        'shopping_events', _shoppingEvents.map((e) => e.toJson()).toList());
    await _write('content_requests', _contentRequests);
    await _write('cook_progress', _cookProgress);
    notifyListeners();
  }
}

class SavedRecipe {
  final String recipeId;
  final int savedAt;
  const SavedRecipe({required this.recipeId, required this.savedAt});
  Map<String, dynamic> toJson() => {'recipe_id': recipeId, 'saved_at': savedAt};
  factory SavedRecipe.fromJson(Map<String, dynamic> json) => SavedRecipe(
      recipeId: json['recipe_id'] as String,
      savedAt: (json['saved_at'] as num).toInt());
}

class CookEvent {
  final String recipeId;
  final int cookedAt;
  const CookEvent({required this.recipeId, required this.cookedAt});
  Map<String, dynamic> toJson() =>
      {'recipe_id': recipeId, 'cooked_at': cookedAt};
  factory CookEvent.fromJson(Map<String, dynamic> json) => CookEvent(
      recipeId: json['recipe_id'] as String,
      cookedAt: (json['cooked_at'] as num).toInt());
}

class ShoppingEvent {
  final String ingredientId;
  final int at;
  const ShoppingEvent({required this.ingredientId, required this.at});
  Map<String, dynamic> toJson() => {'ingredient_id': ingredientId, 'at': at};
  factory ShoppingEvent.fromJson(Map<String, dynamic> json) => ShoppingEvent(
      ingredientId: json['ingredient_id'] as String,
      at: (json['at'] as num).toInt());
}
