import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';

/// Profile + small flags in shared_preferences.
class ProfileStore extends ChangeNotifier {
  static const _key = 'morphcook.profile';
  static const _onboardedKey = 'morphcook.onboarded';
  static const _calorieOverrideKey = 'morphcook.calorie_overrides';

  SharedPreferences? _prefs;
  UserProfile _profile = const UserProfile();
  bool _onboarded = false;

  /// Per-dish override: show variants outside the calorie target.
  final Set<String> _calorieOverrideDishIds = {};

  UserProfile get profile => _profile;
  bool get onboarded => _onboarded;
  bool get isLoaded => _prefs != null;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw != null) {
      try {
        _profile = UserProfile.decode(raw);
      } catch (_) {
        _profile = const UserProfile();
      }
    }
    _onboarded = _prefs!.getBool(_onboardedKey) ?? false;
    _calorieOverrideDishIds
      ..clear()
      ..addAll(_prefs!.getStringList(_calorieOverrideKey) ?? const []);
    notifyListeners();
  }

  Future<void> save(UserProfile profile) async {
    _profile = profile;
    await _prefs?.setString(_key, profile.encode());
    notifyListeners();
  }

  Future<void> completeOnboarding(UserProfile profile) async {
    await save(profile);
    _onboarded = true;
    await _prefs?.setBool(_onboardedKey, true);
    notifyListeners();
  }

  bool hasCalorieOverride(String dishId) =>
      _calorieOverrideDishIds.contains(dishId);

  Future<void> setCalorieOverride(String dishId, bool enabled) async {
    if (enabled) {
      _calorieOverrideDishIds.add(dishId);
    } else {
      _calorieOverrideDishIds.remove(dishId);
    }
    await _prefs?.setStringList(
        _calorieOverrideKey, _calorieOverrideDishIds.toList());
    notifyListeners();
  }
}
