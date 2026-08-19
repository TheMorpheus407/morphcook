/// Smart shopping list: unit-aware aggregation across recipes.
///
/// - same ingredient + convertible units (ml ↔ tbsp ↔ tsp …) merge into one
///   base quantity and re-render in the friendliest unit
/// - count ingredients merge as piece/clove/stick per their node unit_type
/// - everything groups by supermarket aisle, sorted within the aisle
library;

import '../data/models.dart';
import 'units.dart';

class ShoppingItem {
  final String ingredientId;
  final double baseAmount; // in the kind's base unit (g / ml / piece / bunch)
  final UnitKind kind;
  final String displayUnit; // most-frequent contributed unit
  final Set<String> sourceRecipeIds;
  final LText? note;

  const ShoppingItem({
    required this.ingredientId,
    required this.baseAmount,
    required this.kind,
    required this.displayUnit,
    required this.sourceRecipeIds,
    this.note,
  });
}

/// Aggregate [recipeId -> Recipe] ingredient lines into shopping items.
/// Scaling factor per recipe adjusts servings (e.g. 1.5 → 3 of 2 servings).
///
/// Display unit = the most frequently contributed unit, so "2 cloves +
/// 3 cloves" stays cloves while "200 ml + 2 tbsp" renders in one unit.
List<ShoppingItem> aggregateShoppingItems(
  Map<String, Recipe> sources, {
  Map<String, double> scaleByRecipe = const {},
}) {
  final byIngredient = <String, _Agg>{};

  for (final entry in sources.entries) {
    final recipe = entry.value;
    final scale = scaleByRecipe[recipe.id] ?? 1.0;
    for (final ing in recipe.ingredients) {
      final amount = ing.amount * scale;
      final base = toBase(amount, ing.unit);
      if (base == null) continue; // unknown unit — skip rather than corrupt
      final kind = unitTable[ing.unit]!.kind;
      final agg = byIngredient.putIfAbsent(
          ing.id, () => _Agg(kind: kind, note: ing.note));
      agg.base += base;
      agg.unitCounts[ing.unit] = (agg.unitCounts[ing.unit] ?? 0) + 1;
      agg.sources.add(recipe.id);
    }
  }

  final items = <ShoppingItem>[];
  byIngredient.forEach((id, agg) {
    items.add(ShoppingItem(
      ingredientId: id,
      baseAmount: agg.base,
      kind: agg.kind,
      displayUnit: _pickDisplayUnit(agg),
      sourceRecipeIds: agg.sources,
      note: agg.note,
    ));
  });

  // stable-ish ordering: by ingredient id; UI groups by aisle anyway
  items.sort((a, b) => a.ingredientId.compareTo(b.ingredientId));
  return items;
}

String _pickDisplayUnit(_Agg agg) {
  // most-frequent contributed unit; ties → first contributor wins
  String best = agg.unitCounts.keys.first;
  int bestCount = -1;
  agg.unitCounts.forEach((u, c) {
    if (c > bestCount) {
      best = u;
      bestCount = c;
    }
  });
  return best;
}

/// Best display (amount, unit) for an item.
(String, double) displayAmount(ShoppingItem item) {
  final unit = item.displayUnit;
  return (unit, convertBaseToUnit(item.baseAmount, unit));
}

class _Agg {
  UnitKind kind;
  double base = 0;
  final Map<String, int> unitCounts = {};
  final Set<String> sources = {};
  LText? note;
  _Agg({required this.kind, this.note});
}

/// Aisle ordering for the market list sections.
const aisleOrder = [
  'produce', 'meat', 'fish', 'dairy', 'bakery', 'pantry', 'frozen', 'spices',
  'drinks', 'other',
];

/// Group items by aisle (falls back to 'other' for unknown ids).
Map<String, List<ShoppingItem>> groupByAisle(
  Iterable<ShoppingItem> items,
  IngredientIndex idx,
) {
  final out = <String, List<ShoppingItem>>{};
  for (final item in items) {
    final node = idx.nodes[item.ingredientId];
    final aisle =
        (node?.aisle != null && aisleOrder.contains(node!.aisle)) ? node.aisle : 'other';
    out.putIfAbsent(aisle, () => []).add(item);
  }
  return out;
}
