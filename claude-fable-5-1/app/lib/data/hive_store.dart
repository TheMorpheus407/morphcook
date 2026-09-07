import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_store.dart';

/// Hive-backed collections store. Values are stored as JSON strings so no
/// type adapters are needed and the on-disk format stays human-debuggable.
class HiveStore implements KeyValueStore {
  HiveStore({this.boxName = 'morphcook'});
  final String boxName;
  Box<String>? _box;

  @override
  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(boxName);
  }

  Box<String> get _b => _box ?? (throw StateError('HiveStore not initialised'));

  @override
  Object? get(String key) {
    final raw = _b.get(key);
    return raw == null ? null : jsonDecode(raw);
  }

  @override
  Future<void> put(String key, Object? value) =>
      value == null ? _b.delete(key) : _b.put(key, jsonEncode(value));

  @override
  Future<void> delete(String key) => _b.delete(key);

  @override
  Iterable<String> get keys => _b.keys.cast<String>();

  @override
  Future<void> clear() async {
    await _b.clear();
  }
}

class PrefsProfileStore implements ProfileStore {
  static const _profileKey = 'profile.v1';

  @override
  Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(Map<String, dynamic> json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(json));
  }

  @override
  Future<String?> getFlag(String key) async => (await SharedPreferences.getInstance()).getString('flag.$key');

  @override
  Future<void> setFlag(String key, String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove('flag.$key');
    } else {
      await prefs.setString('flag.$key', value);
    }
  }
}
