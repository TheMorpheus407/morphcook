import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/localized.dart';
import '../models/profile.dart';

/// Owns the single user profile, persisted to shared_preferences. The whole
/// app listens to this for filter/language changes.
class ProfileService extends ChangeNotifier {
  ProfileService(this._prefs) {
    _load();
  }

  static const _key = 'morphcook.profile';
  final SharedPreferences _prefs;

  Profile _profile = const Profile();
  Profile get profile => _profile;
  AppLang get lang => _profile.lang;

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        _profile = Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {/* corrupt prefs: start fresh */}
    }
  }

  Future<void> update(Profile next) async {
    _profile = next;
    await _prefs.setString(_key, jsonEncode(next.toJson()));
    notifyListeners();
  }

  /// Replace the profile from an imported backup (used by restore).
  Future<void> replaceFromJson(Map<String, dynamic> json) =>
      update(Profile.fromJson(json));

  Future<void> setLang(AppLang lang) => update(_profile.copyWith(lang: lang));

  Future<void> completeOnboarding(Profile p) =>
      update(p.copyWith(onboarded: true));
}
