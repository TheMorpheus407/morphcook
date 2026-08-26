import 'models.dart';

class ShoppingLine {
  ShoppingLine({
    required this.ingredientId,
    required this.displayName,
    required this.total,
    required this.unit,
    required this.aisle,
    required this.sourceRecipeIds,
  });

  final String ingredientId;
  final String displayName;
  final double total;
  final String unit;
  final String aisle;
  final Set<String> sourceRecipeIds;
}

class ShoppingList {
  ShoppingList(this.lines, {required this.aisleOrder});

  final List<ShoppingLine> lines;
  final List<String> aisleOrder;

  /// Grouped by aisle (order from [aisleOrder]); unknown aisles last.
  List<List<ShoppingLine>> byAisle() {
    final known = <String, List<ShoppingLine>>{};
    final rest = <ShoppingLine>[];
    for (final l in lines) {
      if (aisleOrder.contains(l.aisle)) {
        (known[l.aisle] ??= <ShoppingLine>[]).add(l);
      } else {
        rest.add(l);
      }
    }
    final out = <List<ShoppingLine>>[];
    for (final a in aisleOrder) {
      final l = known[a];
      if (l != null && l.isNotEmpty) {
        l.sort((a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
        out.add(l);
      }
    }
    if (rest.isNotEmpty) {
      rest.sort((a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
      out.add(rest);
    }
    return out;
  }

  int get uniqueIngredients => lines.length;
}

/// Unit-aware aggregation across recipes.
///
/// "garlic 2 cloves" + "garlic 3 cloves" -> "garlic 5 cloves".
/// Liquid/measure units in the same base dimension are converted
/// (ml <-> tbsp) and merged; different dimensions stay separate.
class ShoppingAggregator {
  ShoppingAggregator({
    required this.factor, // unitId -> conversion factor to its base dimension
    required this.base, // unitId -> base dimension key ('mass','liquid','time','pc', 'misc:x')
    required this.ingredientName,
    required this.ingredientAisle,
    required this.aisleOrder,
  });

  final Map<String, double> factor;
  final Map<String, String> base;
  final String Function(String id) ingredientName;
  final String Function(String id) ingredientAisle;
  final List<String> aisleOrder;

  ShoppingList aggregate(List<Recipe> recipes) {
    // (ingredientId, baseDimension) -> list of raw lines
    final groups = <String, List<_Raw>>{};
    for (final r in recipes) {
      for (final ref in r.ingredientRefs) {
        if (ref.optional) continue;
        final b = base[ref.unit] ?? 'misc:${ref.unit}';
        final key = '${ref.id}¦$b';
        (groups[key] ??= <_Raw>[])
            .add(_Raw(ref.id, ref.amount, ref.unit, r.id));
      }
    }

    final out = <ShoppingLine>[];
    for (final group in groups.values) {
      // total in base units
      double baseTotal = 0;
      for (final raw in group) {
        baseTotal += raw.amount * (factor[raw.unit] ?? 1.0);
      }
      // pick a display unit: the one giving the smallest total >= 1;
      // otherwise the most frequent unit.
      String unit = group.first.unit;
      double best = -1;
      final counts = <String, int>{};
      for (final raw in group) {
        counts[raw.unit] = (counts[raw.unit] ?? 0) + 1;
      }
      for (final unitCandidate in counts.keys) {
        final t = baseTotal / (factor[unitCandidate] ?? 1.0);
        if (t >= 1 && (best < 0 || t < best)) {
          unit = unitCandidate;
          best = t;
        }
      }
      if (best < 0) {
        for (final u in counts.keys) {
          if (counts[u]! > counts[unit]!) unit = u;
        }
      }
      final totalBase = baseTotal;
      final unitFactor = factor[unit] ?? 1.0;
      final displayTotal = unitFactor == 0 ? 0 : totalBase / unitFactor;

      final id = group.first.id;
      out.add(ShoppingLine(
        ingredientId: id,
        displayName: ingredientName(id),
        total: _round(displayTotal),
        unit: unit,
        aisle: ingredientAisle(id),
        sourceRecipeIds: group.map((g) => g.recipeId).toSet(),
      ));
    }

    out.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return ShoppingList(out, aisleOrder: aisleOrder);
  }

  static double _round(double v) => (v * 100).roundToDouble() / 100;
}

class _Raw {
  const _Raw(this.id, this.amount, this.unit, this.recipeId);
  final String id;
  final double amount;
  final String unit;
  final String recipeId;
}

/// Build an aggregator from ontology + ingredient tree.
buildShoppingAggregator(
  Ontology ontology,
  Map<String, IngredientNode> ingredients,
  String lang, {
  List<String>? aisleOrder,
}) {
  final factor = <String, double>{};
  final base = <String, String>{};
  for (final e in ontology.units.entries) {
    factor[e.key] = ontology.unitFactor(e.key);
    base[e.key] = ontology.unitBase(e.key);
  }
  const order = [
    'produce',
    'meat-fish',
    'dairy-eggs',
    'pantry',
    'grains-legumes',
    'frozen',
    'spices',
    'baking',
    'other',
  ];
  return ShoppingAggregator(
    factor: factor,
    base: base,
    ingredientName: (id) => (ingredients[id]?.nameOf(lang) ?? id.split('.').last.split('-').join(' ')),
    ingredientAisle: (id) => ingredients[id]?.aisle ?? 'other',
    aisleOrder: aisleOrder ?? order,
  );
}
