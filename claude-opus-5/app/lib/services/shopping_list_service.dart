import '../domain/collections.dart';
import '../domain/models.dart';
import '../domain/units.dart';

/// One merged line, ready to render.
class ShoppingLine {
  const ShoppingLine({
    required this.ingredientId,
    required this.label,
    required this.aisle,
    required this.quantities,
    required this.sourceRecipeIds,
    required this.checked,
    required this.addedAt,
  });

  final String ingredientId;
  final Localized label;
  final String aisle;

  /// Usually one entry. More than one means the units could not be merged —
  /// "200 g" and "2 tbsp" of the same thing stay separate rather than being
  /// converted with a guessed density.
  final List<Quantity> quantities;

  final List<String> sourceRecipeIds;
  final bool checked;
  final DateTime addedAt;

  bool get isSplitByUnit => quantities.length > 1;

  String format(String lang) =>
      quantities.map((q) => UnitLabels.format(q, lang)).join(' + ');
}

class ShoppingGroup {
  const ShoppingGroup({
    required this.aisle,
    required this.label,
    required this.lines,
  });

  final String aisle;
  final Localized label;
  final List<ShoppingLine> lines;

  int get remaining => lines.where((l) => !l.checked).length;
}

/// Unit-aware aggregation across recipes.
///
/// "garlic 2 cloves + garlic 3 cloves = 5 cloves"; "15 ml + 1 tbsp = 30 ml".
/// Grams and millilitres never merge into each other.
class ShoppingListService {
  const ShoppingListService(this.ingredients);

  final IngredientDictionary ingredients;

  /// Expands recipes into shopping entries, scaled by servings if asked.
  List<ShoppingEntry> entriesForRecipes(
    Iterable<Recipe> recipes, {
    required DateTime now,
    Map<String, int> servingsOverride = const {},
    bool includeOptional = false,
  }) {
    final out = <ShoppingEntry>[];
    for (final recipe in recipes) {
      final wanted = servingsOverride[recipe.id];
      final factor = (wanted == null || recipe.servings == 0)
          ? 1.0
          : wanted / recipe.servings;
      for (final item in recipe.ingredients) {
        if (item.optional && !includeOptional) continue;
        final scaled = item.scaled(factor);
        out.add(
          ShoppingEntry(
            ingredientId: scaled.ingredientId,
            qty: scaled.qty,
            unit: scaled.unit,
            addedAt: now,
            sourceRecipeIds: [recipe.id],
          ),
        );
      }
    }
    return out;
  }

  /// Adds entries onto an existing list, merging where the units allow it.
  /// Re-adding the same recipe is a no-op, so "send week to shopping list"
  /// twice does not double the quantities.
  List<ShoppingEntry> merge(
    List<ShoppingEntry> existing,
    List<ShoppingEntry> incoming,
  ) {
    final alreadySourced = <String>{
      for (final e in existing) ...e.sourceRecipeIds,
    };
    final fresh = incoming
        .where(
          (e) =>
              e.sourceRecipeIds.isEmpty ||
              !e.sourceRecipeIds.every(alreadySourced.contains),
        )
        .toList();

    final out = List.of(existing);
    for (final entry in fresh) {
      final index = _findMergeTarget(out, entry);
      if (index < 0) {
        out.add(entry);
        continue;
      }
      final current = out[index];
      final a = _quantityOf(current);
      final b = _quantityOf(entry);
      if (a == null || b == null) {
        out.add(entry);
        continue;
      }
      final summed = a.tryAdd(b);
      if (summed == null) {
        out.add(entry);
        continue;
      }
      out[index] = ShoppingEntry(
        ingredientId: current.ingredientId,
        qty: summed.amount,
        unit: summed.unit,
        addedAt: current.addedAt,
        sourceRecipeIds: {
          ...current.sourceRecipeIds,
          ...entry.sourceRecipeIds,
        }.toList(),
        checked: current.checked,
        manual: current.manual,
      );
    }
    return out;
  }

  int _findMergeTarget(List<ShoppingEntry> list, ShoppingEntry candidate) {
    final cq = _quantityOf(candidate);
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      if (e.ingredientId != candidate.ingredientId) continue;
      final eq = _quantityOf(e);
      if (eq == null || cq == null) return i;
      if (eq.canMergeWith(cq)) return i;
    }
    return -1;
  }

  Quantity? _quantityOf(ShoppingEntry e) => e.qty == null
      ? null
      : Quantity(e.qty!, e.unit.isEmpty ? 'piece' : e.unit);

  /// Collapses to one line per ingredient and groups by supermarket aisle.
  List<ShoppingGroup> group(List<ShoppingEntry> entries, String lang) {
    final byIngredient = <String, List<ShoppingEntry>>{};
    for (final e in entries) {
      (byIngredient[e.ingredientId] ??= []).add(e);
    }

    final lines = <ShoppingLine>[];
    byIngredient.forEach((id, group) {
      final node = ingredients[id];
      final quantities = <Quantity>[];
      for (final e in group) {
        final q = _quantityOf(e);
        if (q == null) continue;
        var merged = false;
        for (var i = 0; i < quantities.length; i++) {
          final sum = quantities[i].tryAdd(q);
          if (sum != null) {
            quantities[i] = sum;
            merged = true;
            break;
          }
        }
        if (!merged) quantities.add(q);
      }
      lines.add(
        ShoppingLine(
          ingredientId: id,
          label: node?.label ?? Localized({'en': id}),
          aisle: node?.aisle ?? 'other',
          quantities: quantities,
          sourceRecipeIds: {
            for (final e in group) ...e.sourceRecipeIds,
          }.toList(),
          checked: group.every((e) => e.checked),
          addedAt: group
              .map((e) => e.addedAt)
              .reduce((a, b) => a.isBefore(b) ? a : b),
        ),
      );
    });

    final byAisle = <String, List<ShoppingLine>>{};
    for (final line in lines) {
      (byAisle[line.aisle] ??= []).add(line);
    }

    final groups = byAisle.entries.map((entry) {
      final sorted = entry.value
        ..sort((a, b) => a.label(lang).compareTo(b.label(lang)));
      return ShoppingGroup(
        aisle: entry.key,
        label: ingredients.aisleLabel(entry.key),
        lines: sorted,
      );
    }).toList();

    groups.sort(
      (a, b) => ingredients
          .aisleRank(a.aisle)
          .compareTo(ingredients.aisleRank(b.aisle)),
    );
    return groups;
  }
}
