/// Central app state: profile, saved cookbook, cooking history, meal plan,
/// shopping list + log, content requests, cook-mode session.
/// Persistence: plain JSON files under the app documents dir (offline only).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/matching.dart';

typedef ChangeCallback = void Function();

class SavedEntry {
  final String recipeId;
  final DateTime savedAt;
  const SavedEntry(this.recipeId, this.savedAt);

  Map<String, dynamic> toJson() =>
      {'recipe_id': recipeId, 'saved_at': savedAt.toIso8601String()};

  factory SavedEntry.fromJson(Map<String, dynamic> m) =>
      SavedEntry(m['recipe_id'] as String, DateTime.parse(m['saved_at'] as String));
}

class HistoryEntry {
  final String recipeId;
  final DateTime cookedAt;
  final int servings;
  const HistoryEntry(this.recipeId, this.cookedAt, this.servings);

  Map<String, dynamic> toJson() =>
      {'recipe_id': recipeId, 'cooked_at': cookedAt.toIso8601String(), 'servings': servings};

  factory HistoryEntry.fromJson(Map<String, dynamic> m) =>
      HistoryEntry(m['recipe_id'] as String, DateTime.parse(m['cooked_at'] as String),
          (m['servings'] as num?)?.toInt() ?? 2);
}

class ShoppingLogEntry {
  final String ingredientId;
  final String recipeId;
  final DateTime at;
  const ShoppingLogEntry(this.ingredientId, this.recipeId, this.at);

  Map<String, dynamic> toJson() =>
      {'i': ingredientId, 'r': recipeId, 'at': at.toIso8601String()};

  factory ShoppingLogEntry.fromJson(Map<String, dynamic> m) =>
      ShoppingLogEntry(m['i'] as String, m['r'] as String, DateTime.parse(m['at'] as String));
}

class CookSession {
  final String recipeId;
  int stepIndex;
  int servings;
  bool paused;
  int stepStartedAtEpochMs;
  CookSession({
    required this.recipeId,
    this.stepIndex = 0,
    this.servings = 2,
    this.paused = false,
    this.stepStartedAtEpochMs = 0,
  });

  Map<String, dynamic> toJson() => {
        'recipe_id': recipeId,
        'step_index': stepIndex,
        'servings': servings,
        'paused': paused,
        'step_started_at': stepStartedAtEpochMs,
      };

  factory CookSession.fromJson(Map<String, dynamic> m) => CookSession(
        recipeId: m['recipe_id'] as String,
        stepIndex: (m['step_index'] as num?)?.toInt() ?? 0,
        servings: (m['servings'] as num?)?.toInt() ?? 2,
        paused: m['paused'] as bool? ?? false,
        stepStartedAtEpochMs: (m['step_started_at'] as num?)?.toInt() ?? 0,
      );
}

class AppStore extends ChangeNotifier {
  AppStore({Directory? dir, bool readOnly = false})
      : dir = dir ?? Directory.systemTemp,
        _readOnly = readOnly;

  final Directory dir;
  final bool _readOnly;

  Profile profile = Profile();
  final List<SavedEntry> saved = [];
  final List<HistoryEntry> history = [];
  final Map<String, Map<String, String>> mealPlan = {}; // weekKey -> "mon.dinner" -> recipeId
  final List<String> shoppingRecipeIds = [];
  final List<ShoppingLogEntry> shoppingLog = [];
  final List<String> contentRequests = []; // zero-result search queries
  CookSession? cookSession;

  bool onboarded = false;
  bool _loaded = false;

  void setOnboarded(bool v) {
    if (v == onboarded) return;
    onboarded = v;
    _save();
    notifyListeners();
  }

  void updateProfile(Profile p) {
    profile = p;
    _save();
    _notify();
  }

  void _notify() => notifyListeners();

  // ---- cookbook ----------------------------------------------------------
  bool isSaved(String recipeId) => saved.any((s) => s.recipeId == recipeId);

  void saveRecipe(String recipeId, {DateTime? at}) {
    if (isSaved(recipeId)) return;
    saved.insert(0, SavedEntry(recipeId, at ?? DateTime.now()));
    _save();
    _notify();
  }

  void unsaveRecipe(String recipeId) {
    saved.removeWhere((s) => s.recipeId == recipeId);
    _save();
    _notify();
  }

  // ---- history -------------------------------------------------------------
  DateTime? lastCooked(String recipeId) {
    DateTime? best;
    for (final h in history) {
      if (h.recipeId == recipeId && (best == null || h.cookedAt.isAfter(best))) {
        best = h.cookedAt;
      }
    }
    return best;
  }

  int cookCount(String recipeId) =>
      history.where((h) => h.recipeId == recipeId).length;

  void logCooked(String recipeId, {DateTime? at, int servings = 2}) {
    history.insert(0, HistoryEntry(recipeId, at ?? DateTime.now(), servings));
    _save();
    _notify();
  }

  // ---- meal plan -------------------------------------------------------------
  static String weekKeyOf(DateTime d) {
    // ISO-style year-week, Monday-based.
    final monday = _mondayOf(d);
    return '${monday.year}-W${_isoWeek(monday)}';
  }

  static DateTime _mondayOf(DateTime d) {
    final shift = (d.weekday - DateTime.monday + 7) % 7;
    final m = d.subtract(Duration(days: shift));
    return DateTime(m.year, m.month, m.day);
  }

