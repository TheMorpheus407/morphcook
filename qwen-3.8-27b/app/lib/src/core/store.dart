import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User profile (persisted).
class Profile {
  Profile({
    required this.name,
    required this.lang,
    this.avoidFlags = const {},
    this.avoidIngredients = const {},
    this.requiredAttributes = const {},
    this.maxTimeMinutes = 90,
    this.calorieTarget = 600,
    this.calorieTolerance = 200,
    this.preferredEffort = 'medium',
    this.showVariantTags = true,
    this.reduceMotion,
    this.visualAlertEnabled = true,
    this.quickNextTapEnabled = false,
    this.calorieOverrideEnabled = false,
  });

  String name;
  String lang; // 'en' | 'de'

  /// Class-level avoid-flags: {dairy, pork, tree-nuts, ...}
  Set<String> avoidFlags;

  /// Specific ingredient ids (leaves or parents, propagation handled by corpus).
  Set<String> avoidIngredients;

  /// Required positive attributes: {halal-compat, ...}
  Set<String> requiredAttributes;

  int maxTimeMinutes;
  int calorieTarget;
  int calorieTolerance;
  String preferredEffort;
  bool showVariantTags;

  /// null = follow system setting.
  bool? reduceMotion;
  bool visualAlertEnabled;
  bool quickNextTapEnabled;

  /// Per-dish override switch state (persisted so it survives navigation).
  bool calorieOverrideEnabled;

  Map<String, dynamic> toJson() => {
        'name': name,
        'lang': lang,
        'avoid_flags': avoidFlags.toList(),
        'avoid_ingredients': avoidIngredients.toList(),
        'required_attributes': requiredAttributes.toList(),
        'max_time_minutes': maxTimeMinutes,
        'calorie_target': calorieTarget,
        'calorie_tolerance': calorieTolerance,
        'preferred_effort': preferredEffort,
        'show_variant_tags': showVariantTags,
        'reduce_motion': reduceMotion,
        'visual_alert_enabled': visualAlertEnabled,
        'quick_next_tap_enabled': quickNextTapEnabled,
        'calorie_override_enabled': calorieOverrideEnabled,
      };

  factory Profile.fromJson(Map<String, dynamic> j) {
    Set<String> set(dynamic v) =>
        ((v as List?) ?? const []).map((e) => e.toString()).toSet();
    return Profile(
      name: j['name'] as String? ?? '',
      lang: j['lang'] as String? ?? 'en',
      avoidFlags: set(j['avoid_flags']),
      avoidIngredients: set(j['avoid_ingredients']),
      requiredAttributes: set(j['required_attributes']),
      maxTimeMinutes: (j['max_time_minutes'] as num? ?? 90).toInt(),
      calorieTarget: (j['calorie_target'] as num? ?? 600).toInt(),
      calorieTolerance: (j['calorie_tolerance'] as num? ?? 200).toInt(),
      preferredEffort: j['preferred_effort'] as String? ?? 'medium',
      showVariantTags: j['show_variant_tags'] as bool? ?? true,
      reduceMotion: j['reduce_motion'] as bool?,
      visualAlertEnabled: j['visual_alert_enabled'] as bool? ?? true,
      quickNextTapEnabled: j['quick_next_tap_enabled'] as bool? ?? false,
      calorieOverrideEnabled: false,
    );
  }

  Profile copyWith() => Profile(
        name: name,
        lang: lang,
        avoidFlags: avoidFlags.toSet(),
        avoidIngredients: avoidIngredients.toSet(),
        requiredAttributes: requiredAttributes.toSet(),
        maxTimeMinutes: maxTimeMinutes,
        calorieTarget: calorieTarget,
        calorieTolerance: calorieTolerance,
        preferredEffort: preferredEffort,
        showVariantTags: showVariantTags,
        reduceMotion: reduceMotion,
        visualAlertEnabled: visualAlertEnabled,
        quickNextTapEnabled: quickNextTapEnabled,
        calorieOverrideEnabled: calorieOverrideEnabled,
      );
}

