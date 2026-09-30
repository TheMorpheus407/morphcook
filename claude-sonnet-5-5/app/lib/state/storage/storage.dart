import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small flags and the profile (backed by `shared_preferences`).
abstract class KeyValueStore {
  String? getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
  Iterable<String> get keys;
}

class SharedPrefsStore implements KeyValueStore {
  SharedPrefsStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) => _prefs.setString(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);

  @override
  Iterable<String> get keys => _prefs.getKeys();
}

class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _values = <String, String>{};

  @override
  String? getString(String key) => _values[key];

  @override
  Future<void> setString(String key, String value) async => _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);

  @override
  Iterable<String> get keys => _values.keys;
}

/// A collection of JSON records keyed by string (saved, history, meal plan ...).
abstract class RecordBox {
  String? get(String key);
  Future<void> put(String key, String value);
  Future<void> delete(String key);
  Future<void> clear();
  Iterable<String> get keys;
  int get length;

  Iterable<MapEntry<String, String>> get entries sync* {
    for (final key in keys) {
      final value = get(key);
      if (value != null) yield MapEntry(key, value);
    }
  }

  Map<String, dynamic>? getJson(String key) {
    final raw = get(key);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  Future<void> putJson(String key, Map<String, dynamic> value) => put(key, jsonEncode(value));
}

abstract class RecordStore {
  Future<RecordBox> open(String name);
}

class MemoryRecordBox extends RecordBox {
  final Map<String, String> _values = <String, String>{};

  @override
  String? get(String key) => _values[key];

  @override
  Future<void> put(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<void> clear() async => _values.clear();

  @override
  Iterable<String> get keys => _values.keys.toList();

  @override
  int get length => _values.length;
}

class MemoryRecordStore implements RecordStore {
  final Map<String, MemoryRecordBox> _boxes = <String, MemoryRecordBox>{};

  @override
  Future<RecordBox> open(String name) async => _boxes.putIfAbsent(name, MemoryRecordBox.new);
}

class HiveRecordBox extends RecordBox {
  HiveRecordBox(this._box);

  final Box<String> _box;

  @override
  String? get(String key) => _box.get(key);

  @override
  Future<void> put(String key, String value) => _box.put(key, value);

  @override
  Future<void> delete(String key) => _box.delete(key);

  @override
  Future<void> clear() async {
    await _box.clear();
  }

  @override
  Iterable<String> get keys => _box.keys.map((k) => k.toString()).toList();

  @override
  int get length => _box.length;
}

class HiveRecordStore implements RecordStore {
  HiveRecordStore._();

  /// Uses the app documents folder (Android/iOS).
  static Future<HiveRecordStore> initFlutter() async {
    await Hive.initFlutter('morphcook');
    return HiveRecordStore._();
  }

  /// Uses [path], for tests and tools.
  static HiveRecordStore initAt(String path) {
    Hive.init(path);
    return HiveRecordStore._();
  }

  @override
  Future<RecordBox> open(String name) async => HiveRecordBox(await Hive.openBox<String>(name));
}

/// Names of the record collections.
class Boxes {
  const Boxes._();

  static const String saved = 'saved';
  static const String history = 'history';
  static const String mealPlan = 'meal_plan';
  static const String shopping = 'shopping';
  static const String shoppingEvents = 'shopping_events';
  static const String contentRequests = 'content_requests';
  static const String cookSession = 'cook_session';
}

/// Everything persistent the app owns.
class AppStorage {
  AppStorage({required this.prefs, required this.records});

  final KeyValueStore prefs;
  final RecordStore records;

  /// `shared_preferences` plus Hive in the app documents folder.
  static Future<AppStorage> openDefault() async {
    final prefs = await SharedPreferences.getInstance();
    return AppStorage(prefs: SharedPrefsStore(prefs), records: await HiveRecordStore.initFlutter());
  }

  /// Nothing touches disk. For tests.
  static AppStorage memory() => AppStorage(prefs: MemoryKeyValueStore(), records: MemoryRecordStore());
}
