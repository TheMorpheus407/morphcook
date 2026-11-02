import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

/// The key/value contract the app stores its collections behind.
///
/// Kept as an interface so the controllers can be tested without Hive.
abstract interface class KeyValueStore {
  String? readString(String key);
  Future<void> writeString(String key, String value);
  Future<void> delete(String key);
  bool contains(String key);
  List<Map<String, dynamic>> readList(String key);
  Future<void> writeList(String key, List<Map<String, dynamic>> value);
  Map<String, dynamic> readMap(String key);
  Future<void> writeMap(String key, Map<String, dynamic> value);
}

/// An in-memory store, used by the tests.
class MemoryStore implements KeyValueStore {
  final Map<String, String> _values = <String, String>{};

  @override
  bool contains(String key) => _values.containsKey(key);

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  String? readString(String key) => _values[key];

  @override
  Map<String, dynamic> readMap(String key) {
    final raw = _values[key];
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{};
  }

  @override
  List<Map<String, dynamic>> readList(String key) {
    final raw = _values[key];
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <Map<String, dynamic>>[];
    return decoded.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  @override
  Future<void> writeList(String key, List<Map<String, dynamic>> value) async {
    _values[key] = jsonEncode(value);
  }

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    _values[key] = jsonEncode(value);
  }

  @override
  Future<void> writeString(String key, String value) async {
    _values[key] = value;
  }
}

/// Local collection storage.
///
/// MorphCook keeps everything on the device: there is no account, no sync
/// and no network. The profile and the small preference flags live in
/// `shared_preferences`; the collections (cookbook, meal plan, history,
/// shopping list) live here, in a Hive box of JSON strings — no type
/// adapters, no code generation, nothing that can drift out of sync with
/// the models.
class LocalStore implements KeyValueStore {
  LocalStore._(this._box);

  static const String boxName = 'morphcook';

  final Box<String> _box;

  static Future<LocalStore> open() async {
    await Hive.initFlutter();
    final box = await Hive.openBox<String>(boxName);
    return LocalStore._(box);
  }

  @override
  String? readString(String key) => _box.get(key);

  @override
  Future<void> writeString(String key, String value) =>
      _box.put(key, value);

  @override
  Future<void> delete(String key) => _box.delete(key);

  @override
  bool contains(String key) => _box.containsKey(key);

  /// Reads a JSON array of objects.
  @override
  List<Map<String, dynamic>> readList(String key) {
    final raw = _box.get(key);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  @override
  Future<void> writeList(String key, List<Map<String, dynamic>> value) =>
      _box.put(key, jsonEncode(value));

  /// Reads a JSON object.
  @override
  Map<String, dynamic> readMap(String key) {
    final raw = _box.get(key);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) =>
      _box.put(key, jsonEncode(value));

  Future<void> close() => _box.close();
}

/// The keys used inside the local store.
abstract final class StoreKeys {
  const StoreKeys._();

  static const String cookbook = 'cookbook.saved';
  static const String mealPlan = 'mealplan.weeks';
  static const String history = 'history.entries';
  static const String shoppingSelected = 'shopping.selected';
  static const String shoppingChecked = 'shopping.checked';
  static const String shoppingNotes = 'shopping.notes';
  static const String contentRequests = 'content.requests';
  static const String cookProgress = 'cook.progress';
  static const String settings = 'settings.flags';
}
