import '../../data/models/ingredient.dart';
import '../../data/models/ontology.dart';
import '../../data/models/recipe.dart';
import '../../core/text/text_fold.dart';
import 'amounts.dart';

/// An amount with a unit id (`g`, `tbsp`, `clove`, ...).
class Quantity {
  const Quantity(this.amount, this.unit);

  final double amount;
  final String unit;

  @override
  bool operator ==(Object other) => other is Quantity && (other.amount - amount).abs() < 1e-6 && other.unit == unit;

  @override
  int get hashCode => Object.hash(amount.toStringAsFixed(4), unit);

  @override
  String toString() => 'Quantity($amount $unit)';
}

/// A recipe on the shopping list, cooked for [servings] people.
class ShoppingSource {
  const ShoppingSource({required this.recipe, required this.servings});

  final Recipe recipe;
  final double servings;

  double get scale => recipe.servings == 0 ? 1 : servings / recipe.servings;
}

/// A line the cook added by hand.
class ManualItem {
  const ManualItem({required this.id, required this.label, this.ingredientId, this.amount, this.unit});

  final String id;

  /// Free text, used when there is no dictionary [ingredientId].
  final String label;
  final String? ingredientId;
  final double? amount;
  final String? unit;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'label': label,
    if (ingredientId != null) 'ingredient_id': ingredientId,
    if (amount != null) 'amount': amount,
    if (unit != null) 'unit': unit,
  };

  factory ManualItem.fromJson(Map<String, dynamic> json) => ManualItem(
    id: json['id'] as String,
    label: (json['label'] as String?) ?? '',
    ingredientId: json['ingredient_id'] as String?,
    amount: (json['amount'] as num?)?.toDouble(),
    unit: json['unit'] as String?,
  );
}

/// One aggregated line: one ingredient with its merged quantities.
class ShoppingLine {
  const ShoppingLine({
    required this.key,
    required this.aisle,
    required this.quantities,
    required this.toTaste,
    required this.recipeIds,
    this.ingredientId,
    this.label = '',
  });

  /// Stable id used for the check-off state.
  final String key;
  final String? ingredientId;

  /// Text of a free-form manual line.
  final String label;
  final String aisle;
  final List<Quantity> quantities;

  /// The ingredient also appears somewhere without an amount ("salt, to taste").
  final bool toTaste;
  final Set<String> recipeIds;

  /// Text of the amounts, such as `5 cloves` or `2 tbsp + 30 g`.
  String amountText(Ontology ontology, IngredientDictionary dictionary, String lang) {
    final parts = <String>[];
    for (final q in quantities) {
      final unit = ontology.unit(q.unit);
      final number = AmountFormatter.format(q.amount, q.unit, lang);
      final plural = (AmountFormatter.roundFor(q.amount, q.unit) - 1).abs() > 1e-9;
      final unitLabel = unit?.label(lang, plural: plural) ?? q.unit;
      parts.add(unitLabel.isEmpty ? number : '$number $unitLabel');
    }
    return parts.join(' + ');
  }

  /// Display name; pieces read naturally in plural (`3 onions`).
  String nameText(IngredientDictionary dictionary, Ontology ontology, String lang) {
    final id = ingredientId;
    if (id == null) return label;
    final onlyPieces = quantities.length == 1 && quantities.first.unit == 'piece';
    final plural = onlyPieces && (AmountFormatter.roundFor(quantities.first.amount, 'piece') - 1).abs() > 1e-9;
    return dictionary.nameOf(id, lang, plural: plural);
  }
}

class AisleGroup {
  const AisleGroup({required this.aisle, required this.lines});
  final AisleDef aisle;
  final List<ShoppingLine> lines;
}

/// Unit-aware aggregation of the ingredients of several recipes.
///
/// `garlic 2 cloves + garlic 3 cloves = 5 cloves`, `1 tbsp + 30 ml` collapses
/// into one volume, and mass and volume merge when the dictionary knows the
/// ingredient's density.
class ShoppingAggregator {
  const ShoppingAggregator(this.ontology, this.dictionary);

  final Ontology ontology;
  final IngredientDictionary dictionary;

