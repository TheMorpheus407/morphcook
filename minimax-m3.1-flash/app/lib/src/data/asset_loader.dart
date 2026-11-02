import 'dart:convert';

import 'package:flutter/services.dart';

/// Thin wrapper over the asset bundle so the rest of the app never touches
/// `rootBundle` directly and every JSON document is decoded exactly once.
class AssetLoader {
  AssetLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final Map<String, Future<Map<String, dynamic>>> _cache =
      <String, Future<Map<String, dynamic>>>{};

  Future<Map<String, dynamic>> loadJson(String path) {
    return _cache.putIfAbsent(path, () async {
      final raw = await _bundle.loadString(path);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw FormatException('Expected a JSON object in $path');
      }
      return decoded;
    });
  }

  Future<List<dynamic>> loadJsonList(String path) async {
    final raw = await _bundle.loadString(path);
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw FormatException('Expected a JSON array in $path');
    }
    return decoded;
  }
}
