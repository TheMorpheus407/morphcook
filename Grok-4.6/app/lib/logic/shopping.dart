import '../models/collections.dart';
import '../models/ingredient.dart';
import '../models/recipe.dart';
import 'units.dart';

class AggregatedItem {
  final String ingredientId;
  final Quantity quantity;
  final String aisle;

  const AggregatedItem({
    required this.ingredientId,
    required this.quantity,
    required this.aisle,
  });
}

List<AggregatedItem> aggregate(
  Iterable<(Recipe, double)> recipesWithServingFactor,
  IngredientDictionary dictionary,
) {
  final buckets = <String, ({String ingredientId, Quantity qty})>{};

  for (final (recipe, factor) in recipesWithServingFactor) {
    for (final ing in recipe.ingredients) {
      final qty = Quantity(ing.qty * factor, ing.unit);
      final family = qty.def.family;
      final key = family == UnitFamily.count
          ? '${ing.ingredientId}|count|${ing.unit}'
          : '${ing.ingredientId}|${family.name}';
      final existing = buckets[key];
      buckets[key] = existing == null
          ? (ingredientId: ing.ingredientId, qty: qty)
          : (ingredientId: ing.ingredientId, qty: existing.qty + qty);
    }
  }

  final items = buckets.values
      .map(
        (b) => AggregatedItem(
          ingredientId: b.ingredientId,
          quantity: b.qty,
          aisle: dictionary.aisleOf(b.ingredientId),
        ),
      )
      .toList();

  items.sort((a, b) {
    final aisle = a.aisle.compareTo(b.aisle);
    if (aisle != 0) return aisle;
    return a.ingredientId.compareTo(b.ingredientId);
  });
  return items;
}

Map<String, List<AggregatedItem>> groupByAisle(List<AggregatedItem> items) {
  final out = <String, List<AggregatedItem>>{};
  for (final item in items) {
    out.putIfAbsent(item.aisle, () => []).add(item);
  }
  return out;
}

List<ShoppingItem> mergeIntoList(
  List<ShoppingItem> existing,
  List<AggregatedItem> additions,
  DateTime addedAt,
) {
  final result = List<ShoppingItem>.from(existing);
  for (final add in additions) {
    final addQty = add.quantity;
    final idx = result.indexWhere(
      (item) =>
          item.ingredientId == add.ingredientId &&
          !item.checked &&
          Quantity(item.qty, item.unit).canAddTo(addQty),
    );
    if (idx >= 0) {
      final merged = Quantity(result[idx].qty, result[idx].unit) + addQty;
      result[idx] = result[idx].copyWith(qty: merged.amount, unit: merged.unit);
    } else {
      result.add(
        ShoppingItem(
          ingredientId: add.ingredientId,
          qty: addQty.amount,
          unit: addQty.unit,
          aisle: add.aisle,
          addedAt: addedAt,
        ),
      );
    }
  }
  return result;
}
