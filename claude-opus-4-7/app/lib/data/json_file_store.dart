import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Tiny JSON-file persistence layer for collections.
/// Each store owns one file under the app documents directory.
class JsonFileStore {
  final String filename;
  JsonFileStore(this.filename);

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$filename');
  }

  Future<dynamic> read({dynamic fallback}) async {
    try {
      final f = await _file();
      if (!await f.exists()) return fallback;
      final raw = await f.readAsString();
      if (raw.isEmpty) return fallback;
      return json.decode(raw);
    } catch (e) {
      debugPrint('JsonFileStore[$filename] read failed: $e');
      return fallback;
    }
  }

  Future<void> write(dynamic data) async {
    final f = await _file();
    await f.writeAsString(json.encode(data));
  }

  Future<void> clear() async {
    final f = await _file();
    if (await f.exists()) await f.delete();
  }
}
