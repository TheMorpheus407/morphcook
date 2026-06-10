import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';

/// Persistence boundary: shared_preferences for the profile + small flags,
/// Hive for collections. Swappable for an in-memory store in tests.
abstract class PersistenceStore {
  Future<void> open();

  Profile? loadProfile();
  Future<void> saveProfile(Profile profile);
  bool get onboardingComplete;
  Future<void> setOnboardingComplete(bool value);

  /// Collections are stored as JSON strings under a key.
  String? getCollection(String key);
  Future<void> putCollection(String key, String jsonText);
  Future<void> clearAll();
}

class HiveStore implements PersistenceStore {
  late SharedPreferences _prefs;
  late Box<String> _box;

  @override
  Future<void> open() async {
    _prefs = await SharedPreferences.getInstance();
    await Hive.initFlutter();
    _box = await Hive.openBox<String>('morphcook');
  }

  @override
  Profile? loadProfile() {
    final raw = _prefs.getString('profile');
    if (raw == null) return null;
    try {
      return Profile.fromJson(json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveProfile(Profile profile) async {
    await _prefs.setString('profile', json.encode(profile.toJson()));
  }

  @override
  bool get onboardingComplete =>
      _prefs.getBool('onboarding_complete') ?? false;

  @override
  Future<void> setOnboardingComplete(bool value) async {
    await _prefs.setBool('onboarding_complete', value);
  }

  @override
  String? getCollection(String key) => _box.get(key);

  @override
  Future<void> putCollection(String key, String jsonText) async {
    await _box.put(key, jsonText);
  }

  @override
  Future<void> clearAll() async {
    await _prefs.clear();
    await _box.clear();
  }
}

/// In-memory store for tests and previews.
class MemoryStore implements PersistenceStore {
  Profile? _profile;
  bool _onboarded = false;
  final Map<String, String> _collections = {};

  @override
  Future<void> open() async {}

  @override
  Profile? loadProfile() => _profile;

  @override
  Future<void> saveProfile(Profile profile) async => _profile = profile;

  @override
  bool get onboardingComplete => _onboarded;

  @override
  Future<void> setOnboardingComplete(bool value) async => _onboarded = value;

  @override
  String? getCollection(String key) => _collections[key];

  @override
  Future<void> putCollection(String key, String jsonText) async {
    _collections[key] = jsonText;
  }

  @override
  Future<void> clearAll() async {
    _profile = null;
    _onboarded = false;
    _collections.clear();
  }
}
