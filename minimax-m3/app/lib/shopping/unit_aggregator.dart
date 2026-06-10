import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/shopping_list_item.dart';
import 'units.dart';

/// Aggregates per-recipe ingredients into a deduplicated shopping list.
///
/// - Same id + compatible unit family → sum, converting to a base unit
///   then prettifying (e.g. 1500 g → 1.5 kg, 1500 ml → 1.5 l).
/// - Same id, incompatible units → two separate items.
/// - Items are grouped by aisle.
class ShoppingAggregator {
  final IngredientTree ingredientTree;

  const ShoppingAggregator(this.ingredientTree);

  List<ShoppingListItem> aggregate(
    Map<String, double> recipeIdToServingMultiplier,
    List<Recipe> recipes, {
    DateTime? now,
  }) {
    final nowTs = now ?? DateTime.now();
    // Bucket by (id, unit-family-key). For mass we use 'g', volume 'ml',
    // count keeps the actual unit string.
    final buckets = <String, _Bucket>{};

    for (final recipe in recipes) {
      final multiplier = recipeIdToServingMultiplier[recipe.id] ?? 1.0;
      for (final ing in recipe.ingredients) {
        final scaled = ing.qty * multiplier;
        final info = Units.info(ing.unit);
        final familyKey = info == null
            ? ing.unit
            : switch (info.family) {
                UnitFamily.mass => 'g',
                UnitFamily.volume => 'ml',
                UnitFamily.count => ing.unit,
                UnitFamily.none => ing.unit,
              };
        final key = '${ing.id}|$familyKey';
        final converted = info == null
            ? scaled
            : (Units.convert(scaled, ing.unit, familyKey) ?? scaled);
        final existing = buckets[key];
        if (existing == null) {
          buckets[key] = _Bucket(
            ingredientId: ing.id,
            name: ing.name,
            qty: converted,
            baseUnit: familyKey,
            sources: {recipe.id},
          );
        } else {
          existing.qty += converted;
          existing.sources.add(recipe.id);
        }
      }
    }

    final items = <ShoppingListItem>[];
    for (final b in buckets.values) {
      final (qty, unit) = Units.prettify(b.qty, b.baseUnit);
      items.add(
        ShoppingListItem(
          ingredientId: b.ingredientId,
          name: b.name,
          qty: qty,
          unit: unit,
          aisle: ingredientTree.aisleFor(b.ingredientId),
          checked: false,
          sourceRecipeIds: b.sources,
          addedAt: nowTs,
        ),
      );
    }
    // Stable order: aisle, then name (en).
    items.sort((a, b) {
      final byAisle = a.aisle.compareTo(b.aisle);
      if (byAisle != 0) return byAisle;
      return a.name.resolve('en').compareTo(b.name.resolve('en'));
    });
    return items;
  }
}

class _Bucket {
  final String ingredientId;
  final dynamic name; // I18nString — kept lazily
  double qty;
  final String baseUnit;
  final Set<String> sources;

  _Bucket({
    required this.ingredientId,
    required this.name,
    required this.qty,
    required this.baseUnit,
    required this.sources,
  });
}
