import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/l10n.dart';
import '../data/profile.dart';

/// Profile + app-level settings, persisted in shared_preferences.
class AppModel extends ChangeNotifier {
  static const _profileKey = 'profile.v1';

  SharedPreferences? _prefs;
  Profile _profile = Profile();
  bool _onboardingDone = false;

  Profile get profile => _profile;
  bool get onboardingDone => _onboardingDone;
  AppLang get lang => _profile.lang;
  Strings get strings => Strings(_profile.lang);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs?.getString(_profileKey);
    if (raw != null) {
      try {
        _profile = Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        _onboardingDone = _profile.onboarded;
      } catch (_) {
        _profile = Profile();
      }
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    await _prefs?.setString(_profileKey, jsonEncode(_profile.toJson()));
    notifyListeners();
  }

  void updateProfile(void Function(Profile profile) mutate) {
    mutate(_profile);
    _persist();
  }

  Future<void> replaceProfile(Profile profile) async {
    _profile = profile;
    _onboardingDone = profile.onboarded;
    await _persist();
  }

  Future<void> finishOnboarding() async {
    _onboardingDone = true;
    await _persist();
  }

  Future<void> resetOnboarding() async {
    _onboardingDone = false;
    notifyListeners();
  }

  void setLang(AppLang lang) {
    if (_profile.lang == lang) return;
    _profile.lang = lang;
    _persist();
  }
}
