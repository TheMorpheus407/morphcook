import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/shopping.dart';
import 'unit_conversion.dart';

/// Builds the smart shopping list.
///
/// Ingredients are deduped across recipes and their quantities added
/// together — 2 cloves plus 3 cloves of garlic is 5 cloves. Where two
/// recipes use compatible units of the same ingredient (200 ml + 1 tbsp),
/// the smaller quantity is converted and folded in. Quantities that cannot
/// be converted stay on their own line rather than being guessed at.
abstract final class ShoppingAggregator {
  const ShoppingAggregator._();

  /// The order aisles appear in the list.
  static const List<String> aisleOrder = <String>[
    'produce',
    'bakery',
    'meat-seafood',
    'dairy',
    'pantry',
    'frozen',
    'beverages',
    'other',
  ];

  static int aisleRank(String aisle) {
    final index = aisleOrder.indexOf(aisle);
    return index == -1 ? aisleOrder.length : index;
  }

  /// Aggregates the ingredients of [recipes] into shopping lines.
  static List<ShoppingItem> aggregate({
    required List<Recipe> recipes,
    required IngredientTree ingredients,
    required String lang,
    Set<String> checkedIngredientIds = const <String>{},
  }) {
    final buckets = <String, List<_Entry>>{};

    for (final recipe in recipes) {
      for (final ingredient in recipe.ingredients) {
        if (ingredient.quantity <= 0) continue;
        buckets.putIfAbsent(ingredient.ingredientId, () => <_Entry>[]).add(
              _Entry(
                quantity: ingredient.quantity,
                unit: ingredient.unit,
                recipeId: recipe.id,
                name: ingredient.name.resolve(lang),
              ),
            );
      }
    }

    final items = <ShoppingItem>[];

    buckets.forEach((ingredientId, entries) {
      final node = ingredients.node(ingredientId);
      final displayName = _displayName(node, entries, lang);
      final aisle = ingredients.aisleOf(ingredientId);
      final system = ingredients.unitSystemOf(ingredientId);

      for (final group in _groupByUnit(entries, system)) {
        final unit = Units.preferredUnit(group.unit, group.quantity);
        final quantity = unit == group.unit
            ? group.quantity
            : Units.convert(group.quantity, group.unit, unit) ?? group.quantity;

        items.add(
          ShoppingItem(
            ingredientId: ingredientId,
            name: displayName,
            quantity: quantity,
            unit: unit,
            aisle: aisle,
            recipeIds: group.recipeIds.toList(growable: false),
            checked: checkedIngredientIds.contains(ingredientId),
          ),
        );
      }
    });

    items.sort((a, b) {
      final byAisle = aisleRank(a.aisle).compareTo(aisleRank(b.aisle));
      if (byAisle != 0) return byAisle;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return items;
  }

  static String _displayName(
    IngredientNode? node,
    List<_Entry> entries,
    String lang,
  ) {
    if (node != null) {
      final label = node.label.resolve(lang);
      if (label.isNotEmpty) return label;
    }
    for (final entry in entries) {
      if (entry.name.isNotEmpty) return entry.name;
    }
    return '';
  }

  /// Groups the entries of one ingredient into lines that can share a unit.
  ///
  /// Count units (cloves, slices, cans) never convert, so they group by
  /// themselves; volume and mass fold into a canonical unit when the
  /// ingredient allows it.
  static List<_Group> _groupByUnit(List<_Entry> entries, String system) {
    final canonical = _canonicalUnit(entries, system);
    final bucket = <String, _Group>{};

    for (final entry in entries) {
      final target = canonical != null &&
              _canConvert(entry.unit, canonical, system)
          ? canonical
          : entry.unit;
      final group = bucket.putIfAbsent(
        target,
        () => _Group(unit: target, quantity: 0, recipeIds: <String>{}),
      );
      final converted = target == entry.unit
          ? entry.quantity
          : Units.convert(entry.quantity, entry.unit, target,
              ingredientSystem: system) ?? entry.quantity;
      group.quantity += converted;
      group.recipeIds.add(entry.recipeId);
    }

    return bucket.values.toList(growable: false);
  }

  static bool _canConvert(String from, String to, String system) {
    if (from == to) return true;
    if (Units.systemOf(from) != Units.systemOf(to)) return false;
    if (system != 'any' && system != Units.systemOf(from)) return false;
    return true;
  }

  /// The unit everything in a group is converted into.
  static String? _canonicalUnit(List<_Entry> entries, String system) {
    final units = entries.map((entry) => entry.unit).toSet().toList();
    if (units.isEmpty) return null;
    if (units.length == 1) return units.first;

    final systems = units.map(Units.systemOf).toSet();
    if (systems.length != 1) return null;

    final effective = system == 'any' ? systems.first : system;
    if (effective != systems.first) return null;

    return effective == 'volume' ? 'ml' : (effective == 'mass' ? 'g' : units.first);
  }
}

class _Entry {
  const _Entry({
    required this.quantity,
    required this.unit,
    required this.recipeId,
    required this.name,
  });

  final double quantity;
  final String unit;
  final String recipeId;
  final String name;
}

class _Group {
  _Group({
    required this.unit,
    required this.quantity,
    required this.recipeIds,
  });

  final String unit;
  double quantity;
  final Set<String> recipeIds;
}
