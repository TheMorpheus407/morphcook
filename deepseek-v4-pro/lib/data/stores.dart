import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';
import '../models/shopping.dart';

/// Single source of local state: profile + small flags in
/// shared_preferences; saved / history / meal-plan / shopping /
/// content-requests collections in Hive.
class AppStore extends ChangeNotifier {
  AppStore._(this._prefs, this._saved, this._history, this._mealPlan,
      this._shopping, this._contentRequests);

  final SharedPreferences _prefs;
  final Box<String> _saved;
  final Box<String> _history;
  final Box<String> _mealPlan;
  final Box<String> _shopping;
  final Box<String> _contentRequests;

  // ------------------------------------------------------------ profile

  Profile _profile = const Profile();
  Profile get profile => _profile;

  void updateProfile(Profile p) {
    _profile = p;
    _prefs.setString('profile', p.encode());
    notifyListeners();
  }

  void setLang(String lang) {
    updateProfile(_profile.copyWith(lang: lang));
    _prefs.setString('lang', lang);
  }

  // -------------------------------------------------------------- saved

  List<String> get savedIds => List.unmodifiable(
      (jsonDecode(_saved.get('ids', defaultValue: '[]')!) as List)
          .cast<String>());

  Map<String, DateTime> get savedAt {
    final raw = _saved.get('at', defaultValue: '{}')!;
    return (jsonDecode(raw) as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, DateTime.parse(v as String)));
  }

  bool isSaved(String recipeId) => savedIds.contains(recipeId);

  void saveRecipe(String recipeId) {
    final ids = savedIds.toSet()..add(recipeId);
    _saved.put('ids', jsonEncode(ids.toList()));
    final at = savedAt..[recipeId] = DateTime.now();
    _saved.put(
        'at',
        jsonEncode(at.map(
            (k, v) => MapEntry(k, v.toIso8601String()))));
    notifyListeners();
  }

  void unsaveRecipe(String recipeId) {
    final ids = savedIds.toSet()..remove(recipeId);
    _saved.put('ids', jsonEncode(ids.toList()));
    final at = savedAt..remove(recipeId);
    _saved.put(
        'at',
        jsonEncode(at.map(
            (k, v) => MapEntry(k, v.toIso8601String()))));
    notifyListeners();
  }

  // ------------------------------------------------------------- history

  List<HistoryEntry> get history {
    final raw = _history.values.toList();
    final out = raw.map(HistoryEntry.decode).toList()
      ..sort((a, b) => b.cookedAt.compareTo(a.cookedAt));
    return List.unmodifiable(out);
  }

  Map<String, DateTime> get lastCookedAt {
    final out = <String, DateTime>{};
    for (final raw in _history.values) {
      final h = HistoryEntry.decode(raw);
      final prev = out[h.recipeId];
      if (prev == null || h.cookedAt.isAfter(prev)) {
        out[h.recipeId] = h.cookedAt;
      }
    }
    return out;
  }

  void recordCooked(String recipeId, {DateTime? at}) {
    final entry = HistoryEntry(recipeId: recipeId, cookedAt: at ?? DateTime.now());
    _history.add(entry.encode());
    notifyListeners();
  }

  // ------------------------------------------------------------ meal plan

  /// week id ("2026-W33") → slot ("mon.dinner") → recipe id
  Map<String, Map<String, String>> get mealPlan {
    final out = <String, Map<String, String>>{};
    for (final raw in _mealPlan.values) {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      out[json['week'] as String] =
          ((json['slots'] as Map<String, dynamic>?) ?? const <String, dynamic>{})
              .map((k, v) => MapEntry(k, v.toString()));
    }
    return out;
  }

  String? plannedRecipe(String weekId, String slot) =>
      mealPlan[weekId]?[slot];

  void assignSlot(String weekId, String slot, String recipeId) {
    final json = jsonDecode(_mealPlan.get(weekId, defaultValue: '{}')!) as Map<String, dynamic>;
    final slots = (json['slots'] as Map<String, dynamic>? ?? {});
    slots[slot] = recipeId;
    _mealPlan.put(weekId, jsonEncode({'week': weekId, 'slots': slots}));
    notifyListeners();
  }

  void clearSlot(String weekId, String slot) {
    final json = jsonDecode(_mealPlan.get(weekId, defaultValue: '{}')!) as Map<String, dynamic>;
    final slots = (json['slots'] as Map<String, dynamic>? ?? {})..remove(slot);
    _mealPlan.put(weekId, jsonEncode({'week': weekId, 'slots': slots}));
    notifyListeners();
  }

  // ------------------------------------------------------------- shopping

  List<ShoppingEntry> get shoppingEntries => List.unmodifiable(
      _shopping.values.map((e) => ShoppingEntry.decode(e)).toList());

  void addShoppingEntries(List<ShoppingEntry> entries) {
    for (final e in entries) {
      _shopping.add(e.encode());
    }
    notifyListeners();
  }

  void removeShoppingEntries(List<ShoppingEntry> entries) {
    final targets = entries.map((e) => e.encode()).toSet();
    final doomed = <dynamic>[];
    for (final key in _shopping.keys) {
      if (targets.contains(_shopping.get(key))) doomed.add(key);
    }
    _shopping.deleteAll(doomed);
    notifyListeners();
  }

  void toggleChecked(String ingredientId, bool checked) {
    for (final key in _shopping.keys) {
      final e = ShoppingEntry.decode(_shopping.get(key)!);
      if (e.ingredientId == ingredientId) {
        _shopping.put(
            key,
            ShoppingEntry(
              ingredientId: e.ingredientId,
              amount: e.amount,
              unit: e.unit,
              checked: checked,
              addedAt: e.addedAt,
            ).encode());
      }
    }
    notifyListeners();
  }

  void clearChecked() {
    final doomed = <dynamic>[];
    for (final key in _shopping.keys) {
      if (ShoppingEntry.decode(_shopping.get(key)!).checked) doomed.add(key);
    }
    _shopping.deleteAll(doomed);
    notifyListeners();
  }

  Future<void> clearAllShopping() async {
    await _shopping.clear();
    notifyListeners();
  }

  // --------------------------------------------------- content requests

  List<String> get contentRequests =>
      List.unmodifiable(_contentRequests.values.toList());

  void addContentRequest(String query) {
    if (query.trim().isEmpty) return;
    if (_contentRequests.values.contains(query.trim())) return;
    _contentRequests.add(query.trim());
  }

  // ----------------------------------------------------- cook progress

  /// Persists cook-mode progress (step, scale, timer) so interruptions
  /// never lose your place.
  void saveCookProgress(String recipeId, Map<String, dynamic> progress) {
    _prefs.setString('cook_progress.$recipeId', jsonEncode(progress));
  }

  Map<String, dynamic>? readCookProgress(String recipeId) {
    final raw = _prefs.getString('cook_progress.$recipeId');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  void clearCookProgress(String recipeId) {
    _prefs.remove('cook_progress.$recipeId');
  }

  // ---------------------------------------------------------------- init

  static Future<AppStore> init({String boxPrefix = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await Hive.openBox<String>('${boxPrefix}saved');
    final history = await Hive.openBox<String>('${boxPrefix}history');
    final mealPlan = await Hive.openBox<String>('${boxPrefix}meal_plan');
    final shopping = await Hive.openBox<String>('${boxPrefix}shopping');
    final contentRequests = await Hive.openBox<String>('${boxPrefix}content_requests');
    final store = AppStore._(
        prefs, saved, history, mealPlan, shopping, contentRequests);
    store._profile = Profile.decode(prefs.getString('profile'));
    return store;
  }

  // ------------------------------------------------------------ backup IO

  /// Replaces mutable state from an imported backup (replace mode).
  Future<void> applyBackupReplace(Map<String, dynamic> backup) async {
    updateProfile(Profile.fromJson(backup['profile'] as Map<String, dynamic>));
    final savedList = (backup['saved'] as List<dynamic>? ?? const []).cast<String>();
    final at = savedAt;
    for (final id in savedList) {
      at[id] ??= DateTime.now();
    }
    _saved.put('ids', jsonEncode(savedList));
    _saved.put('at', jsonEncode(at.map((k, v) => MapEntry(k, v.toIso8601String()))));

    await _history.clear();
    for (final h in (backup['history'] as List<dynamic>? ?? const [])) {
      _history.add(jsonEncode(h));
    }

    await _mealPlan.clear();
    final plan = backup['meal_plan'] as Map<String, dynamic>? ?? const {};
    for (final week in plan.keys) {
      final slots = (plan[week] as Map<String, dynamic>? ?? const {}).map(
          (k, v) => MapEntry(k, v.toString()));
      _mealPlan.put(week, jsonEncode({'week': week, 'slots': slots}));
    }

    final requests = (backup['content_requests'] as List<dynamic>? ?? const []).cast<String>();
    await _contentRequests.clear();
    for (final q in requests) {
      _contentRequests.add(q);
    }
    notifyListeners();
  }

  /// Merge mode: union saved, newest-wins meal plan, dedup history.
  Future<void> applyBackupMerge(Map<String, dynamic> backup) async {
    final incomingSaved = (backup['saved'] as List<dynamic>? ?? const []).cast<String>();
    final ids = savedIds.toSet()..addAll(incomingSaved);
    _saved.put('ids', jsonEncode(ids.toList()));
    final at = savedAt;
    for (final id in incomingSaved) {
      at[id] ??= DateTime.now();
    }
    _saved.put('at', jsonEncode(at.map((k, v) => MapEntry(k, v.toIso8601String()))));

    final plan = backup['meal_plan'] as Map<String, dynamic>? ?? const {};
    for (final week in plan.keys) {
      final incoming = (plan[week] as Map<String, dynamic>? ?? const {})
          .map((k, v) => MapEntry(k, v.toString()));
      final existing = mealPlan[week] ?? {};
      _mealPlan.put(
          week, jsonEncode({'week': week, 'slots': {...existing, ...incoming}}));
    }

    for (final h in (backup['history'] as List<dynamic>? ?? const [])) {
      _history.add(jsonEncode(h));
    }

    final requests = (backup['content_requests'] as List<dynamic>? ?? const []).cast<String>();
    for (final q in requests) {
      addContentRequest(q);
    }
    notifyListeners();
  }

  Map<String, dynamic> buildBackupPayload() => {
        'schema_version': 1,
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'profile': _profile.toJson(),
        'saved': savedIds,
        'meal_plan': mealPlan,
        'history': [
          for (final e in _history.values) jsonDecode(e),
        ],
        'content_requests': contentRequests,
      };
}
