import '../data/corpus.dart';
import '../models/models.dart';

/// Canonical unit handling: everything is summed in a base unit per class,
/// then converted back to the most readable unit.

enum UnitClass { volume, weight, count }

class UnitDef {
  final String key; // canonical unit key (en)
  final String de;
  final UnitClass cls;
  final double factorToBase; // volume: ml, weight: g, count: 1
  final double displayFactor; // unit per 1 base (used for re-render)

  const UnitDef({
    required this.key,
    required this.de,
    required this.cls,
    required this.factorToBase,
    required this.displayFactor,
  });
}

const unitDefinitions = <UnitDef>[
  // volume (base: ml)
  UnitDef(key: 'ml', de: 'ml', cls: UnitClass.volume, factorToBase: 1, displayFactor: 1),
  UnitDef(key: 'tsp', de: 'tl', cls: UnitClass.volume, factorToBase: 5, displayFactor: 0.2),
  UnitDef(key: 'tbsp', de: 'EL', cls: UnitClass.volume, factorToBase: 15, displayFactor: 1 / 15),
  UnitDef(key: 'cup', de: 'Tasse', cls: UnitClass.volume, factorToBase: 240, displayFactor: 1 / 240),
  UnitDef(key: 'l', de: 'l', cls: UnitClass.volume, factorToBase: 1000, displayFactor: 1 / 1000),
  // weight (base: g)
  UnitDef(key: 'g', de: 'g', cls: UnitClass.weight, factorToBase: 1, displayFactor: 1),
  UnitDef(key: 'kg', de: 'kg', cls: UnitClass.weight, factorToBase: 1000, displayFactor: 1 / 1000),
];

const _countUnits = [
  'clove', 'piece', 'slice', 'head', 'can', 'punnet', 'handful', 'bunch',
  'stalk', 'leaf', 'sprig', 'stick', 'jar', 'bag', 'pack', 'packet', 'pinch',
];

final _countUnitLabels = <String, Map<String, String>>{
  'clove': {'en': 'clove(s)', 'de': 'Zehe(n)'},
  'piece': {'en': 'piece(s)', 'de': 'Stück'},
  'slice': {'en': 'slice(s)', 'de': 'Scheibe(n)'},
  'head': {'en': 'head(s)', 'de': 'Kopf'},
  'can': {'en': 'can(s)', 'de': 'Dose(n)'},
  'punnet': {'en': 'punnet(s)', 'de': 'Schale(n)'},
  'handful': {'en': 'handful(s)', 'de': 'Handvoll'},
  'bunch': {'en': 'bunch(es)', 'de': 'Bund'},
  'stalk': {'en': 'stalk(s)', 'de': 'Stange(n)'},
  'leaf': {'en': 'leaf/leaves', 'de': 'Blatt'},
  'sprig': {'en': 'sprig(s)', 'de': 'Zweig(e)'},
  'stick': {'en': 'stick(s)', 'de': 'Stange(n)'},
  'jar': {'en': 'jar(s)', 'de': 'Glas'}, // Gläser
  'bag': {'en': 'bag(s)', 'de': 'Beutel'},
  'pack': {'en': 'pack(s)', 'de': 'Packung(en)'},
  'packet': {'en': 'packet(s)', 'de': 'Päckchen'},
  'pinch': {'en': 'pinch(es)', 'de': 'Prise(n)'},
};

/// Normalizes a unit string ("tbsp", "EL", "Zehe", "clove") to a canonical
/// UnitDef for volume/weight, or a count-unit key.
class UnitConverter {
  static UnitDef? defFor(String raw) {
    final s = raw.trim().toLowerCase();
    switch (s) {
      case 'ml':
      case 'milliliter':
      case 'milliliters':
      case 'millilitre':
      case 'millilitres':
      case 'milliliter(s)':
        return _def('ml');
      case 'l':
      case 'liter':
      case 'liters':
      case 'litre':
      case 'litres':
      case 'ltr':
        return _def('l');
      case 'tbsp':
      case 'tablespoon':
      case 'tablespoons':
      case 'el':
      case 'esslöffel':
      case 'essloffel':
        return _def('tbsp');
      case 'tsp':
      case 'teaspoon':
      case 'teaspoons':
      case 'tl':
      case 'teelöffel':
      case 'teeloffel':
        return _def('tsp');
      case 'cup':
      case 'cups':
      case 'tasse':
      case 'tassen':
        return _def('cup');
      case 'g':
      case 'gramm':
      case 'gram':
      case 'grams':
      case 'gr':
        return _def('g');
      case 'kg':
      case 'kilo':
      case 'kilogramm':
      case 'kilogram':
      case 'kilograms':
        return _def('kg');
    }
    if (_countUnits.contains(s)) return null; // count unit, handled separately
    return null;
  }

