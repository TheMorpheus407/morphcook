import 'package:flutter/foundation.dart';

import '../models/shopping_list_item.dart';
import 'local_storage.dart';

class ShoppingListRepository extends ChangeNotifier {
  ShoppingListRepository._(this._storage, this._items);

  final LocalStorage _storage;
  final List<ShoppingListItem> _items;

  static const _key = 'shopping_list';

  static Future<ShoppingListRepository> load(LocalStorage storage) async {
    final raw = await storage.readJsonList(_key);
    final items = <ShoppingListItem>[];
    if (raw != null) {
      for (final r in raw) {
        if (r is Map<String, dynamic>) {
          items.add(ShoppingListItem.fromJson(r));
        }
      }
    }
    return ShoppingListRepository._(storage, items);
  }

  List<ShoppingListItem> get items => List.unmodifiable(_items);

  Future<void> addAll(Iterable<ShoppingListItem> items) async {
    for (final inc in items) {
      final i = _items.indexWhere(
          (e) => e.ingredientId == inc.ingredientId && e.unit == inc.unit);
      if (i >= 0) {
        final existing = _items[i];
        _items[i] = existing.copyWith(
          qty: existing.qty + inc.qty,
          sourceRecipeIds: {...existing.sourceRecipeIds, ...inc.sourceRecipeIds},
        );
      } else {
        _items.add(inc);
      }
    }
    await _persist();
  }

  Future<void> toggleChecked(int index) async {
    if (index < 0 || index >= _items.length) return;
    _items[index] = _items[index].copyWith(checked: !_items[index].checked);
    await _persist();
  }

  Future<void> removeAt(int index) async {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    await _persist();
  }

  Future<void> clearChecked() async {
    _items.removeWhere((e) => e.checked);
    await _persist();
  }

  Future<void> clearAll() async {
    _items.clear();
    await _persist();
  }

  Future<void> _persist() async {
    await _storage.writeJson(_key, _items.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  Map<String, List<ShoppingListItem>> groupedByAisle() {
    final out = <String, List<ShoppingListItem>>{};
    for (final i in _items) {
      out.putIfAbsent(i.aisle, () => []).add(i);
    }
    return out;
  }
}
