import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal key-value persistence. Values are JSON-encodable.
abstract class KvStore {
  Object? read(String key);
  Future<void> write(String key, Object? value);
  Future<void> remove(String key);
}

/// Hive box for the growing collections: saved, history, meal plan,
/// shopping list, insight log. Values are stored as JSON strings so no type
/// adapters are needed and the backup is a straight copy.
class HiveKvStore implements KvStore {
  HiveKvStore._(this._box);

  static Future<HiveKvStore> open({String name = 'morphcook_library'}) async {
    await Hive.initFlutter();
    return HiveKvStore._(await Hive.openBox<String>(name));
  }

  final Box<String> _box;

  @override
  Object? read(String key) {
    final raw = _box.get(key);
    return raw == null ? null : jsonDecode(raw);
  }

  @override
  Future<void> write(String key, Object? value) => _box.put(key, jsonEncode(value));

  @override
  Future<void> remove(String key) => _box.delete(key);
}

/// shared_preferences for the profile and small flags.
class PrefsKvStore implements KvStore {
  PrefsKvStore._(this._prefs);

  static Future<PrefsKvStore> open() async => PrefsKvStore._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  @override
  Object? read(String key) {
    final raw = _prefs.getString(key);
    return raw == null ? null : jsonDecode(raw);
  }

  @override
  Future<void> write(String key, Object? value) => _prefs.setString(key, jsonEncode(value));

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}

class MemoryKvStore implements KvStore {
  final Map<String, String> data = {};

  @override
  Object? read(String key) => data[key] == null ? null : jsonDecode(data[key]!);

  @override
  Future<void> write(String key, Object? value) async => data[key] = jsonEncode(value);

  @override
  Future<void> remove(String key) async => data.remove(key);
}
