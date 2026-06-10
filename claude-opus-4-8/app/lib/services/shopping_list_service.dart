import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// A recipe queued onto the shopping list, with the servings the user wants.
class ShoppingSelection {
  ShoppingSelection(this.recipeId, this.servings);
  final String recipeId;
  final int servings;
  Map<String, dynamic> toJson() => {'recipe_id': recipeId, 'servings': servings};
  factory ShoppingSelection.fromJson(Map j) =>
      ShoppingSelection(j['recipe_id'] as String, (j['servings'] as num).toInt());
}

/// Holds which recipes/servings feed the smart shopping list plus the
/// checked-off line ids. Aggregation itself lives in [ShoppingAggregator].
class ShoppingListService extends ChangeNotifier {
  ShoppingListService(this._box);
  static const _selKey = 'selections';
  static const _checkedKey = 'checked';
  final Box _box;

  List<ShoppingSelection> selections() {
    final raw = (_box.get(_selKey) as List?) ?? const [];
    return raw.map((e) => ShoppingSelection.fromJson(e as Map)).toList();
  }

  Set<String> checkedIngredientIds() =>
      ((_box.get(_checkedKey) as List?) ?? const []).cast<String>().toSet();

  bool contains(String recipeId) =>
      selections().any((s) => s.recipeId == recipeId);

  Future<void> _save(List<ShoppingSelection> sels) async {
    await _box.put(_selKey, sels.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  Future<void> addRecipe(String recipeId, int servings) async {
    final sels = selections();
    final idx = sels.indexWhere((s) => s.recipeId == recipeId);
    if (idx >= 0) {
      sels[idx] = ShoppingSelection(recipeId, servings);
    } else {
      sels.add(ShoppingSelection(recipeId, servings));
    }
    await _save(sels);
  }

  Future<void> addMany(Map<String, int> servingsByRecipe) async {
    final sels = selections();
    for (final entry in servingsByRecipe.entries) {
      final idx = sels.indexWhere((s) => s.recipeId == entry.key);
      if (idx >= 0) {
        sels[idx] = ShoppingSelection(entry.key, entry.value);
      } else {
        sels.add(ShoppingSelection(entry.key, entry.value));
      }
    }
    await _save(sels);
  }

  Future<void> removeRecipe(String recipeId) async {
    await _save(selections()..removeWhere((s) => s.recipeId == recipeId));
  }

  Future<void> setServings(String recipeId, int servings) =>
      addRecipe(recipeId, servings);

  Future<void> toggleChecked(String ingredientId) async {
    final checked = checkedIngredientIds();
    if (!checked.add(ingredientId)) checked.remove(ingredientId);
    await _box.put(_checkedKey, checked.toList());
    notifyListeners();
  }

  Future<void> clear() async {
    await _box.delete(_selKey);
    await _box.delete(_checkedKey);
    notifyListeners();
  }
}
