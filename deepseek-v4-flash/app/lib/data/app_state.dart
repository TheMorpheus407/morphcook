import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/backup_service.dart';

/// Single source of truth for user state. Hive for bulky lists, shared
/// preferences for the small profile. One ChangeNotifier keeps the UI simple.
class AppState extends ChangeNotifier {
  AppState._();

  static AppState? _instance;

  static AppState get instance => _instance ??= AppState._();

  /// Test hook: drops the cached singleton so each test starts fresh.
  @visibleForTesting
  static void debugReset() {
    _instance = null;
  }

  // --- persistence ---
  late SharedPreferences _prefs;
  late Box _cookbookBox;
  late Box _historyBox;
  late Box _mealPlanBox;
  late Box _shoppingBox;
  late Box _checkedBox;
  late Box _eventsBox;

  // --- profile ---
  UserProfile profile = UserProfile();

  /// Boxes opened + initial state loaded. Idempotent.
  Future<void> init({
    required SharedPreferences prefs,
    required Box cookbookBox,
    required Box historyBox,
    required Box mealPlanBox,
    required Box shoppingBox,
    required Box checkedBox,
    required Box eventsBox,
  }) async {
    _prefs = prefs;
    _cookbookBox = cookbookBox;
    _historyBox = historyBox;
    _mealPlanBox = mealPlanBox;
    _shoppingBox = shoppingBox;
    _checkedBox = checkedBox;
    _eventsBox = eventsBox;
    _loadProfile();
  }

  /// Convenience: Hive boxes opened from a directory (tests pass a temp dir).
  static Future<void> openHive(String dir) async {
    Hive.init(dir);
    await Hive.openBox('cookbook');
    await Hive.openBox('history');
    await Hive.openBox('meal_plan');
    await Hive.openBox('shopping');
    await Hive.openBox('shopping_checked');
    await Hive.openBox('events');
  }

  void _loadProfile() {
    final raw = _prefs.getString('morphcook_profile');
    if (raw != null) {
      try {
        profile = UserProfile.fromJson(
            (jsonDecode(raw) as Map).cast<String, dynamic>());
      } catch (_) {
        profile = UserProfile();
      }
    }
  }

  // --- profile ---

  void updateProfile(UserProfile p) {
    profile = p;
    _prefs.setString('morphcook_profile', jsonEncode(p.toJson()));
    notifyListeners();
  }

  void patchProfile(void Function(UserProfile p) fn) {
    final p = UserProfile(
      name: profile.name,
      lang: profile.lang,
      avoidFlags: Set.of(profile.avoidFlags),
      avoidIngredients: Set.of(profile.avoidIngredients),
      requiredAttributes: Set.of(profile.requiredAttributes),
      maxTimeMinutes: profile.maxTimeMinutes,
      calorieTarget: profile.calorieTarget,
      preferredEffort: profile.preferredEffort,
      showVariantTags: profile.showVariantTags,
      reduceMotion: profile.reduceMotion,
      visualAlertEnabled: profile.visualAlertEnabled,
      quickNextTapEnabled: profile.quickNextTapEnabled,
      completedOnboarding: profile.completedOnboarding,
    );
    fn(p);
    updateProfile(p);
  }

  String get lang => profile.lang;
  bool get reduceMotionEnabled =>
      profile.reduceMotion ??
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  // --- cookbook ---

  List<SavedEntry> get savedEntries {
    final out = <SavedEntry>[];
    for (final key in _cookbookBox.keys) {
      final at = _cookbookBox.get(key) as String?;
      if (at == null) continue;
      out.add(SavedEntry(recipeId: key as String, savedAt: DateTime.parse(at)));
    }
    out.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return out;
  }

  bool isSaved(String recipeId) => _cookbookBox.containsKey(recipeId);

  void toggleSaved(String recipeId) {
    if (isSaved(recipeId)) {
      _cookbookBox.delete(recipeId);
    } else {
      _cookbookBox.put(recipeId, DateTime.now().toIso8601String());
    }
    notifyListeners();
  }

  // --- history ---

  List<HistoryEntry> get history {
    final out = <HistoryEntry>[];
    for (final key in _historyBox.keys) {
      final v = _historyBox.get(key) as Map?;
      if (v == null) continue;
      out.add(HistoryEntry(
        recipeId: v['recipe_id'] as String,
        at: DateTime.parse(v['at'] as String),
      ));
    }
    out.sort((a, b) => b.at.compareTo(a.at));
    return out;
  }