  static UnitDef _def(String key) => unitDefinitions.firstWhere((u) => u.key == key);

  /// True when the raw string is a known count unit.
  static bool isCountUnit(String raw) {
    final s = raw.trim().toLowerCase();
    return _countUnits.contains(s) || defFor(s) == null;
  }

  static String countLabel(String raw, String lang) {
    final s = raw.trim().toLowerCase();
    final map = _countUnitLabels[s];
    if (map != null) return map[lang] ?? map['en']!;
    return raw; // unknown -> show as-is
  }
}

/// Groups [ShoppingLine]s into one aggregated, aisle-ordered list.
/// Pure logic — unit-testable without Flutter.
class ShoppingAggregator {
  final Corpus corpus;

  ShoppingAggregator(this.corpus);

  List<ShoppingItem> build(
    List<ShoppingLine> lines,
    String lang,
  ) {
    // pass 1: expand each line into raw amounts
    final rows = <({String ing, UnitClass cls, String unit, double amount})>[];
    for (final line in lines) {
      final recipe = corpus.recipeById(line.recipeId);
      if (recipe == null) continue;
      final scale = (line.servings ?? recipe.servings) / recipe.servings;
      for (final ref in recipe.ingredients) {
        final amount = ref.amount * scale;
        final def = UnitConverter.defFor(ref.unit);
        if (def == null) {
          // count unit (or unknown) — keyed by unit string, same-unit sums
          rows.add((
            ing: ref.id,
            cls: UnitClass.count,
            unit: ref.unit.toLowerCase(),
            amount: amount,
          ));
        } else {
          rows.add((
            ing: ref.id,
            cls: def.cls,
            unit: def.key,
            amount: amount * def.factorToBase, // to base
          ));
        }
      }
    }

    // pass 2: aggregate
    final vol = <String, double>{};
    final weight = <String, double>{};
    final count = <String, Map<String, double>>{};
    final sources = <String, int>{};
    for (final r in rows) {
      if (r.cls == UnitClass.volume) {
        vol[r.ing] = (vol[r.ing] ?? 0) + r.amount;
        sources[r.ing] = (sources[r.ing] ?? 0) + 1;
      } else if (r.cls == UnitClass.weight) {
        weight[r.ing] = (weight[r.ing] ?? 0) + r.amount;
        sources[r.ing] = (sources[r.ing] ?? 0) + 1;
      } else {
        final m = count.putIfAbsent(r.ing, () => {});
        m[r.unit] = (m[r.unit] ?? 0) + r.amount;
        sources[r.ing] = (sources[r.ing] ?? 0) + 1;
      }
    }

    // pass 3: build items
    final items = <ShoppingItem>[];
    final aisleOrder = corpus.aisleOrder;

    String aisleFor(String ingId) {
      final node = corpus.ingredientsById[ingId];
      if (node == null) return 'misc';
      return node.aisle;
    }

    // volume
    vol.forEach((ing, base) {
      items.add(ShoppingItem(
        ingredientId: ing,
        aisle: aisleFor(ing),
        amount: base >= 1000 ? base / 1000 : base,
        unit: base >= 1000 ? 'l' : 'ml',
        sourceCount: sources[ing] ?? 1,
      ));
    });
    // weight
    weight.forEach((ing, base) {
      items.add(ShoppingItem(
        ingredientId: ing,
        aisle: aisleFor(ing),
        amount: base >= 1000 ? base / 1000 : base,
        unit: base >= 1000 ? 'kg' : 'g',
        sourceCount: sources[ing] ?? 1,
      ));
    });
    // count: one item per ingredient+unit combo
    count.forEach((ing, byUnit) {
      byUnit.forEach((unit, amount) {
        items.add(ShoppingItem(
          ingredientId: ing,
          aisle: aisleFor(ing),
          amount: amount,
          unit: unit,
          sourceCount: sources[ing] ?? 1,
        ));
      });
    });

    // pass 4: order by aisle order, then label
    items.sort((a, b) {
      final ia = aisleOrder.indexOf(a.aisle);
      final ib = aisleOrder.indexOf(b.aisle);
      if (ia != ib) return ia.compareTo(ib);
      final la = corpus.labelOf(a.ingredientId, lang);
      final lb = corpus.labelOf(b.ingredientId, lang);
      return la.compareTo(lb);
    });

    return items;
  }
}
