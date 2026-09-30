import '../models/ingredient_tree.dart';
import '../models/ontology.dart';
import '../models/recipe.dart';

/// One recipe put on the list, at a given number of servings.
class ShoppingSource {
  const ShoppingSource({
    required this.id,
    required this.recipeId,
    required this.servings,
    required this.addedAt,
    this.label,
  });

  factory ShoppingSource.fromJson(Map<String, dynamic> j) => ShoppingSource(
    id: j['id'] as String,
    recipeId: j['recipe_id'] as String,
    servings: j['servings'] as int,
    addedAt: DateTime.parse(j['added_at'] as String),
    label: j['label'] as String?,
  );

  final String id;
  final String recipeId;
  final int servings;
  final DateTime addedAt;

  /// e.g. `2026-W38 · mon.dinner` when exported from the meal plan.
  final String? label;

  Map<String, dynamic> toJson() => {
    'id': id,
    'recipe_id': recipeId,
    'servings': servings,
    'added_at': addedAt.toIso8601String(),
    if (label != null) 'label': label,
  };
}

class ManualItem {
  const ManualItem({required this.id, required this.text});
  factory ManualItem.fromJson(Map<String, dynamic> j) => ManualItem(id: j['id'] as String, text: j['text'] as String);
  final String id;
  final String text;
  Map<String, dynamic> toJson() => {'id': id, 'text': text};
}

/// An aggregated line: one ingredient in one compatible unit family.
class ShoppingLine {
  ShoppingLine({
    required this.key,
    required this.ingredientId,
    required this.aisle,
    required this.family,
    this.displayUnit,
  });

  /// `ingredientId|family` — stable across list changes, used for checkmarks.
  final String key;
  final String ingredientId;
  final String aisle;

  /// `mass`, `volume`, `unit:<id>`, `count:<noun>` or `taste`.
  final String family;

  /// Total in base units (g, ml, or count). Null for to-taste lines.
  double? total;

  /// Units that fed this line, so a line fed only by `tbsp` stays in tbsp.
  final Set<String> sourceUnits = {};
  final Set<String> recipeIds = {};
  String? displayUnit;

  bool get toTaste => family == 'taste';
}

class AislePart {
  const AislePart(this.aisle, this.lines);
  final String aisle;
  final List<ShoppingLine> lines;
}

/// Unit-aware aggregation: identical ingredients merge; mass converts
/// g ↔ kg, volume converts ml ↔ tsp ↔ tbsp ↔ cup ↔ l for ingredient types
/// that pour or spoon (liquids, oils, sauces, spices, powders, sweeteners);
/// countable nouns (cloves, cans …) add up by noun. Anything else stays on
/// its own line rather than guessing a conversion.
class ShoppingAggregator {
  ShoppingAggregator(this.ontology, this.tree);

  final Ontology ontology;
  final IngredientTree tree;

  String familyFor(String ingredientId, String unitId) {
    final unit = ontology.units[unitId];
    if (unit == null) return 'unit:$unitId';
    switch (unit.kind) {
      case 'mass':
        return 'mass';
      case 'volume':
        final type = tree[ingredientId]?.type ?? 'solid';
        return ontology.volumeConvertibleTypes.contains(type) ? 'volume' : 'unit:$unitId';
      case 'taste':
        return 'taste';
      case 'count':
        return 'count:pc';
      default:
        return unit.kind; // count:clove, count:can …
    }
  }

  List<ShoppingLine> aggregate(Iterable<ShoppingSource> sources, Recipe? Function(String id) lookup) {
    final lines = <String, ShoppingLine>{};
    for (final src in sources) {
      final recipe = lookup(src.recipeId);
      if (recipe == null) continue;
      final factor = src.servings / recipe.servings;
      for (final ing in recipe.ingredients) {
        final family = familyFor(ing.id, ing.unit);
        final key = '${ing.id}|$family';
        final line = lines.putIfAbsent(
          key,
          () => ShoppingLine(key: key, ingredientId: ing.id, aisle: tree[ing.id]?.aisle ?? 'other', family: family),
        );
        line.recipeIds.add(recipe.id);
        line.sourceUnits.add(ing.unit);
        if (family == 'taste' || ing.qty == null) continue;
        final unit = ontology.units[ing.unit];
        final base = family.startsWith('unit:') ? ing.qty! : ing.qty! * (unit?.toBase ?? 1);
        line.total = (line.total ?? 0) + base * factor;
      }
    }
    for (final line in lines.values) {
      line.displayUnit = _displayUnit(line);
    }
    return lines.values.toList();
  }

  /// The unit a line is shown in, and its amount converted to that unit.
  (double?, String) display(ShoppingLine line) {
    final unitId = line.displayUnit ?? line.sourceUnits.first;
    if (line.total == null) return (null, unitId);
    if (line.family.startsWith('unit:')) return (line.total, unitId);
    final unit = ontology.units[unitId];
    return (line.total! / (unit?.toBase ?? 1), unitId);
  }

  String _displayUnit(ShoppingLine line) {
    switch (line.family) {
      case 'mass':
        return (line.total ?? 0) >= 1000 ? 'kg' : 'g';
      case 'volume':
        final total = line.total ?? 0;
        if (line.sourceUnits.length == 1) {
          final only = line.sourceUnits.first;
          // keep the author's unit unless it grew unwieldy
          if (!(only == 'tsp' && total >= 45) && !(only == 'tbsp' && total >= 240)) return only;
        }
        if (total < 15) return 'tsp';
        if (total < 120) return 'tbsp';
        return total >= 1000 ? 'l' : 'ml';
      case 'taste':
        return 'to-taste';
      case 'count:pc':
        return 'pc';
      default:
        return line.sourceUnits.first;
    }
  }

  /// Groups lines by aisle in store-walk order, alphabetical inside an aisle.
  List<AislePart> groupByAisle(List<ShoppingLine> lines, String lang) {
    final byAisle = <String, List<ShoppingLine>>{};
    for (final l in lines) {
      byAisle.putIfAbsent(l.aisle, () => []).add(l);
    }
    final order = [for (final a in ontology.aisles) a.id];
    final keys = byAisle.keys.toList()
      ..sort((a, b) {
        final ia = order.indexOf(a), ib = order.indexOf(b);
        return (ia < 0 ? 999 : ia).compareTo(ib < 0 ? 999 : ib);
      });
    return [
      for (final k in keys)
        AislePart(
          k,
          byAisle[k]!..sort((a, b) => tree.name(a.ingredientId, lang).compareTo(tree.name(b.ingredientId, lang))),
        ),
    ];
  }
}
