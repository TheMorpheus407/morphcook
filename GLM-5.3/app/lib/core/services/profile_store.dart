import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';

/// Persists the profile plus small flags in `shared_preferences` (SPEC).
/// Also owns the per-dish calorie override set and the onboarding flag.
class ProfileStore {
  ProfileStore(this._prefs);

  static const _keyProfile = 'profile';
  static const _keyOnboarded = 'onboarding_done';
  static const _keyCalorieOverrides = 'calorie_override_dishes';
  static const _keyQuickNext = 'quick_next_tap_enabled';

  final SharedPreferences _prefs;

  Profile load() {
    final raw = _prefs.getString(_keyProfile);
    if (raw == null) return Profile();
    try {
      return Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return Profile();
    }
  }

  Future<void> save(Profile profile) =>
      _prefs.setString(_keyProfile, jsonEncode(profile.toJson()));

  bool get onboardingDone => _prefs.getBool(_keyOnboarded) ?? false;

  Future<void> setOnboardingDone() => _prefs.setBool(_keyOnboarded, true);

  /// Dishes where the hard calorie filter is overridden ("show versions
  /// outside my target" per-dish switch, SPEC).
  Set<String> calorieOverrides() =>
      (_prefs.getStringList(_keyCalorieOverrides) ?? const []).toSet();

  Future<void> setCalorieOverride(String dishId, bool enabled) async {
    final current = calorieOverrides();
    if (enabled) {
      current.add(dishId);
    } else {
      current.remove(dishId);
    }
    await _prefs.setStringList(_keyCalorieOverrides, current.toList());
  }

  bool get quickNextTapEnabled => _prefs.getBool(_keyQuickNext) ?? false;

  Future<void> setQuickNextTapEnabled(bool value) => _prefs.setBool(_keyQuickNext, value);

  /// Lazy cook-progress store over the same preferences.
  CookProgressStore? _cook;

  CookProgressStore get cook => _cook ??= CookProgressStore(_prefs);
}

/// Cook-mode progress persistence (SPEC: pause/resume with progress
/// persistence). Stored as small JSON in shared_preferences.
class CookProgressStore {
  CookProgressStore(this._prefs);

  static const _key = 'cook_progress';

  final SharedPreferences _prefs;

  CookProgress? load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      return CookProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(CookProgress progress) =>
      _prefs.setString(_key, jsonEncode(progress.toJson()));

  Future<void> clear() => _prefs.remove(_key);
}

class CookProgress {
  CookProgress({
    required this.recipeId,
    required this.stepIndex,
    required this.servings,
    this.timerRemainingSeconds,
    this.timerRunning = false,
    required this.updatedAt,
  });

  final String recipeId;
  final int stepIndex;
  final int servings;
  final int? timerRemainingSeconds;
  final bool timerRunning;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'recipe_id': recipeId,
        'step': stepIndex,
        'servings': servings,
        'timer_remaining': timerRemainingSeconds,
        'timer_running': timerRunning,
        'updated_at': updatedAt.toIso8601String(),
      };

  static CookProgress fromJson(Map<String, dynamic> json) => CookProgress(
        recipeId: json['recipe_id'] as String,
        stepIndex: (json['step'] as num).toInt(),
        servings: (json['servings'] as num?)?.toInt() ?? 2,
        timerRemainingSeconds: json['timer_remaining'] == null
            ? null
            : (json['timer_remaining'] as num).toInt(),
        timerRunning: json['timer_running'] as bool? ?? false,
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}
