/// Local persistence: profile + flags in SharedPreferences, collections in
/// Hive boxes. Pure wrapper so widgets never touch storage directly.
library;

import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/backup.dart';
import '../logic/mealplan.dart';
import '../logic/profile.dart';

class CookHistoryEntry {
  final String recipeId;
  final DateTime cookedAt;
  const CookHistoryEntry(this.recipeId, this.cookedAt);

  Map<String, dynamic> toJson() =>
      {'recipe_id': recipeId, 'cooked_at': cookedAt.toIso8601String()};

  static CookHistoryEntry fromJson(Map<String, dynamic> json) =>
      CookHistoryEntry(
        json['recipe_id'] as String,
        DateTime.parse(json['cooked_at'] as String),
      );
}

/// One "add" event: when a shopping list was created, what went into it.
class ShoppingListEvent {
  final DateTime addedAt;
  final Set<String> ingredientIds;
  ShoppingListEvent(this.addedAt, this.ingredientIds);

  Map<String, dynamic> toJson() => {
        'added_at': addedAt.toIso8601String(),
        'ingredient_ids': ingredientIds.toList()..sort(),
      };

  static ShoppingListEvent fromJson(Map<String, dynamic> json) =>
      ShoppingListEvent(
        DateTime.parse(json['added_at'] as String),
        ((json['ingredient_ids'] as List?) ?? const []).cast<String>().toSet(),
      );
}

class Stores {
  late final SharedPreferences _prefs;
  late final Box _box;

  static const _kOnboarded = 'onboarded';
  static const _kProfile = 'profile_json';
  static const _kBoxName = 'morphcook_v1';

  // Hive keys
  static const _kSaved = 'saved'; // List<String> recipe ids (order = recency)
  static const _kHistory = 'history'; // List<json> newest first
  static const _kMealPlan = 'meal_plan'; // json blob
  static const _kShoppingChecked = 'shopping_checked';
  static const _kShoppingSources = 'shopping_sources';
  static const _kShoppingEvents = 'shopping_events';
  static const _kContentRequests = 'content_requests';
  static const _kCookProgressPrefix = 'cook_progress_';

  Future<void> init({String? hiveDir}) async {
    _prefs = await SharedPreferences.getInstance();
    if (hiveDir != null) {
      Hive.init(hiveDir);
    } else {
      await Hive.initFlutter();
    }
    _box = await Hive.openBox(_kBoxName);
  }

  // ---- profile ----
  bool get onboarded => _prefs.getBool(_kOnboarded) ?? false;

  Future<void> setOnboarded() => _prefs.setBool(_kOnboarded, true);

  Future<void> resetOnboarding() => _prefs.setBool(_kOnboarded, false);

  Profile get profile {
    final raw = _prefs.getString(_kProfile);
    if (raw == null) return const Profile();
    try {
      return Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const Profile();
    }
  }

  Future<void> saveProfile(Profile p) =>
      _prefs.setString(_kProfile, jsonEncode(p.toJson()));

  // ---- saved recipes (cookbook) ----
  List<String> get savedRecipeIds =>
      ((_box.get(_kSaved) as List?) ?? const []).cast<String>().toList();

  Future<void> saveRecipe(String id) async {
    final list = savedRecipeIds..remove(id);
    list.insert(0, id);
    await _box.put(_kSaved, list);
  }

  Future<void> unsaveRecipe(String id) async {
    final list = savedRecipeIds..remove(id);
    await _box.put(_kSaved, list);
  }

  // ---- history ----
  List<CookHistoryEntry> get history => ((_box.get(_kHistory) as List?) ?? const [])
      .map((e) => CookHistoryEntry.fromJson(
          Map<String, dynamic>.from((e as Map).cast<String, dynamic>())))
      .toList();

  Future<void> addHistory(String recipeId) async {
    final list = history
      ..insert(0, CookHistoryEntry(recipeId, DateTime.now()));
    await _box.put(
        _kHistory, list.map((e) => e.toJson()).toList().take(500).toList());
  }

  Map<String, DateTime> get lastCookedByRecipe {
    final out = <String, DateTime>{};
    for (final e in history) {
      final existing = out[e.recipeId];
      if (existing == null || e.cookedAt.isAfter(existing)) {
        out[e.recipeId] = e.cookedAt;
      }
    }
    return out;
  }

  // ---- meal plan ----
  MealPlan get mealPlan {
    final raw = _box.get(_kMealPlan);
    if (raw is! String || raw.isEmpty) return const MealPlan();
    try {
      return MealPlan.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const MealPlan();
    }
  }

  Future<void> saveMealPlan(MealPlan plan) =>
      _box.put(_kMealPlan, jsonEncode(plan.toJson()));

  // ---- shopping ----
  Set<String> get checkedIngredients =>
      ((_box.get(_kShoppingChecked) as List?) ?? const []).cast<String>().toSet();

  Future<void> setCheckedIngredients(Set<String> ids) =>
      _box.put(_kShoppingChecked, ids.toList());

  /// Current market list: recipeId -> servings scale factor.
  Map<String, double> get shoppingSources {
    final raw = _box.get(_kShoppingSources);
    if (raw is! Map) return {};
    return raw.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
  }

