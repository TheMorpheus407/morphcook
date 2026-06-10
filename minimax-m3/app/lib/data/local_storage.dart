import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A thin wrapper around SharedPreferences for primitives and a per-collection
/// JSON-on-disk strategy for larger structured state (cookbook, history,
/// meal plan, shopping list, content requests).
class LocalStorage {
  LocalStorage._(this._prefs, this._dir);

  final SharedPreferences _prefs;
  final Directory _dir;

  static LocalStorage? _instance;

  static Future<LocalStorage> instance() async {
    if (_instance != null) return _instance!;
    final prefs = await SharedPreferences.getInstance();
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/morphcook');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _instance = LocalStorage._(prefs, dir);
    return _instance!;
  }

  SharedPreferences get prefs => _prefs;

  File _fileFor(String key) => File('${_dir.path}/$key.json');

  Future<Map<String, dynamic>?> readJsonMap(String key) async {
    final f = _fileFor(key);
    if (!f.existsSync()) return null;
    try {
      final content = await f.readAsString();
      if (content.isEmpty) return null;
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<dynamic>?> readJsonList(String key) async {
    final f = _fileFor(key);
    if (!f.existsSync()) return null;
    try {
      final content = await f.readAsString();
      if (content.isEmpty) return null;
      final decoded = jsonDecode(content);
      if (decoded is List) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeJson(String key, Object value) async {
    final f = _fileFor(key);
    await f.writeAsString(jsonEncode(value), flush: true);
  }

  Future<void> delete(String key) async {
    final f = _fileFor(key);
    if (f.existsSync()) {
      await f.delete();
    }
  }

  Directory get directory => _dir;
}

/// Loads a bundled asset JSON.
Future<Map<String, dynamic>> loadJsonAsset(String path) async {
  final raw = await rootBundle.loadString(path);
  return jsonDecode(raw) as Map<String, dynamic>;
}
