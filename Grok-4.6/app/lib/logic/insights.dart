import '../models/collections.dart';

class ShoppingInsights {
  final int varietyScore;
  final List<MapEntry<String, int>> topIngredients;
  final List<MapEntry<String, int>> seasonalBreakdown;

  const ShoppingInsights({
    required this.varietyScore,
    required this.topIngredients,
    required this.seasonalBreakdown,
  });

  factory ShoppingInsights.compute(List<ShoppingItem> history, {int topN = 10}) {
    final counts = <String, int>{};
    final byMonth = <String, int>{};
    for (final item in history) {
      counts[item.ingredientId] = (counts[item.ingredientId] ?? 0) + 1;
      final month =
          '${item.addedAt.year}-${item.addedAt.month.toString().padLeft(2, '0')}';
      byMonth[month] = (byMonth[month] ?? 0) + 1;
    }

    final top = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });

    final seasonal = byMonth.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return ShoppingInsights(
      varietyScore: counts.length,
      topIngredients: top.take(topN).toList(),
      seasonalBreakdown: seasonal,
    );
  }
}