  static int _isoWeek(DateTime d) {
    final jan1 = DateTime(d.year, 1, 1);
    final shift = (jan1.weekday - DateTime.monday + 7) % 7;
    final week1Monday = jan1.subtract(Duration(days: shift));
    final weeks = d.difference(week1Monday).inDays ~/ 7 + 1;
    return weeks.clamp(1, 53);
  }

  void setPlanSlot(DateTime day, String meal, String? recipeId) {
    final wk = weekKeyOf(day);
    final key = '${_dayName(day.weekday)}.$meal';
    final map = mealPlan.putIfAbsent(wk, () => {});
    if (recipeId == null) {
      map.remove(key);
    } else {
      map[key] = recipeId;
    }
    _save();
    _notify();
  }

  String? planSlot(DateTime day, String meal) =>
      mealPlan[weekKeyOf(day)]?['${_dayName(day.weekday)}.$meal'];

  static String _dayName(int weekday) =>
      ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'][weekday - 1];

  List<String> planWeekRecipes(DateTime anyDayInWeek) {
    final wk = weekKeyOf(anyDayInWeek);
    final map = mealPlan[wk] ?? const {};
    return map.values.toSet().toList();
  }

  // ---- shopping list ---------------------------------------------------------
  bool isOnList(String recipeId) => shoppingRecipeIds.contains(recipeId);

  void addToList(String recipeId, {List<String>? ingredientIds, DateTime? at}) {
    if (isOnList(recipeId)) return;
    shoppingRecipeIds.add(recipeId);
    final now = at ?? DateTime.now();
    for (final i in ingredientIds ?? const <String>[]) {
      shoppingLog.add(ShoppingLogEntry(i, recipeId, now));
    }
    _save();
    _notify();
  }

  void removeFromList(String recipeId) {
    shoppingRecipeIds.remove(recipeId);
    shoppingLog.removeWhere((l) => l.recipeId == recipeId);
    _save();
    _notify();
  }

  void clearList() {
    shoppingRecipeIds.clear();
    shoppingLog.clear();
    _save();
    _notify();
  }

  // ---- content requests ------------------------------------------------------
  void logContentRequest(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return;
    contentRequests.add(q);
    _save();
    _notify();
  }

  // ---- cook session -----------------------------------------------------------
  void setSession(CookSession? s) {
    cookSession = s;
    _save();
    _notify();
  }

  // ---- persistence ------------------------------------------------------------
  File get _stateFile => File('${dir.path}/morphcook-state.json');

  Future<void> load() async {
    if (_loaded) return;
    if (await _stateFile.exists()) {
      try {
        final m = jsonDecode(await _stateFile.readAsString()) as Map<String, dynamic>;
        _applySnapshot(
            (m as Map).map((k, v) => MapEntry(k.toString(), v)), preserveLists: true);
      } catch (_) {
        // corrupted state: start clean rather than crash
      }
    }
    _loaded = true;
  }

  void _save() {
    if (!_loaded || _readOnly) return;
    final m = backupSnapshot();
    _stateFile
        .writeAsString(const JsonEncoder.withIndent('  ').convert(m))
        .ignore();
  }

  // ---- backup snapshot ---------------------------------------------------------
  Map<String, dynamic> backupSnapshot() => {
        'schema_version': 1,
        'exported_at': DateTime.now().toIso8601String(),
        'profile': profile.toJson(),
        'saved': saved.map((e) => e.recipeId).toList(),
        'meal_plan': mealPlan,
        'history': history.map((e) => e.toJson()).toList(),
        'shopping_list': shoppingRecipeIds,
        'shopping_log': shoppingLog.map((e) => e.toJson()).toList(),
        'content_requests': contentRequests,
      };

  /// Merge or replace local state from a backup snapshot.
  void restoreFromSnapshot(Map<String, dynamic> m, {required bool replace}) {
    if (replace) {
      saved.clear();
      history.clear();
      mealPlan.clear();
      shoppingRecipeIds.clear();
      shoppingLog.clear();
      contentRequests.clear();
    }
    _applySnapshot(m, preserveLists: !replace);
    _save();
  }

  void _applySnapshot(Map m, {required bool preserveLists}) {
    if (m['profile'] is Map) {
      final p = (m['profile'] as Map);
      profile = Profile.fromJson(p.map((k, v) => MapEntry(k.toString(), v)));
    }
    for (final id in (m['saved'] as List? ?? const []).cast<String>()) {
      if (!isSaved(id)) {
        saved.insert(0, SavedEntry(id, DateTime.now()));
      }
    }
    for (final e in (m['history'] as List? ?? const []).cast<Map>()) {
      history.insert(0, HistoryEntry.fromJson(e.map((k, v) => MapEntry(k.toString(), v))));
    }
    for (final e in (m['meal_plan'] as Map? ?? const {}).entries) {
      final wk = e.key.toString();
      final slots = (e.value as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
      final cur = mealPlan.putIfAbsent(wk, () => {});
      cur.addAll(slots);
    }
    for (final id in (m['shopping_list'] as List? ?? const []).cast<String>()) {
      if (!isOnList(id)) shoppingRecipeIds.add(id);
    }
    for (final e in (m['shopping_log'] as List? ?? const []).cast<Map>()) {
      shoppingLog.add(
          ShoppingLogEntry.fromJson(e.map((k, v) => MapEntry(k.toString(), v))));
    }
    for (final q in (m['content_requests'] as List? ?? const []).cast<String>()) {
      if (!contentRequests.contains(q)) contentRequests.add(q);
    }
  }
}