  void recordCook(String recipeId, {DateTime? at}) {
    final key = DateTime.now().microsecondsSinceEpoch.toString();
    _historyBox.put(key, {
      'recipe_id': recipeId,
      'at': (at ?? DateTime.now()).toIso8601String(),
    });
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _historyBox.clear();
    notifyListeners();
  }

  /// last cooked time per recipe (most recent entry wins).
  Map<String, DateTime> get lastCookedByRecipe {
    final out = <String, DateTime>{};
    for (final e in history) {
      final prev = out[e.recipeId];
      if (prev == null || e.at.isAfter(prev)) out[e.recipeId] = e.at;
    }
    return out;
  }

  int cookedCount(String recipeId) =>
      history.where((e) => e.recipeId == recipeId).length;

  /// Distinct recipes ever cooked.
  Set<String> get cookedRecipeIds =>
      history.map((e) => e.recipeId).toSet();

  // --- meal plan ---

  Map<String, Map<String, String>> get mealPlan {
    final out = <String, Map<String, String>>{};
    for (final k in _mealPlanBox.keys) {
      final v = _mealPlanBox.get(k) as Map;
      out[k as String] = v.map((kk, vv) => MapEntry(kk as String, vv as String));
    }
    return out;
  }

  Map<String, String> week(String weekKey) => mealPlan[weekKey] ?? {};

  void setSlot(String weekKey, String slot, String? recipeId) {
    final week = Map<String, String>.of(mealPlan[weekKey] ?? {});
    if (recipeId == null) {
      week.remove(slot);
    } else {
      week[slot] = recipeId;
    }
    if (week.isEmpty) {
      _mealPlanBox.delete(weekKey);
    } else {
      _mealPlanBox.put(weekKey, week);
    }
    notifyListeners();
  }

  void clearWeek(String weekKey) {
    _mealPlanBox.delete(weekKey);
    notifyListeners();
  }

  // --- shopping ---

  List<ShoppingLine> get shoppingLines {
    final out = <ShoppingLine>[];
    for (final key in _shoppingBox.keys) {
      final v = _shoppingBox.get(key) as Map;
      out.add(ShoppingLine(
        recipeId: key as String,
        addedAt: DateTime.parse(v['added_at'] as String),
        servings: (v['servings'] as num?)?.toInt(),
      ));
    }
    out.sort((a, b) => a.addedAt.compareTo(b.addedAt));
    return out;
  }

  ShoppingLine? shoppingLineFor(String recipeId) {
    final v = _shoppingBox.get(recipeId);
    if (v == null) return null;
    final m = v as Map;
    return ShoppingLine(
      recipeId: recipeId,
      addedAt: DateTime.parse(m['added_at'] as String),
      servings: (m['servings'] as num?)?.toInt(),
    );
  }

  void addShoppingLine(String recipeId, {int? servings}) {
    _shoppingBox.put(recipeId, {
      'added_at': DateTime.now().toIso8601String(),
      'servings': servings,
    });
    _recordShoppingEvent(recipeId);
    notifyListeners();
  }

  void updateShoppingServings(String recipeId, int servings) {
    final existing = _shoppingBox.get(recipeId);
    if (existing == null) return;
    _shoppingBox.put(recipeId, {
      'added_at': (existing as Map)['added_at'],
      'servings': servings,
    });
    notifyListeners();
  }

  void removeShoppingLine(String recipeId) {
    _shoppingBox.delete(recipeId);
    _checkedBox.delete(recipeId);
    notifyListeners();
  }

  Set<String> get checkedShopping =>
      _checkedBox.keys.toSet().cast<String>();

  void toggleShoppingChecked(String recipeId) {
    if (_checkedBox.containsKey(recipeId)) {
      _checkedBox.delete(recipeId);
    } else {
      _checkedBox.put(recipeId, true);
    }
    notifyListeners();
  }

  void clearCheckedShopping() {
    for (final k in _checkedBox.keys.toList()) {
      _shoppingBox.delete(k);
    }
    _checkedBox.clear();
    notifyListeners();
  }

  // --- insights ---

  void _recordShoppingEvent(String recipeId) {
    final key = DateTime.now().microsecondsSinceEpoch.toString();
    _eventsBox.put(key, {
      'recipe_id': recipeId,
      'at': DateTime.now().toIso8601String(),
    });
  }