  List<ShoppingLine> aggregate(Iterable<ShoppingSource> sources, {Iterable<ManualItem> manual = const <ManualItem>[]}) {
    final quantities = <String, List<Quantity>>{};
    final toTaste = <String>{};
    final recipeIds = <String, Set<String>>{};
    final manualFree = <ManualItem>[];

    for (final source in sources) {
      for (final line in source.recipe.ingredients) {
        if (!dictionary.includeInShopping(line.id)) continue;
        recipeIds.putIfAbsent(line.id, () => <String>{}).add(source.recipe.id);
        final amount = line.amount;
        if (amount == null || (ontology.unit(line.unit)?.isFree ?? false)) {
          toTaste.add(line.id);
          continue;
        }
        (quantities[line.id] ??= <Quantity>[]).add(Quantity(amount * source.scale, line.unit));
      }
    }
    for (final item in manual) {
      final id = item.ingredientId;
      if (id == null || !dictionary.contains(id)) {
        manualFree.add(item);
        continue;
      }
      recipeIds.putIfAbsent(id, () => <String>{});
      final amount = item.amount;
      if (amount == null) {
        toTaste.add(id);
      } else {
        (quantities[id] ??= <Quantity>[]).add(Quantity(amount, item.unit ?? 'piece'));
      }
    }

    final lines = <ShoppingLine>[];
    for (final id in recipeIds.keys) {
      final merged = mergeQuantities(id, quantities[id] ?? const <Quantity>[]);
      lines.add(
        ShoppingLine(
          key: id,
          ingredientId: id,
          aisle: dictionary.aisleOf(id),
          quantities: merged,
          toTaste: toTaste.contains(id) && merged.isEmpty,
          recipeIds: recipeIds[id]!,
        ),
      );
    }
    for (final item in manualFree) {
      lines.add(
        ShoppingLine(
          key: 'manual:${item.id}',
          aisle: 'other',
          label: item.label,
          quantities: item.amount == null ? const <Quantity>[] : [Quantity(item.amount!, item.unit ?? 'piece')],
          toTaste: item.amount == null,
          recipeIds: const <String>{},
        ),
      );
    }
    return lines;
  }

  /// Groups lines by aisle in shopping-route order, alphabetical within an aisle.
  List<AisleGroup> group(List<ShoppingLine> lines, String lang) {
    final byAisle = <String, List<ShoppingLine>>{};
    for (final line in lines) {
      (byAisle[line.aisle] ??= <ShoppingLine>[]).add(line);
    }
    final groups = <AisleGroup>[];
    for (final aisle in ontology.aisles) {
      final inAisle = byAisle.remove(aisle.id);
      if (inAisle == null) continue;
      inAisle.sort((a, b) => _sortName(a, lang).compareTo(_sortName(b, lang)));
      groups.add(AisleGroup(aisle: aisle, lines: inAisle));
    }
    for (final entry in byAisle.entries) {
      groups.add(
        AisleGroup(
          aisle: AisleDef(id: entry.key, name: ontology.nameOf(entry.key)),
          lines: entry.value..sort((a, b) => _sortName(a, lang).compareTo(_sortName(b, lang))),
        ),
      );
    }
    return groups;
  }

  String _sortName(ShoppingLine line, String lang) {
    final id = line.ingredientId;
    return TextFold.fold(id == null ? line.label : dictionary.nameOf(id, lang));
  }

  /// Merges the quantities of one ingredient.
  ///
  /// Mass units add up in grams, volume units in millilitres (`tbsp`, `tsp`,
  /// `cup`, `ml` and `l` all convert). With a known density mass and volume are
  /// merged into grams. Count units (`clove`, `piece`, ...) only merge with the
  /// same unit.
  List<Quantity> mergeQuantities(String? ingredientId, Iterable<Quantity> input) {
    var grams = 0.0;
    var millilitres = 0.0;
    final volumeUnits = <String>{};
    final counts = <String, double>{};

    for (final q in input) {
      final unit = ontology.unit(q.unit);
      if (unit == null) {
        counts[q.unit] = (counts[q.unit] ?? 0) + q.amount;
      } else if (unit.isMass) {
        grams += q.amount * unit.toBase!;
      } else if (unit.isVolume) {
        millilitres += q.amount * unit.toBase!;
        volumeUnits.add(q.unit);
      } else if (unit.isCount) {
        counts[q.unit] = (counts[q.unit] ?? 0) + q.amount;
      }
    }

    final density = ingredientId == null ? null : dictionary.densityOf(ingredientId);
    if (grams > 0 && millilitres > 0 && density != null) {
      grams += millilitres * density;
      millilitres = 0;
      volumeUnits.clear();
    }

    final out = <Quantity>[];
    if (grams > 0) {
      out.add(grams >= 1000 ? Quantity(grams / 1000, 'kg') : Quantity(grams, 'g'));
    }
    if (millilitres > 0) out.add(_displayVolume(millilitres, volumeUnits));
    for (final entry in counts.entries) {
      out.add(Quantity(entry.value, entry.key));
    }
    return out;
  }

  Quantity _displayVolume(double ml, Set<String> used) {
    if (used.contains('ml') || used.contains('l')) {
      return ml >= 1000 ? Quantity(ml / 1000, 'l') : Quantity(ml, 'ml');
    }
    // Only kitchen units: express in the largest used unit that reads naturally.
    final byBase = used.toList()..sort((a, b) => ontology.unit(b)!.toBase!.compareTo(ontology.unit(a)!.toBase!));
    for (final id in byBase) {
      final value = ml / ontology.unit(id)!.toBase!;
      if (value >= 1 && AmountFormatter.isNice(value)) return Quantity(value, id);
    }
    final smallest = byBase.last;
    return Quantity(ml / ontology.unit(smallest)!.toBase!, smallest);
  }
}
