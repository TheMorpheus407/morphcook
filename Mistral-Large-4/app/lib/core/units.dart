import 'model/recipe.dart';
import 'model/shopping.dart';

/// Unit families. Only units within a family convert into each other;
/// counts (cloves, pieces) never convert into mass or volume.
enum UnitFamily { mass, volume, count, other }

class Units {
  Units._();

  static UnitFamily familyOf(String unit) {
    switch (unit) {
      case 'g':
      case 'kg':
        return UnitFamily.mass;
      case 'ml':
      case 'l':
      case 'tbsp':
      case 'tsp':
        return UnitFamily.volume;
      case 'clove':
      case 'cloves':
      case 'piece':
      case 'pieces':
      case 'slice':
      case 'slices':
      case 'pinch':
      case 'bunch':
      case 'can':
      case 'cans':
      case 'pack':
      case 'packs':
        return UnitFamily.count;
      default:
        return UnitFamily.other;
    }
  }

  static bool convertible(String a, String b) =>
      a == b || familyOf(a) == familyOf(b) && familyOf(a) != UnitFamily.other;

  /// Convert [amount] from [from] to [to]. Throws [ArgumentError] when the
  /// units are not convertible.
  static double convert(double amount, String from, String to) {
    if (from == to) return amount;
    if (!convertible(from, to)) {
      throw ArgumentError('cannot convert $from to $to');
    }
    final canonicalFrom = _canonical(from);
    final canonicalTo = _canonical(to);
    if (canonicalFrom == null || canonicalTo == null) {
      throw ArgumentError('cannot convert $from to $to');
    }
    final base = amount * canonicalFrom.$2; // to base unit
    return base / canonicalTo.$2;
  }

  /// Base-unit factors: g for mass, ml for volume, pieces for count.
  static (String, double)? _canonical(String unit) {
    switch (unit) {
      case 'g':
        return ('g', 1);
      case 'kg':
        return ('g', 1000);
      case 'ml':
        return ('ml', 1);
      case 'l':
        return ('ml', 1000);
      case 'tbsp':
        return ('ml', 15);
      case 'tsp':
        return ('ml', 5);
      default:
        final family = familyOf(unit);
        if (family == UnitFamily.count) return (unit, 1);
        return null;
    }
  }

  /// The nicer display unit when merging: prefer the larger unit of the family
  /// when the converted amount reaches it.
  static String displayUnit(double amount, String unit) {
    final family = familyOf(unit);
    if (family == UnitFamily.mass && unit == 'g' && amount >= 1000) return 'kg';
    if (family == UnitFamily.volume && unit == 'ml' && amount >= 1000) return 'l';
    return unit;
  }

  static double displayAmount(double amount, String unit) {
    final family = familyOf(unit);
    if (family == UnitFamily.mass && unit == 'g' && amount >= 1000) {
      return amount / 1000;
    }
    if (family == UnitFamily.volume && unit == 'ml' && amount >= 1000) {
      return amount / 1000;
    }
    return amount;
  }

  static String formatAmount(double amount) {
    if (amount == amount.roundToDouble()) return amount.toInt().toString();
    // halves and quarters stay readable (½, ¼, ¾)
    final fractions = <double, String>{0.25: '¼', 0.5: '½', 0.75: '¾'};
    final whole = amount.floor();
    final frac = amount - whole;
    final fracStr = fractions[frac];
    if (fracStr != null) {
      return whole == 0 ? fracStr : '$whole$fracStr';
    }
    return amount.toStringAsFixed(1);
  }

  /// Format an amount + unit, upgrading to the display unit when sensible.
  /// Upgraded amounts render as plain decimals (1.5 kg); same-unit amounts
  /// keep the fraction glyphs (½ tsp).
  static String format(double amount, String unit) {
    final display = displayUnit(amount, unit);
    if (display == unit) return '${formatAmount(amount)} $unit';
    final value = displayAmount(amount, unit);
    final text = value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
    return '$text $display';
  }
}

/// Smart aggregation: merge shopping lines by ingredient, converting units
/// within a family (`ml ↔ tbsp`, `g ↔ kg`, `tsp ↔ ml`, `l ↔ ml`). Count units
/// only merge with the identical unit. Returns one line per ingredient, in
/// first-seen order.
class ShoppingAggregator {
  const ShoppingAggregator();

  /// Merge [lines] (ingredientId, amount, unit, recipeId) into ShoppingItems.
  List<ShoppingItem> aggregate(
    List<({String ingredientId, double amount, String unit, String? recipeId})> lines, {
    required DateTime addedAt,
  }) {
    final order = <String>[];
    final totals = <String, double>{};
    final units = <String, String>{};
    final sources = <String, Set<String>>{};

    for (final line in lines) {
      final id = line.ingredientId;
      if (!totals.containsKey(id)) {
        order.add(id);
        totals[id] = 0;
        units[id] = line.unit;
        sources[id] = <String>{};
      }
      final currentUnit = units[id]!;
      final amount = Units.convertible(currentUnit, line.unit)
          ? Units.convert(line.amount, line.unit, currentUnit)
          : line.amount;
      if (!Units.convertible(currentUnit, line.unit)) {
        // Incompatible units: keep the first line's unit and add raw amounts
        // only when they already share a unit; otherwise keep the larger line.
        if (line.unit != currentUnit) {
          if (line.amount > totals[id]!) {
            totals[id] = line.amount;
            units[id] = line.unit;
          }
        } else {
          totals[id] = totals[id]! + amount;
        }
      } else {
        totals[id] = totals[id]! + amount;
      }
      if (line.recipeId != null) sources[id]!.add(line.recipeId!);
    }

    return [
      for (final id in order)
        ShoppingItem(
          ingredientId: id,
          amount: totals[id]!,
          unit: Units.displayUnit(totals[id]!, units[id]!),
          sourceRecipeIds: sources[id]!.toList(),
          addedAt: addedAt,
        ),
    ];
  }

  /// Aggregate a recipe's ingredient lines (scaled to [servings]) into lines.
  List<({String ingredientId, double amount, String unit, String? recipeId})>
      linesFromRecipe(Recipe recipe, int servings) {
    final factor = servings / recipe.servings;
    return [
      for (final line in recipe.ingredients)
        (
          ingredientId: line.ingredientId,
          amount: line.amount * factor,
          unit: line.unit,
          recipeId: recipe.id,
        ),
    ];
  }
}
