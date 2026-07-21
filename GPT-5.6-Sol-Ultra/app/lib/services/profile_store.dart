import 'dart:convert';

import 'package:morphcook/domain/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({
    this.onboardingComplete = false,
    this.quickNextTapEnabled = false,
    this.dismissedHints = const <String>{},
  });

  final bool onboardingComplete;
  final bool quickNextTapEnabled;
  final Set<String> dismissedHints;

  AppSettings copyWith({
    bool? onboardingComplete,
    bool? quickNextTapEnabled,
    Set<String>? dismissedHints,
  }) => AppSettings(
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    quickNextTapEnabled: quickNextTapEnabled ?? this.quickNextTapEnabled,
    dismissedHints: dismissedHints ?? this.dismissedHints,
  );
}

abstract interface class ProfileStore {
  Future<UserProfile?> loadProfile();
  Future<void> saveProfile(UserProfile profile);
  Future<void> deleteProfile();
  Future<AppSettings> loadSettings();
  Future<void> saveSettings(AppSettings settings);
  Future<void> clear();
}

/// SharedPreferences-backed profile/settings storage.
///
/// The profile is one versioned JSON document, keeping all profile writes
/// coherent and allowing additive fields without coordinating many keys.
class SharedPreferencesProfileStore implements ProfileStore {
  SharedPreferencesProfileStore(this._preferences);

  static const profileKey = 'morphcook.profile.v1';
  static const onboardingKey = 'morphcook.onboarding_complete';
  static const quickNextKey = 'morphcook.quick_next_tap_enabled';
  static const dismissedHintsKey = 'morphcook.dismissed_hints';

  static Future<SharedPreferencesProfileStore> create() async =>
      SharedPreferencesProfileStore(await SharedPreferences.getInstance());

  final SharedPreferences _preferences;

  @override
  Future<UserProfile?> loadProfile() async {
    final encoded = _preferences.getString(profileKey);
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return null;
      return UserProfile.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    } on Object {
      // A malformed preference must not prevent the app from starting. The
      // original value remains available for diagnostics/backup.
      return null;
    }
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    final saved = await _preferences.setString(
      profileKey,
      jsonEncode(profile.toJson()),
    );
    if (!saved) throw StateError('Could not persist the MorphCook profile.');
  }

  @override
  Future<void> deleteProfile() async {
    final removed = await _preferences.remove(profileKey);
    if (!removed && _preferences.containsKey(profileKey)) {
      throw StateError('Could not remove the MorphCook profile.');
    }
  }

  @override
  Future<AppSettings> loadSettings() async => AppSettings(
    onboardingComplete: _preferences.getBool(onboardingKey) ?? false,
    quickNextTapEnabled: _preferences.getBool(quickNextKey) ?? false,
    dismissedHints:
        (_preferences.getStringList(dismissedHintsKey) ?? const <String>[])
            .toSet(),
  );

  @override
  Future<void> saveSettings(AppSettings settings) async {
    final hints = settings.dismissedHints.toList()..sort();
    final results = await Future.wait<bool>(<Future<bool>>[
      _preferences.setBool(onboardingKey, settings.onboardingComplete),
      _preferences.setBool(quickNextKey, settings.quickNextTapEnabled),
      _preferences.setStringList(dismissedHintsKey, hints),
    ]);
    if (results.any((saved) => !saved)) {
      throw StateError('Could not persist MorphCook settings.');
    }
  }

  @override
  Future<void> clear() async {
    await Future.wait<bool>(<Future<bool>>[
      _preferences.remove(profileKey),
      _preferences.remove(onboardingKey),
      _preferences.remove(quickNextKey),
      _preferences.remove(dismissedHintsKey),
    ]);
  }
}

class MemoryProfileStore implements ProfileStore {
  MemoryProfileStore({UserProfile? profile, AppSettings? settings})
    : _profile = profile,
      _settings = settings ?? const AppSettings();

  UserProfile? _profile;
  AppSettings _settings;

  @override
  Future<UserProfile?> loadProfile() async => _profile;

  @override
  Future<void> saveProfile(UserProfile profile) async => _profile = profile;

  @override
  Future<void> deleteProfile() async => _profile = null;

  @override
  Future<AppSettings> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(AppSettings settings) async => _settings = settings;

  @override
  Future<void> clear() async {
    _profile = null;
    _settings = const AppSettings();
  }
}
