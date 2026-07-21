import '../models/recipe.dart';
import '../models/user_data.dart';

class ShoppingAggregator {
  const ShoppingAggregator._();

  static List<ShoppingItem> addRecipes(
    Iterable<ShoppingItem> existing,
    Iterable<Recipe> recipes, {
    Map<String, int> servings = const {},
  }) {
    final result = <String, ShoppingItem>{};
    for (final item in existing) {
      result[_key(item.ingredientId, item.unit)] = item;
    }
    for (final recipe in recipes) {
      final targetServings = servings[recipe.id] ?? recipe.servings;
      final scale = targetServings / recipe.servings;
      for (final ingredient in recipe.ingredients) {
        final normalized = _normalize(
          ingredient.quantity * scale,
          ingredient.unit,
          volumeConvertible: ingredient.volumeConvertible,
        );
        final key = _key(ingredient.id, normalized.unit);
        final current = result[key];
        if (current == null) {
          result[key] = ShoppingItem(
            ingredientId: ingredient.id,
            name: ingredient.name,
            quantity: normalized.quantity,
            unit: normalized.unit,
            aisle: ingredient.aisle,
          );
        } else {
          result[key] = current.copyWith(
            quantity: current.quantity + normalized.quantity,
            frequency: current.frequency + 1,
          );
        }
      }
    }
    final items = result.values.toList();
    items.sort((a, b) {
      final aisle = a.aisle.compareTo(b.aisle);
      return aisle != 0 ? aisle : a.ingredientId.compareTo(b.ingredientId);
    });
    return items;
  }

  static _NormalizedAmount _normalize(
    double quantity,
    String unit, {
    required bool volumeConvertible,
  }) {
    if (volumeConvertible) {
      switch (unit) {
        case 'l':
          return _NormalizedAmount(quantity * 1000, 'ml');
        case 'tbsp':
          return _NormalizedAmount(quantity * 15, 'ml');
        case 'tsp':
          return _NormalizedAmount(quantity * 5, 'ml');
        case 'ml':
          return _NormalizedAmount(quantity, 'ml');
      }
    }
    if (unit == 'kg') return _NormalizedAmount(quantity * 1000, 'g');
    return _NormalizedAmount(quantity, unit);
  }

  static String _key(String ingredientId, String unit) => '$ingredientId|$unit';
}

class _NormalizedAmount {
  const _NormalizedAmount(this.quantity, this.unit);
  final double quantity;
  final String unit;
}