  List<Map<String, dynamic>> get shoppingEvents {
    final out = <Map<String, dynamic>>[];
    for (final k in _eventsBox.keys) {
      final v = _eventsBox.get(k);
      if (v is Map) out.add(v.cast<String, dynamic>());
    }
    out.sort((a, b) =>
        (b['at'] as String).compareTo(a['at'] as String));
    return out;
  }

  /// Distinct ingredient ids seen across shopping events, expanded per recipe.
  Set<String> uniqueIngredients(Recipe? Function(String recipeId) resolver) {
    final out = <String>{};
    for (final e in shoppingEvents) {
      final recipe = resolver(e['recipe_id'] as String);
      if (recipe != null) out.addAll(recipe.ingredientIds);
    }
    return out;
  }

  // --- content requests ---

  List<String> get contentRequests =>
      (_prefs.getStringList('morphcook_requests') ?? const []).toList();

  void addContentRequest(String request) {
    final l = contentRequests;
    if (l.contains(request)) return;
    _prefs.setStringList('morphcook_requests', [...l, request]);
    notifyListeners();
  }

  void removeContentRequest(String request) {
    _prefs.setStringList(
        'morphcook_requests', contentRequests.where((r) => r != request).toList());
    notifyListeners();
  }

  // --- backup ---

  BackupPayload exportPayload() => BackupPayload(
        profile: profile,
        saved: savedEntries,
        history: history,
        mealPlan: mealPlan,
        contentRequests: contentRequests,
        shoppingLines: shoppingLines,
      );

  /// Import a payload. When [merge] is false the current state is replaced
  /// (profile replaced, boxes cleared). When true, saved/history/shopping are
  /// unioned, meal plan only fills empty slots, requests are appended.
  Future<void> importPayload(BackupPayload payload, {bool merge = true}) async {
    if (merge) {
      final savedNow = savedEntries.map((e) => e.recipeId).toSet();
      for (final e in payload.saved) {
        if (!savedNow.contains(e.recipeId)) toggleSavedQuiet(e.recipeId, e.savedAt);
      }
      final histKeys = _historyBox.keys.toList();
      for (final e in payload.history) {
        final key = (e.at.microsecondsSinceEpoch).toString();
        if (histKeys.contains(key)) continue;
        _historyBox.put('m$key', {
          'recipe_id': e.recipeId,
          'at': e.at.toIso8601String(),
        });
      }
      final plan = mealPlan;
      for (final weekKey in payload.mealPlan.keys) {
        final slots = plan[weekKey] ?? {};
        final toAdd = <String, String>{};
        payload.mealPlan[weekKey]!.forEach((slot, rid) {
          if (!slots.containsKey(slot)) toAdd[slot] = rid;
        });
        if (toAdd.isNotEmpty) _mealPlanBox.put(weekKey, {...slots, ...toAdd});
      }
      final reqs = contentRequests.toSet();
      reqs.addAll(payload.contentRequests);
      _prefs.setStringList('morphcook_requests', reqs.toList());
      for (final l in payload.shoppingLines) {
        if (!_shoppingBox.containsKey(l.recipeId)) {
          _shoppingBox.put(l.recipeId, {
            'added_at': l.addedAt.toIso8601String(),
            'servings': l.servings,
          });
        }
      }
    } else {
      profile = payload.profile;
      _prefs.setString('morphcook_profile', jsonEncode(payload.profile.toJson()));
      await _cookbookBox.clear();
      for (final e in payload.saved) {
        _cookbookBox.put(e.recipeId, e.savedAt.toIso8601String());
      }
      await _historyBox.clear();
      for (final e in payload.history) {
        _historyBox.put(e.at.microsecondsSinceEpoch.toString(), {
          'recipe_id': e.recipeId,
          'at': e.at.toIso8601String(),
        });
      }
      await _mealPlanBox.clear();
      payload.mealPlan.forEach((k, v) => _mealPlanBox.put(k, v));
      _prefs.setStringList('morphcook_requests', payload.contentRequests);
      await _shoppingBox.clear();
      for (final l in payload.shoppingLines) {
        _shoppingBox.put(l.recipeId, {
          'added_at': l.addedAt.toIso8601String(),
          'servings': l.servings,
        });
      }
    }
    notifyListeners();
  }

  void toggleSavedQuiet(String recipeId, DateTime savedAt) {
    _cookbookBox.put(recipeId, savedAt.toIso8601String());
  }
}
