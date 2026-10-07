import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/corpus.dart';
import '../core/matching.dart';
import '../core/model/meal_plan.dart';
import '../core/model/profile.dart';
import '../core/model/recipe.dart';
import '../core/model/shopping.dart';
import '../core/units.dart';
import 'storage.dart';

/// The app's single source of truth at runtime. Boring on purpose: one
/// ChangeNotifier, write-through persistence, no Redux, no BLoC.
class AppState extends ChangeNotifier {
  AppState({Corpus? corpus, Matcher? matcher})
      : _corpus = corpus,
        _matcher = matcher;

  Corpus? _corpus;
  Matcher? _matcher;

  UserProfile _profile = const UserProfile();
  final List<String> _savedRecipeIds = []; // newest first
  final List<HistoryEntry> _history = []; // newest first
  final MealPlanMap _mealPlan = {};
  final Map<String, ShoppingItem> _shopping = {}; // ingredientId -> item
  final List<ShoppingLogEntry> _shoppingLog = [];
  final List<String> _contentRequests = [];

  final ShoppingAggregator _aggregator = const ShoppingAggregator();

  UserProfile get profile => _profile;
  Corpus get corpus => _corpus!;
  Matcher get matcher => _matcher!;

  List<String> get savedRecipeIds => List.unmodifiable(_savedRecipeIds);
  List<HistoryEntry> get history => List.unmodifiable(_history);
  MealPlanMap get mealPlan => _mealPlan;
  List<ShoppingItem> get shoppingItems => _shopping.values.toList();
  List<ShoppingLogEntry> get shoppingLog => List.unmodifiable(_shoppingLog);
  List<String> get contentRequests => List.unmodifiable(_contentRequests);

  bool get onboardingComplete => _profile.onboardingComplete;

  bool isSaved(String recipeId) => _savedRecipeIds.contains(recipeId);

  String? recipeIdAt(String weekId, String slot) => _mealPlan[weekId]?[slot];

  /// Map recipeId → most recent cook date, for staleness-aware ranking.
  Map<String, DateTime> get lastCookedByRecipe {
    final result = <String, DateTime>{};
    for (final entry in _history) {
      final existing = result[entry.recipeId];
      if (existing == null || entry.cookedAt.isAfter(existing)) {
        result[entry.recipeId] = entry.cookedAt;
      }
    }
    return result;
  }

