// Smart shopping list: unit-aware aggregation across recipes, dedup,
// grouped by aisle. "garlic 2 cloves + garlic 3 cloves = 5 cloves";
// ml ↔ tbsp ↔ tsp ↔ cup ↔ l inside the volume class; g ↔ kg inside mass.
import '../data/models/ingredient.dart';
import '../data/models/ltext.dart';
import '../data/models/ontology.dart';
import '../data/models/recipe.dart';

class ShoppingInput {
  const ShoppingInput({required this.recipe, required this.servings});
  final Recipe recipe;
  final int servings;
}

class AggregatedLine {
  const AggregatedLine({
    required this.key,
    required this.ingredientId,
    required this.aisle,
    required this.unitClass,
    required this.baseAmount,
    required this.displayAmount,
    required this.displayUnit,
    required this.sourceRecipeIds,
    required this.originalUnits,
    this.notes = const [],
  });

  final String key;
  final String ingredientId;
  final String aisle;
  final UnitClass unitClass;

  /// Sum in the class base unit (g / ml / count); null for "to taste".
  final double? baseAmount;
  final double? displayAmount;
  final String displayUnit;
  final Set<String> sourceRecipeIds;
  final Set<String> originalUnits;
  final List<String> notes;
}

class AisleGroup {
  const AisleGroup({required this.aisle, required this.lines});
  final Aisle aisle;
  final List<AggregatedLine> lines;
}

class ShoppingAggregator {
  ShoppingAggregator({required this.ontology, required this.dictionary});
  final Ontology ontology;
  final IngredientDictionary dictionary;

  List<AggregatedLine> aggregate(Iterable<ShoppingInput> inputs, {String lang = 'en'}) {
    final acc = <String, _Acc>{};
    for (final input in inputs) {
      final r = input.recipe;
      final factor = r.servings == 0 ? 1.0 : input.servings / r.servings;
      for (final ing in r.ingredients) {
        final unit = ontology.unitById[ing.unit];
        final cls = unit?.unitClass ?? UnitClass.none;
        final amountless = ing.amount == null || cls == UnitClass.none;
        final key = amountless
            ? '${ing.id}|none'
            : cls == UnitClass.count
                ? '${ing.id}|count|${ing.unit}'
                : '${ing.id}|${cls.name}';
        final a = acc.putIfAbsent(key, () => _Acc(ing.id, cls, amountless ? ing.unit : (cls == UnitClass.count ? ing.unit : null)));
        if (!amountless) a.base += ing.amount! * (unit?.toBase ?? 1) * factor;
        a.sources.add(r.id);
        a.units.add(ing.unit);
        final note = ing.note.of(lang);
        if (note.isNotEmpty && !a.notes.contains(note)) a.notes.add(note);
      }
    }
    final lines = <AggregatedLine>[];
    for (final e in acc.entries) {
      final a = e.value;
      final node = dictionary.byId[a.ingredientId];
      final (amount, unit) = _display(a);
      lines.add(AggregatedLine(
        key: e.key,
        ingredientId: a.ingredientId,
        aisle: node?.aisle ?? 'pantry',
        unitClass: a.cls,
        baseAmount: a.countUnit != null && a.cls == UnitClass.none ? null : a.base,
        displayAmount: amount,
        displayUnit: unit,
        sourceRecipeIds: a.sources,
        originalUnits: a.units,
        notes: a.notes,
      ));
    }
    lines.sort((x, y) {
      final ax = _aisleOrder(x.aisle), ay = _aisleOrder(y.aisle);
      if (ax != ay) return ax.compareTo(ay);
      return _name(x.ingredientId, lang).compareTo(_name(y.ingredientId, lang));
    });
    return lines;
  }

  List<AisleGroup> groupByAisle(List<AggregatedLine> lines) {
    final groups = <String, List<AggregatedLine>>{};
    for (final l in lines) {
      groups.putIfAbsent(l.aisle, () => []).add(l);
    }
    final out = [
      for (final e in groups.entries)
        AisleGroup(aisle: ontology.aisleById[e.key] ?? Aisle(id: e.key, label: LText({'en': e.key}), order: 99), lines: e.value),
    ]..sort((a, b) => a.aisle.order.compareTo(b.aisle.order));
    return out;
  }

  int _aisleOrder(String id) => ontology.aisleById[id]?.order ?? 99;
  String _name(String id, String lang) => dictionary.byId[id]?.name.of(lang) ?? id;

  (double?, String) _display(_Acc a) {
    switch (a.cls) {
      case UnitClass.none:
        return (null, a.countUnit ?? 'to-taste');
      case UnitClass.count:
        return (a.base, a.countUnit ?? 'piece');
      case UnitClass.mass:
        if (a.base >= 1000) return (_round(a.base / 1000, 2), 'kg');
        return (_round(a.base, 0), 'g');
      case UnitClass.volume:
        final spoonsOnly = a.units.every((u) => u == 'tsp' || u == 'tbsp');
        if (a.base >= 1000) return (_round(a.base / 1000, 2), 'l');
        if (spoonsOnly && a.base <= 90) {
          if (a.base < 15 && a.base % 5 == 0) return (_round(a.base / 5, 1), 'tsp');
          return (_round(a.base / 15, 1), 'tbsp');
        }
        return (_round(a.base, 0), 'ml');
    }
  }

  static double _round(double v, int decimals) {
    var f = 1.0;
    for (var i = 0; i < decimals; i++) {
      f *= 10;
    }
    return (v * f).roundToDouble() / f;
  }
}

class _Acc {
  _Acc(this.ingredientId, this.cls, this.countUnit);
  final String ingredientId;
  final UnitClass cls;
  final String? countUnit;
  double base = 0;
  final Set<String> sources = {};
  final Set<String> units = {};
  final List<String> notes = [];
}

/// Formats amounts the way a handwritten list would: 0.5 → ½, 1.0 → 1,
/// 1.5 → 1½, 250.0 → 250, 1.25 → 1.25.
String formatAmount(double? amount) {
  if (amount == null) return '';
  final whole = amount.floor();
  final frac = amount - whole;
  const fractions = [(0.25, '¼'), (0.5, '½'), (0.75, '¾'), (0.33, '⅓'), (0.67, '⅔')];
  String? fracStr;
  for (final (value, glyph) in fractions) {
    if ((frac - value).abs() < 0.02) fracStr = glyph;
  }
  if (fracStr != null) return whole == 0 ? fracStr : '$whole$fracStr';
  if (frac.abs() < 0.001) return '$whole';
  final s = amount.toStringAsFixed(amount < 10 ? 2 : 1);
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}
