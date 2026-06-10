import 'package:flutter/foundation.dart';

import 'local_storage.dart';

/// Saved (cookbook) — a list of recipe ids in save order, most recent first.
class CookbookRepository extends ChangeNotifier {
  CookbookRepository._(this._storage, this._items);

  final LocalStorage _storage;
  final List<_SavedItem> _items;

  static const _key = 'cookbook';

  static Future<CookbookRepository> load(LocalStorage storage) async {
    final raw = await storage.readJsonList(_key);
    final items = <_SavedItem>[];
    if (raw != null) {
      for (final r in raw) {
        if (r is Map<String, dynamic>) {
          items.add(_SavedItem.fromJson(r));
        }
      }
    }
    return CookbookRepository._(storage, items);
  }

  List<String> get savedRecipeIds =>
      _items.map((e) => e.recipeId).toList(growable: false);

  DateTime? savedAt(String id) =>
      _items.where((e) => e.recipeId == id).cast<_SavedItem?>().firstOrNull?.savedAt;

  bool contains(String id) => _items.any((e) => e.recipeId == id);

  Future<void> toggle(String id) async {
    if (contains(id)) {
      _items.removeWhere((e) => e.recipeId == id);
    } else {
      _items.insert(0, _SavedItem(recipeId: id, savedAt: DateTime.now()));
    }
    await _persist();
  }

  Future<void> _persist() async {
    await _storage.writeJson(_key, _items.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  /// Pagination-friendly slice: offset-based, sorted by savedAt desc.
  List<String> page({required int offset, required int limit}) {
    final sorted = [..._items]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return sorted
        .skip(offset)
        .take(limit)
        .map((e) => e.recipeId)
        .toList(growable: false);
  }

  int get total => _items.length;

  /// For backup export/import.
  List<Map<String, dynamic>> toBackup() => _items.map((e) => e.toJson()).toList();
  Future<void> replaceFromBackup(Iterable<dynamic> raw) async {
    _items
      ..clear()
      ..addAll(
        raw.whereType<Map<String, dynamic>>().map(_SavedItem.fromJson),
      );
    await _persist();
  }
}

class _SavedItem {
  final String recipeId;
  final DateTime savedAt;

  const _SavedItem({required this.recipeId, required this.savedAt});

  Map<String, dynamic> toJson() => {
        'recipe_id': recipeId,
        'saved_at': savedAt.toIso8601String(),
      };

  factory _SavedItem.fromJson(Map<String, dynamic> json) => _SavedItem(
        recipeId: json['recipe_id'] as String,
        savedAt:
            DateTime.tryParse(json['saved_at'] as String? ?? '') ?? DateTime.now(),
      );
}

extension _F<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
