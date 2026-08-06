// Unit-aware shopping aggregation.
//
// Same ingredient + compatible unit → summed ("garlic 2 cloves + garlic
// 3 cloves = 5 cloves"). Liquids convert between ml / tbsp / tsp
// automatically. Items dedup and group by aisle.

import '../core/l10n.dart';
import '../data/models.dart';

const double tbspInMl = 15;
const double tspInMl = 5;

class ShoppingItem {
  final String ingredientId;
  double qty;
  String unit;
  bool checked;

  ShoppingItem({
    required this.ingredientId,
    required this.qty,
    required this.unit,
    this.checked = false,
  });

  Map<String, dynamic> toJson() => {
        'ingredient_id': ingredientId,
        'qty': qty,
        'unit': unit,
        'checked': checked,
      };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
        ingredientId: json['ingredient_id'] as String,
        qty: (json['qty'] as num).toDouble(),
        unit: json['unit'] as String? ?? 'piece',
        checked: json['checked'] as bool? ?? false,
      );
}

/// Which aggregation family a unit belongs to.
String unitFamily(String unit) {
  switch (unit) {
    case 'g':
    case 'kg':
      return 'mass';
    case 'ml':
    case 'l':
    case 'tbsp':
    case 'tsp':
      return 'volume';
    default:
      return 'count:$unit';
  }
}

double toGrams(double qty, String unit) =>
    unit == 'kg' ? qty * 1000 : qty;

double toMl(double qty, String unit) {
  switch (unit) {
    case 'l':
      return qty * 1000;
    case 'tbsp':
      return qty * tbspInMl;
    case 'tsp':
      return qty * tspInMl;
    default:
      return qty;
  }
}

String formatQty(double qty) {
  if ((qty - qty.roundToDouble()).abs() < 0.05) {
    return qty.round().toString();
  }
  return qty.toStringAsFixed(1);
}

class ShoppingAggregator {
  final IngredientDictionary dictionary;
  const ShoppingAggregator(this.dictionary);

  /// Aggregate scaled ingredient lines into deduplicated shopping items.
  /// [lines] are (ingredientId, qty, unit) triples, already scaled for
  /// servings.
  List<ShoppingItem> aggregate(Iterable<({String id, double qty, String unit})> lines) {
    // key: ingredientId|family
    final grouped = <String, ShoppingItem>{};
    for (final line in lines) {
      final node = dictionary[line.id];
      final isLiquid = node?.form == 'liquid';
      var qty = line.qty;
      var unit = line.unit;

      if (isLiquid && unitFamily(unit) == 'volume') {
        qty = toMl(qty, unit);
        unit = 'ml';
      } else if (unit == 'kg') {
        qty = toGrams(qty, unit);
        unit = 'g';
      }

      final family = unitFamily(unit);
      final key = '${line.id}|$family';
      final existing = grouped[key];
      if (existing != null) {
        existing.qty += qty;
      } else {
        grouped[key] =
            ShoppingItem(ingredientId: line.id, qty: qty, unit: unit);
      }
    }

    final items = grouped.values.toList();
    for (final item in items) {
      if (item.unit == 'g' && item.qty >= 1000) {
        item.qty = item.qty / 1000;
        item.unit = 'kg';
      }
    }
    return items;
  }

  /// Scale a recipe's ingredients to [servings] target servings.
  List<({String id, double qty, String unit})> scaleRecipe(
      Recipe recipe, int servings) {
    final factor = servings / recipe.servings;
    return [
      for (final i in recipe.ingredients)
        if (!i.optional)
          (id: i.ingredientId, qty: i.qty * factor, unit: i.unit),
    ];
  }

  /// Group items by aisle, ordered by the dictionary's aisle order.
  List<({Aisle aisle, List<ShoppingItem> items})> groupByAisle(
      List<ShoppingItem> items) {
    final byAisle = <String, List<ShoppingItem>>{};
    for (final item in items) {
      final aisleId = dictionary[item.ingredientId]?.aisle ?? 'pantry';
      byAisle.putIfAbsent(aisleId, () => []).add(item);
    }
    final out = <({Aisle aisle, List<ShoppingItem> items})>[];
    for (final aisle in dictionary.aisles) {
      final list = byAisle[aisle.id];
      if (list == null || list.isEmpty) continue;
      list.sort((a, b) => a.ingredientId.compareTo(b.ingredientId));
      out.add((aisle: aisle, items: list));
    }
    return out;
  }

  String itemName(ShoppingItem item, AppLang lang) {
    final node = dictionary[item.ingredientId];
    if (node == null) return item.ingredientId;
    return tx(node.name, lang);
  }

  String formatItem(ShoppingItem item) =>
      '${formatQty(item.qty)} ${item.unit}';
}

/// Shopping insights over recorded list additions.
class ShoppingInsights {
  /// Number of unique ingredients ever added — the variety score.
  static int varietyScore(List<ShoppingEvent> events) =>
      {for (final e in events) e.ingredientId}.length;

  /// Top ingredients by addition frequency.
  static List<({String ingredientId, int count})> topIngredients(
      List<ShoppingEvent> events,
      {int limit = 8}) {
    final counts = <String, int>{};
    for (final e in events) {
      counts[e.ingredientId] = (counts[e.ingredientId] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });
    return [
      for (final e in entries.take(limit))
        (ingredientId: e.key, count: e.value)
    ];
  }

  /// Additions grouped by month (`yyyy-MM`), oldest first.
  static List<({String month, int count})> byMonth(
      List<ShoppingEvent> events) {
    final counts = <String, int>{};
    for (final e in events) {
      final d = e.at;
      final key =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final keys = counts.keys.toList()..sort();
    return [for (final k in keys) (month: k, count: counts[k]!)];
  }
}

class ShoppingEvent {
  final String ingredientId;
  final DateTime at;
  const ShoppingEvent({required this.ingredientId, required this.at});

  Map<String, dynamic> toJson() =>
      {'ingredient_id': ingredientId, 'at': at.toIso8601String()};

  factory ShoppingEvent.fromJson(Map<String, dynamic> json) => ShoppingEvent(
        ingredientId: json['ingredient_id'] as String,
        at: DateTime.tryParse(json['at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}