class HistoryEntry {
  const HistoryEntry({required this.recipeId, required this.atMs});
  final String recipeId;
  final int atMs;
}

class CookSession {
  const CookSession({
    required this.recipeId,
    required this.stepIndex,
    required this.servings,
    required this.updatedAtMs,
  });
  final String recipeId;
  final int stepIndex;
  final int servings;
  final int updatedAtMs;

  Map<String, dynamic> toJson() => {
        'recipeId': recipeId,
        'stepIndex': stepIndex,
        'servings': servings,
        'updatedAtMs': updatedAtMs,
      };
}

/// The whole local app state.
@immutable
class AppData {
  const AppData({
    required this.profile,
    required this.saved,
    required this.history,
    required this.mealPlan,
    required this.contentRequests,
    required this.lastCook,
    required this.onboarded,
  });

  final Profile profile;

  /// recipeId -> savedAtMs (insertion order preserved via map iteration).
  final Map<String, int> saved;

  final List<HistoryEntry> history;

  /// ISO week id ("2026-W34") -> {"mon.breakfast": recipeId}
  final Map<String, Map<String, String>> mealPlan;

  /// normalized query -> lastLoggedMs
  final Map<String, int> contentRequests;

  final CookSession? lastCook;
  final bool onboarded;

  AppData copyWith({
    Profile? profile,
    Map<String, int>? saved,
    List<HistoryEntry>? history,
    Map<String, Map<String, String>>? mealPlan,
    Map<String, int>? contentRequests,
    CookSession? lastCook,
    bool? onboarded,
  }) =>
      AppData(
        profile: profile ?? this.profile,
        saved: saved ?? this.saved,
        history: history ?? this.history,
        mealPlan: mealPlan ?? this.mealPlan,
        contentRequests: contentRequests ?? this.contentRequests,
        lastCook: lastCook ?? this.lastCook,
        onboarded: onboarded ?? this.onboarded,
      );
}

/// Persistent app store. Boring by design: one JSON blob in shared_preferences.
class AppStore extends ChangeNotifier {
  AppStore(this._prefs, this._data);

  final SharedPreferences _prefs;
  AppData _data;

  static const _key = 'mc.state.v1';
  static const maxHistory = 200;

  AppData get data => _data;
  Profile get profile => _data.profile;