  Future<void> init({required Corpus corpus, required Matcher matcher}) async {
    _corpus = corpus;
    _matcher = matcher;

    final rawProfile = AppStorage.prefs.getString(AppStorage.prefProfile);
    if (rawProfile != null) {
      _profile = UserProfile.fromJson(jsonDecode(rawProfile) as Map<String, dynamic>);
    }

    for (final key in AppStorage.savedBox.keys) {
      final value = AppStorage.savedBox.get(key);
      if (value is Map) _savedRecipeIds.add(key as String);
    }
    _savedRecipeIds.sort((a, b) {
      final aAt = DateTime.tryParse((AppStorage.savedBox.get(a) as Map)['saved_at'] as String? ?? '') ?? DateTime(0);
      final bAt = DateTime.tryParse((AppStorage.savedBox.get(b) as Map)['saved_at'] as String? ?? '') ?? DateTime(0);
      return bAt.compareTo(aAt);
    });

    for (final key in AppStorage.historyBox.keys) {
      final value = AppStorage.historyBox.get(key);
      if (value is List) {
        for (final item in value) {
          if (item is Map) _history.add(HistoryEntry.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    _history.sort((a, b) => b.cookedAt.compareTo(a.cookedAt));

    for (final key in AppStorage.mealPlanBox.keys) {
      final value = AppStorage.mealPlanBox.get(key);
      if (value is Map) {
        _mealPlan[key as String] =
            value.map((k, v) => MapEntry(k as String, v as String));
      }
    }

    for (final key in AppStorage.shoppingBox.keys) {
      final value = AppStorage.shoppingBox.get(key);
      if (value is Map) {
        final item = ShoppingItem.fromJson(value.cast<String, dynamic>());
        _shopping[item.ingredientId] = item;
      }
    }

    for (final key in AppStorage.shoppingLogBox.keys) {
      final value = AppStorage.shoppingLogBox.get(key);
      if (value is Map) {
        _shoppingLog.add(ShoppingLogEntry.fromJson(value.cast<String, dynamic>()));
      }
    }
    _shoppingLog.sort((a, b) => b.addedAt.compareTo(a.addedAt));

    for (final key in AppStorage.contentRequestsBox.keys) {
      final value = AppStorage.contentRequestsBox.get(key);
      if (value is Map && value['query'] is String) {
        _contentRequests.add(value['query'] as String);
      }
    }

    notifyListeners();
  }

  // ── profile ───────────────────────────────────────────────────────────

  Future<void> updateProfile(UserProfile profile) async {
    _profile = profile;
    await AppStorage.prefs.setString(AppStorage.prefProfile, jsonEncode(profile.toJson()));
    notifyListeners();
  }

  Future<void> setLang(String lang) => updateProfile(_profile.copyWith(lang: lang));

  Future<void> completeOnboarding() =>
      updateProfile(_profile.copyWith(onboardingComplete: true));

  // ── cookbook (saved variants) ─────────────────────────────────────────

  Future<void> toggleSaved(String recipeId) async {
    if (isSaved(recipeId)) {
      _savedRecipeIds.remove(recipeId);
      await AppStorage.savedBox.delete(recipeId);
    } else {
      _savedRecipeIds.insert(0, recipeId);
      await AppStorage.savedBox.put(recipeId, {
        'recipe_id': recipeId,
        'saved_at': DateTime.now().toIso8601String(),
      });
    }
    notifyListeners();
  }

  // ── history ───────────────────────────────────────────────────────────

  Future<void> addToHistory(String recipeId, {DateTime? at}) async {
    final entry = HistoryEntry(recipeId: recipeId, cookedAt: at ?? DateTime.now());
    _history.insert(0, entry);
    _history.sort((a, b) => b.cookedAt.compareTo(a.cookedAt));
    final key = recipeId;
    final existing = AppStorage.historyBox.get(key);
    final list = existing is List ? List<Map<String, dynamic>>.from(existing) : <Map<String, dynamic>>[];
    list.add(entry.toJson());
    await AppStorage.historyBox.put(key, list);
    notifyListeners();
  }

  // ── meal plan ─────────────────────────────────────────────────────────

  Future<void> setMealSlot(String weekId, String slot, String? recipeId) async {
    final week = _mealPlan.putIfAbsent(weekId, () => {});
    if (recipeId == null) {
      week.remove(slot);
    } else {
      week[slot] = recipeId;
    }
    await AppStorage.mealPlanBox.put(weekId, Map<String, String>.from(week));
    notifyListeners();
  }

  Future<void> moveMealSlot(String fromWeek, String fromSlot, String toWeek, String toSlot) async {
    final recipeId = recipeIdAt(fromWeek, fromSlot);
    if (recipeId == null) return;
    await setMealSlot(fromWeek, fromSlot, null);
    await setMealSlot(toWeek, toSlot, recipeId);
  }

  List<Recipe> weekRecipes(String weekId) {
    final ids = _mealPlan[weekId]?.values.toSet() ?? {};
    final recipes = <Recipe>[];
    for (final id in ids) {
      final r = _corpus?.loadedRecipe(id);
      if (r != null) recipes.add(r);
    }
    return recipes;
  }

  /// One-tap export: aggregate the whole week into the market list.
  Future<int> exportWeekToShopping(String weekId, {int Function(Recipe r)? servingsOf}) async {
    final ids = _mealPlan[weekId]?.values.toSet() ?? {};
    var added = 0;
    for (final id in ids) {
      final recipe = _corpus?.loadedRecipe(id) ?? await _corpus?.loadRecipe(id);
      if (recipe == null) continue;
      final servings = servingsOf?.call(recipe) ?? recipe.servings;
      added += await addRecipeToShopping(recipe, servings: servings);
    }
    return added;
  }

  // ── shopping ──────────────────────────────────────────────────────────

  /// Add one recipe's ingredients to the market list, unit-aware aggregated
  /// with what's already there. Returns how many lines were touched.
  Future<int> addRecipeToShopping(Recipe recipe, {int? servings, DateTime? at}) async {
    final now = at ?? DateTime.now();
    final lines = _aggregator.linesFromRecipe(recipe, servings ?? recipe.servings);
    var touched = 0;
    for (final item in _aggregator.aggregate(lines, addedAt: now)) {
      touched += 1;
      final existing = _shopping[item.ingredientId];
      if (existing == null) {
        _shopping[item.ingredientId] = item;
      } else {
        final merged = _aggregator.aggregate([
          (
            ingredientId: existing.ingredientId,
            amount: existing.amount,
            unit: existing.unit,
            recipeId: null,
          ),
          (ingredientId: item.ingredientId, amount: item.amount, unit: item.unit, recipeId: item.sourceRecipeIds.isNotEmpty ? item.sourceRecipeIds.first : null),
        ], addedAt: existing.addedAt);
        final m = merged.first;
        _shopping[item.ingredientId] = existing.copyWith(
          amount: m.amount,
          unit: m.unit,
          sourceRecipeIds: {
            ...existing.sourceRecipeIds,
            ...item.sourceRecipeIds,
          }.toList(),
        );
      }
      _shoppingLog.add(ShoppingLogEntry(
        ingredientId: item.ingredientId,
        amount: item.amount,
        unit: item.unit,
        recipeId: recipe.id,
        addedAt: now,
      ));
      await AppStorage.shoppingBox.put(
          item.ingredientId, _shopping[item.ingredientId]!.toJson());
      await AppStorage.shoppingLogBox.add(_shoppingLog.last.toJson());
    }
    notifyListeners();
    return touched;
  }

  Future<void> toggleShoppingItem(String ingredientId, bool checked) async {
    final item = _shopping[ingredientId];
    if (item == null) return;
    _shopping[ingredientId] = item.copyWith(checked: checked);
    await AppStorage.shoppingBox.put(ingredientId, _shopping[ingredientId]!.toJson());
    notifyListeners();
  }

  Future<void> clearCheckedShopping() async {
    final checkedIds = _shopping.values.where((i) => i.checked).map((i) => i.ingredientId).toList();
    for (final id in checkedIds) {
      _shopping.remove(id);
      await AppStorage.shoppingBox.delete(id);
    }
    notifyListeners();
  }

  Future<void> clearShopping() async {
    _shopping.clear();
    await AppStorage.shoppingBox.clear();
    notifyListeners();
  }

  /// Restore from a parsed backup payload. [replace] clears local data
  /// first; otherwise the backup is merged in (backup wins on meal-slot
  /// conflicts, saved/history/shopping are unioned). Never touches the
  /// bundled corpus.
  Future<void> restoreFromBackup(Map<String, dynamic> data, {required bool replace}) async {
    final profileJson = data['profile'];
    if (profileJson is Map<String, dynamic>) {
      final imported = UserProfile.fromJson(profileJson);
      // Never trap the user in onboarding because of an old backup.
      _profile = imported.copyWith(
        onboardingComplete: imported.onboardingComplete || _profile.onboardingComplete,
      );
      await AppStorage.prefs.setString(AppStorage.prefProfile, jsonEncode(_profile.toJson()));
    }

    if (replace) {
      await AppStorage.savedBox.clear();
      await AppStorage.historyBox.clear();
      await AppStorage.mealPlanBox.clear();
      await AppStorage.shoppingBox.clear();
      await AppStorage.shoppingLogBox.clear();
      await AppStorage.contentRequestsBox.clear();
      _savedRecipeIds.clear();
      _history.clear();
      _mealPlan.clear();
      _shopping.clear();
      _shoppingLog.clear();
      _contentRequests.clear();
    }

    // saved (list of recipe ids, newest first)
    final saved = (data['saved'] as List? ?? const []).cast<String>();
    for (final id in replace ? saved.reversed : saved) {
      if (_savedRecipeIds.contains(id)) continue;
      if (replace) {
        _savedRecipeIds.insert(0, id);
      } else {
        _savedRecipeIds.add(id);
      }
      await AppStorage.savedBox.put(id, {
        'recipe_id': id,
        'saved_at': DateTime.now().toIso8601String(),
      });
    }

    // meal plan
    final mealPlan = data['meal_plan'];
    if (mealPlan is Map) {
      for (final entry in mealPlan.entries) {
        if (entry.value is! Map) continue;
        final weekId = entry.key as String;
        final slots = (entry.value as Map).map((k, v) => MapEntry(k as String, v as String));
        final target = _mealPlan.putIfAbsent(weekId, () => {});
        target.addAll(slots); // backup wins on conflict
        await AppStorage.mealPlanBox.put(weekId, Map<String, String>.from(target));
      }
    }

    // history
    final history = data['history'];
    if (history is List) {
      for (final item in history) {
        if (item is! Map) continue;
        final entry = HistoryEntry.fromJson(item.cast<String, dynamic>());
        final key = entry.recipeId;
        final existing = AppStorage.historyBox.get(key);
        final list =
            existing is List ? List<Map<String, dynamic>>.from(existing) : <Map<String, dynamic>>[];
        final json = entry.toJson();
        if (!list.any((m) => m['cooked_at'] == json['cooked_at'])) {
          list.add(json);
          await AppStorage.historyBox.put(key, list);
        }
        if (!_history.any((h) => h.recipeId == entry.recipeId && h.cookedAt == entry.cookedAt)) {
          _history.add(entry);
        }
      }
      _history.sort((a, b) => b.cookedAt.compareTo(a.cookedAt));
    }

    // shopping
    final shopping = data['shopping'];
    if (shopping is Map) {
      for (final entry in shopping.entries) {
        if (entry.value is! Map) continue;
        final item = ShoppingItem.fromJson((entry.value as Map).cast<String, dynamic>());
        final existing = _shopping[item.ingredientId];
        if (existing == null) {
          _shopping[item.ingredientId] = item;
        } else {
          final merged = _aggregator.aggregate([
            (
              ingredientId: existing.ingredientId,
              amount: existing.amount,
              unit: existing.unit,
              recipeId: null,
            ),
            (
              ingredientId: item.ingredientId,
              amount: item.amount,
              unit: item.unit,
              recipeId: null,
            ),
          ], addedAt: existing.addedAt);
          _shopping[item.ingredientId] = existing.copyWith(
            amount: merged.first.amount,
            unit: merged.first.unit,
            sourceRecipeIds: {...existing.sourceRecipeIds, ...item.sourceRecipeIds}.toList(),
          );
        }
        await AppStorage.shoppingBox.put(item.ingredientId, _shopping[item.ingredientId]!.toJson());
      }
    }

    // shopping log
    final shoppingLog = data['shopping_log'];
    if (shoppingLog is Map && shoppingLog['entries'] is List) {
      for (final item in (shoppingLog['entries'] as List)) {
        if (item is! Map) continue;
        final entry = ShoppingLogEntry.fromJson(item.cast<String, dynamic>());
        _shoppingLog.add(entry);
        await AppStorage.shoppingLogBox.add(entry.toJson());
      }
      _shoppingLog.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    }

    // content requests
    final requests = (data['content_requests'] as List? ?? const []).cast<String>();
    for (final query in requests) {
      final trimmed = query.trim();
      if (trimmed.isEmpty || _contentRequests.contains(trimmed)) continue;
      _contentRequests.add(trimmed);
      await AppStorage.contentRequestsBox.add({
        'query': trimmed,
        'at': DateTime.now().toIso8601String(),
      });
    }

    notifyListeners();
  }

  // ── content requests ──────────────────────────────────────────────────

  Future<void> logContentRequest(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || _contentRequests.contains(trimmed)) return;
    _contentRequests.add(trimmed);
    await AppStorage.contentRequestsBox.add({'query': trimmed, 'at': DateTime.now().toIso8601String()});
    notifyListeners();
  }

  // ── helpers ───────────────────────────────────────────────────────────

  /// Shopping items grouped by aisle, aisles in a stable editorial order.
  Map<String, List<ShoppingItem>> shoppingByAisle() {
    const order = ['produce', 'meat', 'dairy', 'pantry', 'spices', 'bakery', 'frozen'];
    final grouped = <String, List<ShoppingItem>>{};
    for (final item in _shopping.values) {
      final aisle = _corpus?.ingredients.aisleOf(item.ingredientId) ?? 'pantry';
      grouped.putIfAbsent(aisle, () => []).add(item);
    }
    final sorted = <String, List<ShoppingItem>>{};
    for (final aisle in order) {
      if (grouped.containsKey(aisle)) sorted[aisle] = grouped[aisle]!;
    }
    for (final entry in grouped.entries) {
      if (!sorted.containsKey(entry.key)) sorted[entry.key] = entry.value;
    }
    return sorted;
  }
}
