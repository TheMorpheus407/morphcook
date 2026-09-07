import 'dart:convert';

/// Minimal key/value persistence for collections (saved, history, meal
/// plan, shopping list, cook progress). Values are JSON-encodable.
abstract class KeyValueStore {
  Future<void> init();
  Object? get(String key);
  Future<void> put(String key, Object? value);
  Future<void> delete(String key);
  Iterable<String> get keys;
  Future<void> clear();
}

class InMemoryStore implements KeyValueStore {
  final Map<String, String> _data = {};

  @override
  Future<void> init() async {}

  @override
  Object? get(String key) {
    final raw = _data[key];
    return raw == null ? null : jsonDecode(raw);
  }

  @override
  Future<void> put(String key, Object? value) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = jsonEncode(value);
    }
  }

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Iterable<String> get keys => _data.keys;

  @override
  Future<void> clear() async => _data.clear();
}

/// Profile lives in shared_preferences (small, read at startup).
abstract class ProfileStore {
  Future<Map<String, dynamic>?> load();
  Future<void> save(Map<String, dynamic> json);
  Future<String?> getFlag(String key);
  Future<void> setFlag(String key, String? value);
}

class InMemoryProfileStore implements ProfileStore {
  Map<String, dynamic>? _profile;
  final Map<String, String> _flags = {};

  @override
  Future<Map<String, dynamic>?> load() async => _profile;

  @override
  Future<void> save(Map<String, dynamic> json) async => _profile = Map.of(json);

  @override
  Future<String?> getFlag(String key) async => _flags[key];

  @override
  Future<void> setFlag(String key, String? value) async {
    if (value == null) {
      _flags.remove(key);
    } else {
      _flags[key] = value;
    }
  }
}
