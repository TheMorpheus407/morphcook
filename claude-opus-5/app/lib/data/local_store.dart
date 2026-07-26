import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/collections.dart';
import '../domain/profile.dart';

/// A tiny key→JSON-string interface so the collections layer can be exercised
/// in tests without a Hive box on disk.
abstract class JsonStore {
  String? read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> clear();
}

class MemoryJsonStore implements JsonStore {
  final Map<String, String> _values = {};

  @override
  String? read(String key) => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<void> clear() async => _values.clear();
}

class HiveJsonStore implements JsonStore {
  HiveJsonStore(this._box);

  static const String boxName = 'morphcook_collections';

  static Future<HiveJsonStore> open() async {
    await Hive.initFlutter();
    final box = await Hive.openBox<String>(boxName);
    return HiveJsonStore(box);
  }

  final Box<String> _box;

  @override
  String? read(String key) => _box.get(key);

  @override
  Future<void> write(String key, String value) => _box.put(key, value);

  @override
  Future<void> delete(String key) => _box.delete(key);

  @override
  Future<void> clear() => _box.clear();
}

/// Profile lives in shared_preferences — it is small, flat and read on launch.
class ProfileStore {
  ProfileStore(this._prefs);

  static const String _key = 'morphcook.profile.v1';

  static Future<ProfileStore> open() async =>
      ProfileStore(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  Profile load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const Profile();
    try {
      return Profile.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } on FormatException {
      return const Profile();
    }
  }

  Future<void> save(Profile profile) =>
      _prefs.setString(_key, jsonEncode(profile.toJson()));

  Future<void> reset() => _prefs.remove(_key);
}

/// Saved recipes, cooking history, meal plan, shopping list, content requests
/// and cook-mode progress. One Hive box, six keys, all plain JSON — no
/// generated adapters, so a schema change never needs a migration script.
class CollectionsStore {
  CollectionsStore(this._store);

  static const String _kSaved = 'saved';
  static const String _kHistory = 'history';
  static const String _kPlan = 'meal_plan';
  static const String _kShopping = 'shopping';
  static const String _kRequests = 'content_requests';
  static const String _kProgress = 'cook_progress';

  final JsonStore _store;

  List<T> _list<T>(String key, T Function(Map<String, dynamic>) parse) {
    final raw = _store.read(key);
    if (raw == null) return <T>[];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => parse((e as Map).cast<String, dynamic>()))
          .toList();
    } on Object {
      return <T>[];
    }
  }

  Future<void> _putList(String key, List<Map<String, dynamic>> values) =>
      _store.write(key, jsonEncode(values));

  // --- saved --------------------------------------------------------------

  List<SavedRecipe> loadSaved() => _list(_kSaved, SavedRecipe.fromJson);

  Future<void> saveSaved(List<SavedRecipe> items) =>
      _putList(_kSaved, items.map((e) => e.toJson()).toList());

  // --- history ------------------------------------------------------------

  List<CookHistoryEntry> loadHistory() =>
      _list(_kHistory, CookHistoryEntry.fromJson);

  Future<void> saveHistory(List<CookHistoryEntry> items) =>
      _putList(_kHistory, items.map((e) => e.toJson()).toList());

  // --- meal plan ----------------------------------------------------------

  MealPlan loadPlan() {
    final raw = _store.read(_kPlan);
    if (raw == null) return MealPlan();
    try {
      return MealPlan.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    } on Object {
      return MealPlan();
    }
  }

  Future<void> savePlan(MealPlan plan) =>
      _store.write(_kPlan, jsonEncode(plan.toJson()));

  // --- shopping -----------------------------------------------------------

  List<ShoppingEntry> loadShopping() =>
      _list(_kShopping, ShoppingEntry.fromJson);

  Future<void> saveShopping(List<ShoppingEntry> items) =>
      _putList(_kShopping, items.map((e) => e.toJson()).toList());

  // --- content requests ---------------------------------------------------

  List<ContentRequest> loadRequests() {
    final raw = _store.read(_kRequests);
    if (raw == null) return <ContentRequest>[];
    try {
      return (jsonDecode(raw) as List).map(ContentRequest.fromJson).toList();
    } on Object {
      return <ContentRequest>[];
    }
  }

  Future<void> saveRequests(List<ContentRequest> items) =>
      _putList(_kRequests, items.map((e) => e.toJson()).toList());

  // --- cook progress ------------------------------------------------------

  CookProgress? loadProgress() {
    final raw = _store.read(_kProgress);
    if (raw == null) return null;
    try {
      return CookProgress.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    } on Object {
      return null;
    }
  }

  Future<void> saveProgress(CookProgress? progress) => progress == null
      ? _store.delete(_kProgress)
      : _store.write(_kProgress, jsonEncode(progress.toJson()));

  Future<void> clearAll() => _store.clear();
}
