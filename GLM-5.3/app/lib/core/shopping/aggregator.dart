import '../models/recipe.dart';
import 'units.dart';

/// One aggregated quantity line (a unit family summed in its base unit).
/// Mutable: merging later additions adjusts [baseQty] in place.
class QtyLine {
  QtyLine({required this.family, required this.baseQty, this.countUnit = ''});

  final UnitFamily family;
  double baseQty; // grams / millilitres / count-in-[countUnit]

  /// Display unit for count lines (e.g. `clove`).
  final String countUnit;

  /// Human display: `5 clove`, `450 g`, `2.5 tbsp`.
  String display() {
    switch (family) {
      case UnitFamily.mass:
        return formatAmount(baseQty, 'g');
      case UnitFamily.volume:
        return formatAmount(baseQty, 'ml');
      case UnitFamily.count:
        return '${formatQty(baseQty)} $countUnit';
    }
  }

  Map<String, dynamic> toJson() =>
      {'family': family.index, 'base': baseQty, 'u': countUnit};

  static QtyLine fromJson(Map<String, dynamic> json) => QtyLine(
        family: UnitFamily.values[(json['family'] as num).toInt()],
        baseQty: (json['base'] as num).toDouble(),
        countUnit: json['u'] as String? ?? '',
      );
}

/// One shopping-list item: an ingredient with one or more aggregated
/// quantity lines plus a checked flag.
class ShoppingItem {
  ShoppingItem({required this.ingredientId, required this.lines, this.checked = false});

  final String ingredientId;
  List<QtyLine> lines;
  bool checked;

  String display() => lines.map((l) => l.display()).join(' + ');

  Map<String, dynamic> toJson() =>
      {'id': ingredientId, 'checked': checked, 'lines': lines.map((l) => l.toJson()).toList()};

  static ShoppingItem fromJson(Map<String, dynamic> json) => ShoppingItem(
        ingredientId: json['id'] as String,
        checked: json['checked'] as bool? ?? false,
        lines: ((json['lines'] as List?) ?? const [])
            .map((raw) => QtyLine.fromJson(raw as Map<String, dynamic>))
            .toList(),
      );
}

/// One "added to list" event — feeds the shopping insights analytics.
class ShoppingAddition {
  ShoppingAddition({required this.at, required this.ingredientIds});

  final DateTime at;
  final List<String> ingredientIds;

  Map<String, dynamic> toJson() => {'at': at.toIso8601String(), 'ids': ingredientIds};

  static ShoppingAddition fromJson(Map<String, dynamic> json) => ShoppingAddition(
        at: DateTime.parse(json['at'] as String),
        ingredientIds: ((json['ids'] as List?) ?? const []).map((e) => e.toString()).toList(),
      );
}

/// Per-ingredient quantity accumulator: mass (base g), volume (base ml) and
/// one bucket per count unit.
class _Acc {
  double mass = 0;
  double volume = 0;
  final Map<String, double> counts = {};

  bool get isEmpty => mass == 0 && volume == 0 && counts.isEmpty;
}
/// Unit-aware aggregation across recipes (SPEC: "garlic 2 cloves + 3 cloves
/// = 5 cloves"; ml ↔ tbsp conversion for compatible families; dedup). Aisle
/// grouping is done by the caller via the ingredient dictionary.
class ShoppingAggregator {
  /// Aggregates ingredient lines of [recipes] into deduplicated items,
  /// merging quantities per unit family (and per count unit).
  static List<ShoppingItem> aggregate(Iterable<Recipe> recipes) {
    final acc = <String, _Acc>{};
    for (final recipe in recipes) {
      for (final line in recipe.ingredients) {
        final unit = unitOf(line.unit);
        final bucket = acc.putIfAbsent(line.id, _Acc.new);
        switch (unit.family) {
          case UnitFamily.mass:
            bucket.mass += unit.toBaseValue(line.qty);
          case UnitFamily.volume:
            bucket.volume += unit.toBaseValue(line.qty);
          case UnitFamily.count:
            bucket.counts[line.unit] = (bucket.counts[line.unit] ?? 0) + line.qty;
        }
      }
    }
    final items = <ShoppingItem>[];
    acc.forEach((ingredientId, bucket) {
      final lines = <QtyLine>[];
      if (bucket.mass > 0) {
        lines.add(QtyLine(family: UnitFamily.mass, baseQty: bucket.mass));
      }
      if (bucket.volume > 0) {
        lines.add(QtyLine(family: UnitFamily.volume, baseQty: bucket.volume));
      }
      final countUnits = bucket.counts.keys.toList()..sort();
      for (final unitId in countUnits) {
        lines.add(QtyLine(
          family: UnitFamily.count,
          baseQty: bucket.counts[unitId]!,
          countUnit: unitId,
        ));
      }
      if (lines.isNotEmpty) {
        items.add(ShoppingItem(ingredientId: ingredientId, lines: lines));
      }
    });
    return items;
  }

  /// Merges [incoming] items into [existing] (preserving checked state),
  /// returning the combined list.
  static List<ShoppingItem> mergeInto(
    List<ShoppingItem> existing,
    List<ShoppingItem> incoming,
  ) {
    final result = existing.map((e) => e).toList();
    for (final item in incoming) {
      final target = result.where((e) => e.ingredientId == item.ingredientId).toList();
      if (target.isEmpty) {
        result.add(item);
        continue;
      }
      for (final line in item.lines) {
        _mergeLine(target.first, line);
      }
    }
    return result;
  }

  static void _mergeLine(ShoppingItem target, QtyLine line) {
    for (final existing in target.lines) {
      if (existing.family == line.family) {
        if (line.family == UnitFamily.count) {
          if (existing.countUnit == line.countUnit) {
            existing.baseQty += line.baseQty;
            return;
          }
        } else {
          existing.baseQty += line.baseQty;
          return;
        }
      }
    }
    target.lines.add(line);
  }
}
