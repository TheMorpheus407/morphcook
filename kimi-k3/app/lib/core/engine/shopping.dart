import '../models/local_text.dart';
import '../models/recipe.dart';

/// One aggregated shopping-list line.
class ShoppingItem {
  final String ingredientId;
  final LocalText name;
  final String aisle;
  double amount;
  final String unit;
  final Set<String> sourceRecipeIds;

  ShoppingItem({
    required this.ingredientId,
    required this.name,
    required this.aisle,
    required this.amount,
    required this.unit,
    Set<String>? sourceRecipeIds,
  }) : sourceRecipeIds = sourceRecipeIds ?? {};
}

/// Unit-aware aggregation: identical units sum; compatible units convert.
class ShoppingAggregator {
  /// Conversion table into a canonical unit per "kind".
  /// volume → ml, mass → g. count units only merge with themselves.
  static const _toCanonical = <String, (String kind, double factor)>{
    'ml': ('volume', 1),
    'l': ('volume', 1000),
    'tbsp': ('volume', 15),
    'tsp': ('volume', 5),
    'cup': ('volume', 240),
    'g': ('mass', 1),
    'kg': ('mass', 1000),
  };

  static const _countUnits = {'pcs', 'cloves', 'pinch'};

  /// Returns [amount] in [unit] expressed in the unit's canonical form, or
  /// null when the unit is a count unit (no conversion).
  (String, double)? _canonical(double amount, String unit) {
    final conv = _toCanonical[unit];
    if (conv == null) return null;
    return (conv.$1, amount * conv.$2);
  }

  /// Whether [from] can be merged into a line carrying unit [into], and the
  /// resulting display unit (prefers the "nicer" unit: tbsp/tsp over ml when
  /// the existing line uses them).
  bool compatible(String a, String b) {
    if (a == b) return true;
    final ca = _canonical(1, a);
    final cb = _canonical(1, b);
    if (ca == null || cb == null) return false;
    return ca.$1 == cb.$1;
  }

  double convert(double amount, String from, String to) {
    if (from == to) return amount;
    final ca = _canonical(amount, from);
    if (ca == null) return amount;
    final factorTo = _toCanonical[to]?.$2;
    if (factorTo == null) return amount;
    return ca.$2 / factorTo;
  }

  /// Aggregates the ingredient lists of [recipes] into deduped lines,
  /// grouped by aisle (returned sorted by aisle, then name).
  List<ShoppingItem> aggregate(Iterable<Recipe> recipes) {
    final lines = <ShoppingItem>[];
    for (final recipe in recipes) {
      for (final ing in recipe.ingredients) {
        var merged = false;
        for (final line in lines) {
          if (line.ingredientId != ing.id) continue;
          if (!compatible(line.unit, ing.unit)) continue;
          line.amount += convert(ing.amount, ing.unit, line.unit);
          line.sourceRecipeIds.add(recipe.id);
          merged = true;
          break;
        }
        if (!merged) {
          lines.add(ShoppingItem(
            ingredientId: ing.id,
            name: ing.name,
            aisle: ing.aisle,
            amount: ing.amount,
            unit: ing.unit,
            sourceRecipeIds: {recipe.id},
          ));
        }
      }
    }
    lines.sort((a, b) {
      final c = a.aisle.compareTo(b.aisle);
      if (c != 0) return c;
      return localize(a.name, 'en').compareTo(localize(b.name, 'en'));
    });
    return lines;
  }

  static bool isCountUnit(String unit) => _countUnits.contains(unit);
}

/// Shopping-insights analytics over add-to-list events.
class ShoppingInsights {
  /// Events: (ingredientId, timestamp millis).
  final List<({String ingredientId, int at})> events;

  ShoppingInsights(this.events);

  /// Variety score: unique ingredient count.
  int get varietyScore => events.map((e) => e.ingredientId).toSet().length;

  /// Top ingredients by add frequency.
  List<MapEntry<String, int>> topIngredients({int limit = 10}) {
    final counts = <String, int>{};
    for (final e in events) {
      counts[e.ingredientId] = (counts[e.ingredientId] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).toList();
  }

  /// Seasonal breakdown: month (1-12) → add count.
  Map<int, int> byMonth() {
    final out = <int, int>{};
    for (final e in events) {
      final month = DateTime.fromMillisecondsSinceEpoch(e.at).month;
      out[month] = (out[month] ?? 0) + 1;
    }
    return out;
  }
}
