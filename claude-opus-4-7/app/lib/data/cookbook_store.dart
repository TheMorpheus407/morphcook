import 'package:flutter/foundation.dart';
import 'json_file_store.dart';

/// Saved variants. The user saves a specific recipe id, not a dish — per SPEC.
class CookbookStore extends ChangeNotifier {
  final _store = JsonFileStore('cookbook.json');
  final List<_SavedEntry> _entries = [];
  bool _loaded = false;

  Future<void> load() async {
    final raw = await _store.read(fallback: const []);
    _entries.clear();
    for (final e in (raw as List)) {
      if (e is String) {
        _entries.add(_SavedEntry(recipeId: e, savedAt: DateTime.now()));
      } else if (e is Map) {
        _entries.add(_SavedEntry.fromJson(e.cast<String, dynamic>()));
      }
    }
    _entries.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    _loaded = true;
    notifyListeners();
  }

  bool get loaded => _loaded;
  List<String> get savedRecipeIds =>
      _entries.map((e) => e.recipeId).toList(growable: false);

  bool contains(String recipeId) =>
      _entries.any((e) => e.recipeId == recipeId);

  Future<void> toggle(String recipeId) async {
    if (contains(recipeId)) {
      _entries.removeWhere((e) => e.recipeId == recipeId);
    } else {
      _entries.insert(
          0, _SavedEntry(recipeId: recipeId, savedAt: DateTime.now()));
    }
    await _persist();
  }

  Future<void> add(String recipeId) async {
    if (contains(recipeId)) return;
    _entries.insert(0, _SavedEntry(recipeId: recipeId, savedAt: DateTime.now()));
    await _persist();
  }

  Future<void> remove(String recipeId) async {
    _entries.removeWhere((e) => e.recipeId == recipeId);
    await _persist();
  }

  Future<void> replaceAll(List<String> ids) async {
    _entries
      ..clear()
      ..addAll(ids.map(
          (id) => _SavedEntry(recipeId: id, savedAt: DateTime.now())));
    await _persist();
  }

  Future<void> _persist() async {
    await _store.write(_entries.map((e) => e.toJson()).toList());
    notifyListeners();
  }
}

class _SavedEntry {
  final String recipeId;
  final DateTime savedAt;
  const _SavedEntry({required this.recipeId, required this.savedAt});
  Map<String, dynamic> toJson() =>
      {'recipe_id': recipeId, 'saved_at': savedAt.toUtc().toIso8601String()};
  factory _SavedEntry.fromJson(Map<String, dynamic> j) => _SavedEntry(
      recipeId: j['recipe_id'] as String,
      savedAt: DateTime.parse(j['saved_at'] as String));
}