  Future<void> setShoppingSources(Map<String, double> sources) =>
      _box.put(_kShoppingSources, sources);

  List<ShoppingListEvent> get shoppingEvents =>
      ((_box.get(_kShoppingEvents) as List?) ?? const [])
          .map((e) => ShoppingListEvent.fromJson(
              Map<String, dynamic>.from((e as Map).cast<String, dynamic>())))
          .toList();

  Future<void> addShoppingEvent(Set<String> ingredientIds) async {
    final list = shoppingEvents
      ..insert(0, ShoppingListEvent(DateTime.now(), ingredientIds));
    await _box.put(
        _kShoppingEvents, list.map((e) => e.toJson()).toList().take(500).toList());
  }

  Future<void> clearShoppingEvents() => _box.put(_kShoppingEvents, const []);

  // ---- content requests (zero-result searches) ----
  List<String> get contentRequests =>
      ((_box.get(_kContentRequests) as List?) ?? const []).cast<String>().toList();

  Future<void> addContentRequest(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final list = contentRequests;
    if (list.contains(q)) return; // dedupe: keep first occurrence
    list.insert(0, q);
    await _box.put(_kContentRequests, list.take(200).toList());
  }

  // ---- cook mode progress persistence ----
  Map<String, dynamic>? cookProgress(String recipeId) {
    final raw = _box.get('$_kCookProgressPrefix$recipeId');
    if (raw is! String || raw.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCookProgress(String recipeId, Map<String, dynamic> data) =>
      _box.put('$_kCookProgressPrefix$recipeId', jsonEncode(data));

  Future<void> clearCookProgress(String recipeId) =>
      _box.delete('$_kCookProgressPrefix$recipeId');

  // ---- backup ----
  BackupData buildBackup() => BackupData(
        profile: profile.toJson(),
        saved: savedRecipeIds,
        mealPlan: mealPlan.toJson(),
        history: history.map((e) => e.toJson()).toList(),
        shoppingList: {
          'checked': checkedIngredients.toList(),
          'sources': shoppingSources.map((k, v) => MapEntry(k, v)),
          'events': shoppingEvents.map((e) => e.toJson()).toList(),
        },
        contentRequests: contentRequests,
      );

  Future<void> applyBackup(BackupData data, {required bool replace}) async {
    if (data.profile.isNotEmpty) {
      final current = profile;
      final incoming = Profile.fromJson(data.profile);
      await saveProfile(replace
          ? incoming
          : current.copyWith(
              name: incoming.name.isNotEmpty ? incoming.name : null,
              lang: incoming.lang,
              avoidFlags: incoming.avoidFlags,
              avoidIngredients: incoming.avoidIngredients,
              requiredAttributes: incoming.requiredAttributes,
              preferredEffort: incoming.preferredEffort,
            ));
    }
    if (replace) {
      await _box.put(_kSaved, data.saved);
      await _box.put(
          _kHistory, data.history.map((e) => jsonEncode(e)).toList());
      final mp = MealPlan.fromJson(
          data.mealPlan.map((k, v) => MapEntry(k, v)));
      await saveMealPlan(mp);
      await _box.put(
          _kShoppingEvents,
          ((data.shoppingList['events'] as List?) ?? const [])
              .map((e) => jsonEncode(e))
              .toList());
      await _box.put(_kShoppingChecked,
          ((data.shoppingList['checked'] as List?) ?? const []).toList());
      await _box.put(
          _kShoppingSources,
          ((data.shoppingList['sources'] as Map?) ?? {})
              .map((k, v) => MapEntry(k.toString(), (v as num).toDouble())));
      await _box.put(_kContentRequests, data.contentRequests);
    } else {
      final saved = savedRecipeIds;
      for (final id in data.saved) {
        if (!saved.contains(id)) saved.insert(saved.length, id);
      }
      await _box.put(_kSaved, saved);

      final known = history.map((e) => e.toJson()).toList();
      final knownKeys = known
          .map((e) => '${e['recipe_id']}@${e['cooked_at']}')
          .toSet();
      for (final e in data.history) {
        final key = '${e['recipe_id']}@${e['cooked_at']}';
        if (!knownKeys.contains(key)) known.add(e);
      }
      known.sort((a, b) => (b['cooked_at'] as String)
          .compareTo(a['cooked_at'] as String));
      await _box.put(
          _kHistory, known.map(jsonEncode).toList().take(500).toList());

      final currentPlan = mealPlan;
      var merged = currentPlan;
      final incoming = MealPlan.fromJson(
          data.mealPlan.map((k, v) => MapEntry(k, v)));
      incoming.weeks.forEach((week, slots) {
        slots.forEach((slot, id) {
          if (merged.week(week)[slot] == null) {
            merged = merged.assign(week, slot, id);
          }
        });
      });
      await saveMealPlan(merged);

      final requests = contentRequests;
      for (final q in data.contentRequests) {
        if (!requests.contains(q)) requests.add(q);
      }
      await _box.put(_kContentRequests, requests);
    }
  }
}
