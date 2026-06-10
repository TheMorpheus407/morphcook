import '../core/localized.dart';
import '../models/ingredient_dict.dart';
import '../models/recipe.dart';
import 'unit_conversion.dart';

/// One aggregated shopping line for a single ingredient. May carry several
/// quantity buckets when units don't convert (e.g. "2 cloves" + "100 g").
class ShoppingLine {
  ShoppingLine({
    required this.ingredientId,
    required this.name,
    required this.quantities,
    this.recipeNames = const [],
    this.checked = false,
  });

  final String ingredientId;
  final LocalizedText name;

  /// Display strings like `["5 cloves"]` or `["250 ml", "2 pinch"]`.
  final List<String> quantities;

  /// Which recipes contributed (for the "from N recipes" subtitle).
  final List<String> recipeNames;
  bool checked;

  String quantityLabel() => quantities.join(' + ');
}

class AisleGroup {
  AisleGroup(this.aisleId, this.label, this.lines);
  final String aisleId;
  final LocalizedText label;
  final List<ShoppingLine> lines;
}

/// Maps the dictionary's top-level category to a shopping aisle.
const Map<String, String> _rootToAisle = {
  'dairy': 'dairy',
  'egg': 'dairy',
  'meat': 'meat-fish',
  'seafood': 'meat-fish',
  'plant-protein': 'pantry',
  'nuts': 'pantry',
  'grains': 'bakery-grains',
  'vegetables': 'produce',
  'herbs': 'produce',
  'fruit': 'produce',
  'pantry': 'pantry',
};

const Map<String, LocalizedText> kAisleLabels = {
  'produce': LocalizedText({'en': 'Produce', 'de': 'Obst & Gemüse'}),
  'dairy': LocalizedText({'en': 'Dairy & Eggs', 'de': 'Milch & Eier'}),
  'meat-fish': LocalizedText({'en': 'Meat & Fish', 'de': 'Fleisch & Fisch'}),
  'bakery-grains':
      LocalizedText({'en': 'Bakery & Grains', 'de': 'Backwaren & Getreide'}),
  'pantry': LocalizedText({'en': 'Pantry', 'de': 'Vorratskammer'}),
  'other': LocalizedText({'en': 'Other', 'de': 'Sonstiges'}),
};

/// The "request" to aggregate: a recipe plus how many servings the user wants
/// (scales each ingredient quantity).
class ShoppingRequest {
  ShoppingRequest(this.recipe, this.targetServings);
  final Recipe recipe;
  final int targetServings;
}

class ShoppingAggregator {
  ShoppingAggregator(this.dict);
  final IngredientDict dict;

  String _aisleFor(String ingredientId) {
    var node = dict.node(ingredientId);
    if (node == null) return 'other';
    while (node!.parent != null) {
      node = node.parent!;
    }
    return _rootToAisle[node.id] ?? 'other';
  }

  /// Aggregate ingredients across requests: scale by servings, sum compatible
  /// units, dedup by ingredient, group by aisle.
  List<AisleGroup> aggregate(List<ShoppingRequest> requests, AppLang lang) {
    // ingredientId -> bucketKey -> accumulated base qty + display unit choice
    final byIngredient = <String, _Acc>{};

    for (final req in requests) {
      final scale = req.recipe.servings == 0
          ? 1.0
          : req.targetServings / req.recipe.servings;
      for (final ing in req.recipe.ingredients) {
        final acc = byIngredient.putIfAbsent(
          ing.ingredientId,
          () => _Acc(ing.ingredientId, ing.name),
        );
        acc.recipeNames.add(req.recipe.name.resolve(lang));
        final scaledQty = ing.qty * scale;
        final dim = UnitConversion.dimensionOf(ing.unit);
        final key = UnitConversion.bucketKey(ing.unit);
        final bucket = acc.buckets.putIfAbsent(
          key,
          () => _Bucket(dim, ing.unit),
        );
        if (dim == UnitDimension.count || dim == null) {
          bucket.total += scaledQty; // counts of same unit just add
        } else {
          // convert to base unit of the dimension
          final base = UnitConversion.convert(scaledQty, ing.unit,
              dim == UnitDimension.volume ? 'ml' : 'g');
          bucket.total += base ?? scaledQty;
        }
      }
    }

    final aisles = <String, AisleGroup>{};
    for (final acc in byIngredient.values) {
      final quantities = <String>[];
      for (final bucket in acc.buckets.values) {
        if (bucket.dim == UnitDimension.volume) {
          final (q, u) = UnitConversion.humanize(bucket.total, UnitDimension.volume);
          quantities.add('${UnitConversion.fmtQty(q)} $u');
        } else if (bucket.dim == UnitDimension.mass) {
          final (q, u) = UnitConversion.humanize(bucket.total, UnitDimension.mass);
          quantities.add('${UnitConversion.fmtQty(q)} $u');
        } else {
          quantities.add('${UnitConversion.fmtQty(bucket.total)} ${bucket.unit}');
        }
      }
      final line = ShoppingLine(
        ingredientId: acc.ingredientId,
        name: acc.name,
        quantities: quantities,
        recipeNames: acc.recipeNames.toSet().toList(),
      );
      final aisleId = _aisleFor(acc.ingredientId);
      aisles
          .putIfAbsent(
            aisleId,
            () => AisleGroup(aisleId, kAisleLabels[aisleId]!, []),
          )
          .lines
          .add(line);
    }

    // stable aisle ordering matching a typical store walk
    const order = ['produce', 'bakery-grains', 'dairy', 'meat-fish', 'pantry', 'other'];
    final result = aisles.values.toList()
      ..sort((a, b) => order.indexOf(a.aisleId).compareTo(order.indexOf(b.aisleId)));
    for (final g in result) {
      g.lines.sort((a, b) => a.name.resolve(lang).compareTo(b.name.resolve(lang)));
    }
    return result;
  }
}

class _Acc {
  _Acc(this.ingredientId, this.name);
  final String ingredientId;
  final LocalizedText name;
  final Map<String, _Bucket> buckets = {};
  final List<String> recipeNames = [];
}

class _Bucket {
  _Bucket(this.dim, this.unit);
  final UnitDimension? dim;
  final String unit;
  double total = 0;
}
