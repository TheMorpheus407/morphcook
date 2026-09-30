import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/models/ingredient.dart';
import '../../data/models/ontology.dart';
import '../../data/models/profile.dart';
import '../../domain/matching.dart';
import '../storage/storage.dart';

/// The one profile per install, the device settings and the onboarding flag.
class ProfileController extends ChangeNotifier {
  ProfileController(this._store, {required this.ontology, required this.ingredients, Profile initial = const Profile()})
    : _profile = initial {
    _load();
  }

  static const String profileKey = 'profile.v1';
  static const String settingsKey = 'settings.v1';
  static const String onboardedKey = 'onboarded.v1';
  static const String calorieOverrideKey = 'calorie_override.v1';

  final KeyValueStore _store;
  final Ontology ontology;
  final IngredientDictionary ingredients;

  Profile _profile;
  AppSettings _settings = const AppSettings();
  bool _onboarded = false;
  Set<String> _calorieOverrides = <String>{};
  ProfileFilter? _filter;

  Profile get profile => _profile;
  AppSettings get settings => _settings;
  bool get onboarded => _onboarded;
  String get lang => _profile.lang;

  /// The profile compiled for matching; rebuilt whenever the profile changes.
  ProfileFilter get filter => _filter ??= ProfileFilter.compile(_profile, ontology, ingredients);

  void _load() {
    final rawProfile = _store.getString(profileKey);
    if (rawProfile != null) {
      try {
        _profile = Profile.fromJson((jsonDecode(rawProfile) as Map).cast<String, dynamic>());
      } catch (_) {
        // A damaged record falls back to the initial profile.
      }
    }
    final rawSettings = _store.getString(settingsKey);
    if (rawSettings != null) {
      try {
        _settings = AppSettings.fromJson((jsonDecode(rawSettings) as Map).cast<String, dynamic>());
      } catch (_) {}
    }
    _onboarded = _store.getString(onboardedKey) == 'true';
    final rawOverrides = _store.getString(calorieOverrideKey);
    if (rawOverrides != null) {
      try {
        _calorieOverrides = (jsonDecode(rawOverrides) as List).map((e) => e.toString()).toSet();
      } catch (_) {}
    }
  }

  Future<void> setProfile(Profile profile) async {
    if (profile == _profile) return;
    _profile = profile;
    _filter = null;
    notifyListeners();
    await _store.setString(profileKey, jsonEncode(profile.toJson()));
  }

  Future<void> updateProfile(Profile Function(Profile current) change) => setProfile(change(_profile));

  Future<void> setSettings(AppSettings settings) async {
    if (settings == _settings) return;
    _settings = settings;
    notifyListeners();
    await _store.setString(settingsKey, jsonEncode(settings.toJson()));
  }

  Future<void> updateSettings(AppSettings Function(AppSettings current) change) => setSettings(change(_settings));

  Future<void> completeOnboarding(Profile profile) async {
    _onboarded = true;
    await _store.setString(onboardedKey, 'true');
    await setProfile(profile);
    notifyListeners();
  }

  /// Per-dish switch: show variants outside the calorie target for this dish.
  bool calorieOverrideFor(String dishId) => _calorieOverrides.contains(dishId);

  Future<void> setCalorieOverride(String dishId, bool enabled) async {
    final changed = enabled ? _calorieOverrides.add(dishId) : _calorieOverrides.remove(dishId);
    if (!changed) return;
    notifyListeners();
    await _store.setString(calorieOverrideKey, jsonEncode(_calorieOverrides.toList()..sort()));
  }

  /// Back to a fresh install (used by "delete all my data").
  Future<void> resetAll({Profile? initial}) async {
    _profile = initial ?? Profile(lang: _profile.lang);
    _settings = const AppSettings();
    _onboarded = false;
    _calorieOverrides = <String>{};
    _filter = null;
    for (final key in [profileKey, settingsKey, onboardedKey, calorieOverrideKey]) {
      await _store.remove(key);
    }
    notifyListeners();
  }
}
