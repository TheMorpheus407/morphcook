import 'aggregator.dart';

/// Shopping Insights analytics (SPEC): variety score, top added ingredients
/// with frequency counts, and a seasonal breakdown grouped by month.
class ShoppingInsights {
  ShoppingInsights({
    required this.varietyScore,
    required this.topIngredients,
    required this.seasonal,
  });

  /// Unique ingredient count ever added to the list.
  final int varietyScore;

  /// Ingredient ids ordered by add-frequency, descending (top first).
  final List<IngredientFrequency> topIngredients;

  /// Adds per calendar month, index 0–11.
  final List<int> seasonal;

  static ShoppingInsights fromAdditions(List<ShoppingAddition> additions) {
    final freq = <String, int>{};
    final months = List<int>.filled(12, 0);
    for (final addition in additions) {
      months[addition.at.month - 1] += 1;
      for (final id in addition.ingredientIds) {
        freq[id] = (freq[id] ?? 0) + 1;
      }
    }
    final top = freq.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return ShoppingInsights(
      varietyScore: freq.length,
      topIngredients: top.map((e) => IngredientFrequency(e.key, e.value)).toList(),
      seasonal: months,
    );
  }
}

/// An ingredient id plus how often it was added to the shopping list.
class IngredientFrequency {
  const IngredientFrequency(this.ingredientId, this.count);

  final String ingredientId;
  final int count;
}