  static Future<AppStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    AppData data;
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        data = _decode(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        data = const AppData(
          profile: Profile(name: '', lang: 'en'),
          saved: {},
          history: [],
          mealPlan: {},
          contentRequests: {},
          lastCook: null,
          onboarded: false,
        );
      }
    } else {
      data = const AppData(
        profile: Profile(name: '', lang: 'en'),
        saved: {},
        history: [],
        mealPlan: {},
        contentRequests: {},
        lastCook: null,
        onboarded: false,
      );
    }
    return AppStore(prefs, data);
  }

  static AppData _decode(Map<String, dynamic> j) {
    Profile p =
        Profile.fromJson((j['profile'] as Map? ?? const {}).cast<String, dynamic>());
    final saved = <String, int>{};
    (j['saved'] as Map? ?? const {}).forEach((k, v) {
      saved[k.toString()] = (v as num? ?? 0).toInt();
    });
    final history = ((j['history'] as List? ?? const []) as List)
        .map((e) {
          final m = (e as Map).cast<String, dynamic>();
          return HistoryEntry(
              recipeId: m['recipe_id'] as String,
              atMs: (m['at_ms'] as num? ?? 0).toInt());
        })
        .toList();
    final plan = <String, Map<String, String>>{};
    (j['meal_plan'] as Map? ?? const {}).forEach((k, v) {
      plan[k.toString()] =
          ((v as Map).map((a, b) => MapEntry(a.toString(), b.toString())));
    });
    final requests = <String, int>{};
    (j['content_requests'] as Map? ?? const {}).forEach((k, v) {
      requests[k.toString()] = (v as num? ?? 0).toInt();
    });
    CookSession? lastCook;
    final lc = (j['last_cook'] as Map?)?.cast<String, dynamic>();
    if (lc != null) {
      lastCook = CookSession(
        recipeId: lc['recipeId'] as String,
        stepIndex: (lc['stepIndex'] as num? ?? 0).toInt(),
        servings: (lc['servings'] as num? ?? 2).toInt(),
        updatedAtMs: (lc['updatedAtMs'] as num? ?? 0).toInt(),
      );
    }
    return AppData(
      profile: p,
      saved: saved,
      history: history,
      mealPlan: plan,
      contentRequests: requests,
      lastCook: lastCook,
      onboarded: j['onboarded'] as bool? ?? false,
    );
  }

  Map<String, dynamic> _encode() => {
        'schema_version': 1,
        'profile': _data.profile.toJson(),
        'saved': _data.saved,
        'history': _data.history
            .map((h) => {'recipe_id': h.recipeId, 'at_ms': h.atMs})
            .toList(),
        'meal_plan': _data.mealPlan,
        'content_requests': _data.contentRequests,
        'last_cook': _data.lastCook?.toJson(),
        'onboarded': _data.onboarded,
      };

  Future<void> _persist() async {
    await _prefs.setString(_key, jsonEncode(_encode()));
  }

  // ---- profile -------------------------------------------------------

  void setProfile(Profile p) {
    _data = _data.copyWith(profile: p);
    notifyListeners();
    // ignore: unawaited_futures
    _persist();
  }

  void setOnboarded(bool v) {
    _data = _data.copyWith(onboarded: v);
    notifyListeners();
    // ignore: unawaited_futures
    _persist();
  }

  // ---- saved ---------------------------------------------------------

  List<String> get savedIds => _data.saved.keys.toList();
  bool isSaved(String recipeId) => _data.saved.containsKey(recipeId);
  int? savedAt(String recipeId) => _data.saved[recipeId];

  void toggleSave(String recipeId) {
    final saved = Map<String, int>.from(_data.saved);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (saved.containsKey(recipeId)) {
      saved.remove(recipeId);
    } else {
      saved[recipeId] = now;
    }
    _data = _data.copyWith(saved: saved);
    notifyListeners();
    // ignore: unawaited_futures
    _persist();
  }

  // ---- history -------------------------------------------------------

  void recordCooked(String recipeId) {
    final list = List<HistoryEntry>.of(_data.history);
    list.insert(0,
        HistoryEntry(recipeId: recipeId, atMs: DateTime.now().millisecondsSinceEpoch));
    if (list.length > maxHistory) {
      list.removeRange(maxHistory, list.length);
    }
    _data = _data.copyWith(history: list);
    notifyListeners();
    // ignore: unawaited_futures
    _persist();
  }

  /// Most recent time a recipe was cooked, or null.
  int? lastCooked(String recipeId) {
    for (final h in _data.history) {
      if (h.recipeId == recipeId) return h.atMs;
    }
    return null;
  }

  // ---- meal plan -----------------------------------------------------

  static const dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  static const slotKeys = ['breakfast', 'lunch', 'dinner'];

  /// ISO week id (e.g. "2026-W34") for a date.
  static String isoWeekId(DateTime d) {
    final jan4 = DateTime(d.year, 1, 4);
    final jan4Monday =
        jan4.subtract(Duration(days: jan4.weekday - 1));
    final week = ((d.difference(jan4Monday).inDays) ~/ 7) + 1;
    final year = jan4Monday.year == d.year ? d.year : (week < 1 ? d.year - 1 : d.year);
    return '${year}-W${week.toString().padLeft(2, '0')}';
  }

  String? planGet(String weekId, String slot) => _data.mealPlan[weekId]?[slot];

  void planSet(String weekId, String slot, String recipeId) {
    final plan = Map<String, Map<String, String>>.from(_data.mealPlan);
    final week = Map<String, String>.from(plan[weekId] ?? const {});
    week[slot] = recipeId;
    plan[weekId] = week;
    _data = _data.copyWith(mealPlan: plan);
    notifyListeners();
    // ignore: unawaited_futures
    _persist();
  }

  void planClear(String weekId, String slot) {
    final plan = Map<String, Map<String, String>>.from(_data.mealPlan);
    final week = Map<String, String>.from(plan[weekId] ?? const {});
    week.remove(slot);
    if (week.isEmpty) {
      plan.remove(weekId);
    } else {
      plan[weekId] = week;
    }
    _data = _data.copyWith(mealPlan: plan);
    notifyListeners();
    // ignore: unawaited_futures
    _persist();
  }

  void planMove(String fromWeek, String fromSlot, String toWeek, String toSlot) {
    final recipeId = planGet(fromWeek, fromSlot);
    if (recipeId == null) return;
    final plan = Map<String, Map<String, String>>.from(_data.mealPlan);
    final source = Map<String, String>.from(plan[fromWeek] ?? const {});
    source.remove(fromSlot);
    if (source.isEmpty) {
      plan.remove(fromWeek);
    } else {
      plan[fromWeek] = source;
    }
    final target = Map<String, String>.from(plan[toWeek] ?? const {});
    target[toSlot] = recipeId;
    plan[toWeek] = target;
    _data = _data.copyWith(mealPlan: plan);
    notifyListeners();
    // ignore: unawaited_futures
    _persist();
  }

  List<String> planRecipesInWeek(String weekId) {
    final week = _data.mealPlan[weekId] ?? const {};
    return week.values.toList();
  }

  // ---- content requests ----------------------------------------------

  void logContentRequest(String query) {
    final key = query.trim().toLowerCase();
    if (key.isEmpty) return;
    final map = Map<String, int>.from(_data.contentRequests);
    map[key] = DateTime.now().millisecondsSinceEpoch;
    _data = _data.copyWith(contentRequests: map);
    // ignore: unawaited_futures
    _persist();
  }

  List<String> get contentRequests =>
      _data.contentRequests.keys.map((e) => e).toList(growable: false);

  // ---- cook session ----------------------------------------------------

  void saveSession(CookSession session) {
    _data = _data.copyWith(lastCook: session);
    // ignore: unawaited_futures
    _persist();
  }

  void clearSession() {
    _data = _data.copyWith(lastCook: null);
    // note: not notifying; session is cook-screen-local
    // ignore: unawaited_futures
    _persist();
  }

  // ---- reset -----------------------------------------------------------

  /// Replace the full local dataset from a validated backup map.
  /// Used by import (merge/replace already applied by caller).
  /// [keepProfile] ignores the profile in [json] (caller may have merged it).
  Future<void> replaceState(Map<String, dynamic> json, {bool keepProfile = false}) async {
    Profile p;
    if (keepProfile) {
      p = _data.profile;
    } else {
      p = Profile.fromJson(
          (json['profile'] as Map? ?? const {}).cast<String, dynamic>());
    }
    final saved = <String, int>{};
    (json['saved'] as Map? ?? const {}).forEach((k, v) {
      saved[k.toString()] = (v as num? ?? 0).toInt();
    });
    final history = ((json['history'] as List? ?? const []) as List)
        .map((e) {
          final m = (e as Map).cast<String, dynamic>();
          return HistoryEntry(
              recipeId: m['recipe_id'] as String, atMs: (m['at_ms'] as num? ?? 0).toInt());
        })
        .toList();
    final plan = <String, Map<String, String>>{};
    (json['meal_plan'] as Map? ?? const {}).forEach((k, v) {
      plan[k.toString()] = ((v as Map).map((a, b) => MapEntry(a.toString(), b.toString())));
    });
    final requests = <String, int>{};
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final q in (json['content_requests'] as List? ?? const [])) {
      requests[q.toString()] = now;
    }
    _data = _data.copyWith(
      profile: p,
      saved: saved,
      history: history,
      mealPlan: plan,
      contentRequests: requests,
    );
    notifyListeners();
    await _persist();
  }

  Future<void> resetAll() async {
    await _prefs.remove(_key);
  }
}
