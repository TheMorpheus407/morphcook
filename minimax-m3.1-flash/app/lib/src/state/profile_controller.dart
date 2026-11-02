import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';

/// The user's profile and dietary preferences.
///
/// The profile is the only thing that decides what the cook sees. It is
/// stored in `shared_preferences` because it is small, and because it is the
/// one thing a user is most likely to want to export.
class ProfileController extends ChangeNotifier {
  ProfileController(this._prefs) {
    _profile = _read();
  }

  static const String _key = Profile.storageKey;

  final SharedPreferences _prefs;
  late Profile _profile;

  Profile get profile => _profile;

  String get lang => _profile.lang;

  Profile _read() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return Profile.initial();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return Profile.fromJson(decoded);
    } catch (_) {
      // Fall through to a fresh profile.
    }
    return Profile.initial();
  }

  Future<void> _persist() async {
    await _prefs.setString(_key, jsonEncode(_profile.toJson()));
  }

  void _apply(Profile next) {
    _profile = next;
    notifyListeners();
    unawaited(_persist());
  }

  // ── Identity ─────────────────────────────────────────────────────────────

  void setName(String name) =>
      _apply(_profile.copyWith(name: name.trim()));

  void setLanguage(String code) => _apply(_profile.copyWith(lang: code));

  // ── Dietary preferences ──────────────────────────────────────────────────

  void toggleAvoidFlag(String flagId) {
    final next = Set<String>.from(_profile.avoidFlags);
    if (!next.remove(flagId)) next.add(flagId);
    _apply(_profile.copyWith(avoidFlags: next));
  }

  void setAvoidFlags(Set<String> flags) =>
      _apply(_profile.copyWith(avoidFlags: Set<String>.from(flags)));

  void addAvoidIngredient(String ingredientId) {
    final next = Set<String>.from(_profile.avoidIngredients);
    next.add(ingredientId);
    _apply(_profile.copyWith(avoidIngredients: next));
  }

  void removeAvoidIngredient(String ingredientId) {
    final next = Set<String>.from(_profile.avoidIngredients);
    next.remove(ingredientId);
    _apply(_profile.copyWith(avoidIngredients: next));
  }

  void setAvoidIngredients(Set<String> ingredientIds) => _apply(
        _profile.copyWith(
          avoidIngredients: Set<String>.from(ingredientIds),
        ),
      );

  void toggleRequiredAttribute(String attribute) {
    final next = Set<String>.from(_profile.requiredAttributes);
    if (!next.remove(attribute)) next.add(attribute);
    _apply(_profile.copyWith(requiredAttributes: next));
  }

  // ── Targets ──────────────────────────────────────────────────────────────

  void setMaxTimeMinutes(int minutes) =>
      _apply(_profile.copyWith(maxTimeMinutes: minutes));

  void setCalorieTarget(int calories) =>
      _apply(_profile.copyWith(calorieTarget: calories));

  void setCalorieTolerance(int tolerance) =>
      _apply(_profile.copyWith(calorieTolerance: tolerance));

  void setPreferredEffort(String effort) =>
      _apply(_profile.copyWith(preferredEffort: effort));

  // ── UI preferences ───────────────────────────────────────────────────────

  void setShowVariantTags(bool value) =>
      _apply(_profile.copyWith(showVariantTags: value));

  /// `null` restores "follow the system setting".
  void setReduceMotion(bool? value) =>
      _apply(_profile.copyWith(reduceMotion: () => value));

  void setVisualAlertEnabled(bool value) =>
      _apply(_profile.copyWith(visualAlertEnabled: value));

  void setQuickNextTapEnabled(bool value) =>
      _apply(_profile.copyWith(quickNextTapEnabled: value));

  // ── Per-dish calorie override ────────────────────────────────────────────

  void toggleDishOutsideCalorieTarget(String dishId) {
    final next = Set<String>.from(_profile.dishesOutsideCalorieTarget);
    if (!next.remove(dishId)) next.add(dishId);
    _apply(_profile.copyWith(dishesOutsideCalorieTarget: next));
  }

  bool allowsOutsideCalorieTarget(String dishId) =>
      _profile.dishesOutsideCalorieTarget.contains(dishId);

  /// Applies a profile restored from a backup.
  void updateFromBackup(Profile restored) {
    _apply(restored.copyWith(onboardingComplete: _profile.onboardingComplete));
  }

  // ── Onboarding ───────────────────────────────────────────────────────────

  void completeOnboarding() =>
      _apply(_profile.copyWith(onboardingComplete: true));

  void resetProfile() {
    _apply(Profile.initial(lang: _profile.lang));
  }
}

/// Fire-and-forget helper that keeps `unawaited` out of the call sites.
void unawaited(Future<void> future) {
  future.catchError((Object _) {});
}
