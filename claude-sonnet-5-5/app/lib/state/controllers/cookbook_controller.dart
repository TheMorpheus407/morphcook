import 'package:flutter/foundation.dart';

import '../../core/pagination/pagination_controller.dart';
import '../storage/storage.dart';

/// A saved variant. Cookbook entries are recipe ids, not dishes: you save
/// *your* Döner.
class SavedRecipe {
  const SavedRecipe({required this.recipeId, required this.savedAt});

  final String recipeId;
  final DateTime savedAt;
}

class CookbookController extends ChangeNotifier {
  CookbookController._(this._box) {
    _load();
  }

  static Future<CookbookController> open(AppStorage storage) async {
    return CookbookController._(await storage.records.open(Boxes.saved));
  }

  final RecordBox _box;
  final List<SavedRecipe> _saved = <SavedRecipe>[];

  /// Newest first.
  List<SavedRecipe> get saved => List<SavedRecipe>.unmodifiable(_saved);
  int get count => _saved.length;

  bool isSaved(String recipeId) => _saved.any((s) => s.recipeId == recipeId);

  void _load() {
    for (final entry in _box.entries) {
      final json = _box.getJson(entry.key);
      final at = DateTime.tryParse((json?['saved_at'] as String?) ?? '');
      if (json != null && at != null) _saved.add(SavedRecipe(recipeId: entry.key, savedAt: at.toLocal()));
    }
    _sort();
  }

  void _sort() => _saved.sort((a, b) {
    final byDate = b.savedAt.compareTo(a.savedAt);
    return byDate != 0 ? byDate : a.recipeId.compareTo(b.recipeId);
  });

  Future<void> save(String recipeId, {DateTime? at}) async {
    if (isSaved(recipeId)) return;
    final when = at ?? DateTime.now();
    _saved.add(SavedRecipe(recipeId: recipeId, savedAt: when));
    _sort();
    notifyListeners();
    await _box.putJson(recipeId, <String, dynamic>{'saved_at': when.toUtc().toIso8601String()});
  }

  Future<void> remove(String recipeId) async {
    final before = _saved.length;
    _saved.removeWhere((s) => s.recipeId == recipeId);
    if (_saved.length == before) return;
    notifyListeners();
    await _box.delete(recipeId);
  }

  Future<void> toggle(String recipeId) => isSaved(recipeId) ? remove(recipeId) : save(recipeId);

  /// Offset-based page, newest first.
  OffsetPage<SavedRecipe> page(int offset, int limit) {
    final end = (offset + limit).clamp(0, _saved.length);
    final start = offset.clamp(0, _saved.length);
    return OffsetPage<SavedRecipe>(_saved.sublist(start, end), total: _saved.length);
  }

  /// Restores from a backup. Merge keeps what is already here.
  Future<void> restore(Iterable<SavedRecipe> items, {required bool replace}) async {
    if (replace) {
      _saved.clear();
      await _box.clear();
    }
    for (final item in items) {
      if (!isSaved(item.recipeId)) {
        _saved.add(item);
        await _box.putJson(item.recipeId, <String, dynamic>{'saved_at': item.savedAt.toUtc().toIso8601String()});
      }
    }
    _sort();
    notifyListeners();
  }

  Future<void> clear() async {
    _saved.clear();
    await _box.clear();
    notifyListeners();
  }
}
