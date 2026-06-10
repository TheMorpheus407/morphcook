import 'package:flutter/foundation.dart';
import '../models/recipe.dart';
import '../models/meal_plan.dart';
import 'json_file_store.dart';

/// Smart shopping list with unit-aware aggregation.
/// "garlic 2 cloves + garlic 3 cloves = 5 cloves";
/// ml ↔ tbsp ↔ tsp conversion within volume.
class ShoppingListStore extends ChangeNotifier {
  final _store = JsonFileStore('shopping_list.json');
  final List<ShoppingItem> _items = [];
  bool _loaded = false;

  bool get loaded => _loaded;
  List<ShoppingItem> get items => List.unmodifiable(_items);

  Future<void> load() async {
    final raw = await _store.read(fallback: const []);
    _items.clear();
    for (final e in (raw as List)) {
      _items.add(ShoppingItem.fromJson((e as Map).cast<String, dynamic>()));
    }
    _loaded = true;
    notifyListeners();
  }

  /// Add all ingredients from a list of recipes (scaled by servings ratio).
  Future<int> addRecipes(
    Iterable<Recipe> recipes, {
    Map<String, int>? servingsByRecipe,
  }) async {
    final added = <String, ShoppingItem>{};
    // existing items keyed by (ingredient id, canonical unit)
    final existing = {for (final i in _items) _key(i.ingredientId, i.unit): i};

    for (final r in recipes) {
      final scale = (servingsByRecipe?[r.id] ?? r.servings) / r.servings;
      for (final ing in r.ingredients) {
        final unit = _canonical(ing.unit);
        final amount = _toCanonical(ing.amount * scale, ing.unit);
        final key = _key(ing.id, unit);
        final dn = ing.name.get('en'); // raw EN as display; localized at render
        if (existing.containsKey(key)) {
          final cur = existing[key]!;
          existing[key] = cur.copyWith(
            amount: cur.amount + amount,
            sourceRecipeIds: {...cur.sourceRecipeIds, r.id}.toList(),
          );
        } else if (added.containsKey(key)) {
          final cur = added[key]!;
          added[key] = cur.copyWith(
            amount: cur.amount + amount,
            sourceRecipeIds: {...cur.sourceRecipeIds, r.id}.toList(),
          );
        } else {
          added[key] = ShoppingItem(
            ingredientId: ing.id,
            displayName: dn,
            amount: amount,
            unit: unit,
            aisle: ing.aisle,
            sourceRecipeIds: [r.id],
          );
        }
      }
    }

    // merge existing back
    _items
      ..clear()
      ..addAll(existing.values)
      ..addAll(added.values);
    await _persist();
    return added.length;
  }

  Future<void> toggleChecked(String key) async {
    final idx = _items.indexWhere((i) => _key(i.ingredientId, i.unit) == key);
    if (idx == -1) return;
    _items[idx] = _items[idx].copyWith(checked: !_items[idx].checked);
    await _persist();
  }

  Future<void> remove(String key) async {
    _items.removeWhere((i) => _key(i.ingredientId, i.unit) == key);
    await _persist();
  }

  Future<void> clearChecked() async {
    _items.removeWhere((i) => i.checked);
    await _persist();
  }

  Future<void> clear() async {
    _items.clear();
    await _persist();
  }

  Future<void> _persist() async {
    await _store.write(_items.map((i) => i.toJson()).toList());
    notifyListeners();
  }

  /// Group items by aisle.
  Map<String, List<ShoppingItem>> groupedByAisle() {
    final out = <String, List<ShoppingItem>>{};
    for (final i in _items) {
      final a = i.aisle ?? 'other';
      out.putIfAbsent(a, () => []).add(i);
    }
    return out;
  }

  static String _key(String id, String unit) => '$id|${_canonical(unit)}';

  /// Map related units to a canonical key per category.
  static String _canonical(String unit) {
    final u = unit.toLowerCase().trim();
    const volume = {'ml', 'tbsp', 'tsp', 'cup', 'cups', 'tablespoon', 'teaspoon'};
    const mass = {'g', 'kg', 'gram', 'grams', 'kilogram'};
    if (volume.contains(u)) return 'ml';
    if (mass.contains(u)) return 'g';
    if (u == 'cloves' || u == 'clove') return 'cloves';
    if (u == 'pcs' || u == 'pc' || u == 'piece' || u == 'pieces') return 'pcs';
    if (u == 'pinch') return 'pinch';
    return u.isEmpty ? 'pcs' : u;
  }

  static double _toCanonical(double amount, String unit) {
    final u = unit.toLowerCase().trim();
    if (u == 'tbsp' || u == 'tablespoon') return amount * 15;
    if (u == 'tsp' || u == 'teaspoon') return amount * 5;
    if (u == 'cup' || u == 'cups') return amount * 240;
    if (u == 'kg' || u == 'kilogram') return amount * 1000;
    return amount;
  }
}
