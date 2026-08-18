import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/shopping.dart';
import 'units.dart';

/// One aggregated shopping line — ingredient merged across recipes,
/// converted to canonical units, grouped by aisle.
class ShoppingLine {
  const ShoppingLine({
    required this.ingredientId,
    required this.amount,
    required this.unit,
    required this.aisle,
    required this.kind,
  });

  final String ingredientId;
  final double amount;
  final String unit; // canonical unit of the kind
  final String aisle;
  final String kind;

  String get display => Units.format(amount, unit);
}

/// Unit-aware aggregation: "garlic 2 cloves + garlic 3 cloves = 5 cloves",
/// "30 ml + 2 tbsp = 60 ml". Dedup by ingredient; group by aisle.
class ShoppingAggregator {
  const ShoppingAggregator();

  /// Expands a recipe's ingredients into shopping entries (optionally scaled).
  static List<ShoppingEntry> entriesFromRecipe(
    Recipe recipe, {
    double scale = 1,
    DateTime? addedAt,
  }) => [
        for (final ing in recipe.ingredients)
          ShoppingEntry(
            ingredientId: ing.id,
            amount: ing.amount * scale,
            unit: ing.unit,
            addedAt: addedAt ?? DateTime.now(),
          ),
      ];

  /// Merges many recipe lists into entries.
  static List<ShoppingEntry> entriesFromRecipes(
    Iterable<Recipe> recipes, {
    double scale = 1,
    DateTime? addedAt,
  }) => [
        for (final r in recipes)
          ...entriesFromRecipe(r, scale: scale, addedAt: addedAt),
      ];

  /// Aggregates entries into lines, grouped by aisle.
  /// Unknown ingredients go to the "other" aisle and keep their id as label.
  static List<ShoppingLine> aggregate(
    List<ShoppingEntry> entries,
    IngredientTree tree,
  ) {
    // key: ingredientId + canonical unit (in case of mixed kinds)
    final sums = <String, _Acc>{};
    for (final e in entries) {
      if (e.checked) continue;
      final canonical = Units.toCanonical(e.amount, e.unit);
      if (canonical == null) continue;
      final node = tree.byId(e.ingredientId);
      final key = '${e.ingredientId}|${canonical.unit}';
      final acc = sums.putIfAbsent(
        key,
        () => _Acc(
          ingredientId: e.ingredientId,
          amount: 0,
          unit: canonical.unit,
          kind: Units.kindOf(e.unit),
          aisle: node?.aisle ?? 'other',
        ),
      );
      acc.amount += canonical.value;
    }

    final lines = sums.values
        .map((a) => ShoppingLine(
              ingredientId: a.ingredientId,
              amount: a.amount,
              unit: a.unit,
              aisle: a.aisle,
              kind: a.kind,
            ))
        .toList();

    // Group by aisle, stable order.
    const aisleOrder = [
      'produce', 'dairy', 'meat', 'fish', 'bakery',
      'pantry', 'spices', 'baking', 'other',
    ];
    lines.sort((a, b) {
      final ai = aisleOrder.indexOf(a.aisle);
      final bi = aisleOrder.indexOf(b.aisle);
      if (ai != bi) return (ai < 0 ? 99 : ai) - (bi < 0 ? 99 : bi);
      return a.ingredientId.compareTo(b.ingredientId);
    });
    return lines;
  }

  /// Grouped map aisle → lines (convenience for UI).
  static Map<String, List<ShoppingLine>> groupByAisle(
    List<ShoppingLine> lines,
  ) {
    final out = <String, List<ShoppingLine>>{};
    for (final l in lines) {
      out.putIfAbsent(l.aisle, () => []).add(l);
    }
    return out;
  }
}

class _Acc {
  _Acc({
    required this.ingredientId,
    required this.amount,
    required this.unit,
    required this.kind,
    required this.aisle,
  });

  final String ingredientId;
  double amount;
  final String unit;
  final String kind;
  final String aisle;
}
