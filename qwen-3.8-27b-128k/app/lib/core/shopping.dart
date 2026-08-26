/// Unit-aware shopping-list aggregation across recipes.
/// "garlic 2 cloves + garlic 3 cloves = 5 cloves"; ml ↔ tbsp conversion.
/// Pure and unit-tested.
library;

import 'models.dart';

/// Units that are count-like and cannot be mixed with volume/weight.
const Set<String> discreteUnits = {
  'clove', 'piece', 'leaf', 'sheet', 'pinch', 'cup', 'unit',
};

/// Conversion factors to the base unit of each continuous family.
const Map<String, double> toMl = {'ml': 1, 'l': 1000, 'tbsp': 15, 'tsp': 5};
const Map<String, double> toG = {'g': 1, 'kg': 1000};

double? perUnitBase(String unit) => toMl[unit] ?? toG[unit];

class AggPart {
  final double qty;
  final String unit;
  final bool fromConversion; // true if we converted to this unit
  const AggPart(this.qty, this.unit, [this.fromConversion = false]);
}

class AggItem {
  final String id;
  final I18n name;
  final String aisle;
  final List<AggPart> parts;
  final List<String> sources; // recipe ids contributing

  const AggItem({
    required this.id,
    required this.name,
    required this.aisle,
    required this.parts,
    required this.sources,
  });

  /// Display string like "5 cl". or "100 g + 15 cl".
  String display() {
    final pieces = <String>[];
    for (final p in parts) {
      pieces.add('${_fmt(p.qty)} ${p.unit}');
    }
    return pieces.join(' + ');
  }

  static String _fmt(double q) {
    if (q == q.truncateToDouble() && q < 100000) return q.toInt().toString();
    return q.toStringAsFixed(1);
  }
}

/// Aggregate the ingredient lists of [recipes] into shopping items,
/// grouped by ingredient id. Returns sorted by (aisle, name).
List<AggItem> aggregateShopping(
  List<Recipe> recipes,
  Map<String, IngredientMeta> ingredientMeta,
  String lang,
) {
  final groups = <String, _Accum>{};
  for (final r in recipes) {
    for (final ing in r.ingredients) {
      final acc = groups.putIfAbsent(ing.id, _Accum.new);
      acc.sources.add(r.id);
      acc.add(ing);
    }
  }

  final items = groups.entries
      .map((e) {
        final id = e.key;
        final a = e.value;
        final meta = ingredientMeta[id];
        return AggItem(
          id: id,
          name: a.name,
          aisle: meta?.aisle ?? 'pantry',
          parts: a.parts(),
          sources: a.sources.toList(),
        );
      })
      .toList();

  items.sort((a, b) {
    final c = a.aisle.compareTo(b.aisle);
    if (c != 0) return c;
    return a.name.s(lang).compareTo(b.name.s(lang));
  });
  return items;
}

class _Accum {
  late I18n name;
  final Set<String> sources = {};
  final Map<String, double> discrete = {}; // unit -> qty
  double grams = 0;
  double milliliters = 0;

  void add(IngredientRef ref) {
    name = ref.name;
    final qty = ref.qtyNum;
    if (qty <= 0) return; // "to taste" etc.
    final base = perUnitBase(ref.unit);
    if (base == null) {
      discrete[ref.unit] = (discrete[ref.unit] ?? 0) + qty;
    } else if (toG.containsKey(ref.unit)) {
      grams += qty * base;
    } else {
      milliliters += qty * base;
    }
  }

  List<AggPart> parts() {
    final out = <AggPart>[];
    // discrete units in stable order
    for (final u in discrete.keys.toList()..sort()) {
      out.add(AggPart(discrete[u] ?? 0, u));
    }
    if (grams > 0) {
      if (grams >= 1000) {
        out.add(AggPart(grams / 1000, 'kg', true));
      } else {
        out.add(AggPart(grams, 'g'));
      }
    }
    if (milliliters > 0) {
      if (milliliters >= 1000) {
        out.add(AggPart(milliliters / 1000, 'l', true));
      } else {
        out.add(AggPart(milliliters, 'ml'));
      }
    }
    return out;
  }
}

/// --- insights -------------------------------------------------------------

class ShoppingInsights {
  final int uniqueIngredients;
  final List<TopItem> top;
  final Map<int, int> monthly;
  final int seasonalCount;
  final int offSeasonCount;
  const ShoppingInsights({
    required this.uniqueIngredients,
    required this.top,
    required this.monthly,
    required this.seasonalCount,
    required this.offSeasonCount,
  });
}

class TopItem {
  final String id;
  final I18n name;
  final int count;
  const TopItem(this.id, this.name, this.count);
}

ShoppingInsights computeInsights(
  List<Recipe> recipes,
  Map<String, IngredientMeta> ingredientMeta,
  int currentMonth,
) {
  final perIng = <String, int>{};
  final monthly = <int, int>{};
  var seasonal = 0;
  var off = 0;

  for (final r in recipes) {
    for (final ing in r.ingredients) {
      perIng[ing.id] = (perIng[ing.id] ?? 0) + 1;
      final meta = ingredientMeta[ing.id];
      final months = meta?.seasonalMonths ?? const <int>[];
      if (months.isEmpty) continue;
      if (months.contains(currentMonth)) seasonal++;
      off++;
    }
  }

  for (final e in perIng.entries) {
    final meta = ingredientMeta[e.key];
    final months = meta?.seasonalMonths ?? const <int>[];
    for (final m in months) {
      monthly[m] = (monthly[m] ?? 0) + e.value;
    }
  }

  final topList = perIng.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final top = topList
      .take(12)
      .map((e) => TopItem(e.key, ingredientMeta[e.key]?.name ?? I18n({}), e.value))
      .toList();

  return ShoppingInsights(
    uniqueIngredients: perIng.length,
    top: top,
    monthly: monthly,
    seasonalCount: seasonal,
    offSeasonCount: off,
  );
}
