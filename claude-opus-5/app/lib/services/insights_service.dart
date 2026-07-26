import '../domain/collections.dart';
import '../domain/models.dart';

class IngredientFrequency {
  const IngredientFrequency({
    required this.ingredientId,
    required this.label,
    required this.count,
  });

  final String ingredientId;
  final Localized label;
  final int count;
}

class MonthBucket {
  const MonthBucket({
    required this.year,
    required this.month,
    required this.total,
    required this.uniqueIngredients,
  });

  final int year;
  final int month;
  final int total;
  final int uniqueIngredients;

  String get key => '$year-${month.toString().padLeft(2, '0')}';
}

class ShoppingInsights {
  const ShoppingInsights({
    required this.varietyScore,
    required this.totalAdditions,
    required this.topIngredients,
    required this.byMonth,
    required this.aisleSpread,
    required this.firstAddedAt,
  });

  static const ShoppingInsights empty = ShoppingInsights(
    varietyScore: 0,
    totalAdditions: 0,
    topIngredients: [],
    byMonth: [],
    aisleSpread: {},
    firstAddedAt: null,
  );

  /// Number of distinct ingredients that have passed through the list.
  final int varietyScore;

  final int totalAdditions;
  final List<IngredientFrequency> topIngredients;
  final List<MonthBucket> byMonth;
  final Map<String, int> aisleSpread;
  final DateTime? firstAddedAt;

  bool get isEmpty => totalAdditions == 0;

  /// Repeats per distinct ingredient — 1.0 means everything was bought once.
  double get repeatRate =>
      varietyScore == 0 ? 0 : totalAdditions / varietyScore;
}

/// Descriptive statistics over the shopping history. Deliberately not a grade:
/// a low variety score during a hard month is a reasonable way to eat.
class InsightsService {
  const InsightsService(this.ingredients);

  final IngredientDictionary ingredients;

  ShoppingInsights analyse(List<ShoppingEntry> entries, {int topCount = 8}) {
    if (entries.isEmpty) return ShoppingInsights.empty;

    final counts = <String, int>{};
    final aisles = <String, int>{};
    final months = <String, List<ShoppingEntry>>{};
    DateTime? first;

    for (final e in entries) {
      counts.update(e.ingredientId, (v) => v + 1, ifAbsent: () => 1);
      final aisle = ingredients[e.ingredientId]?.aisle ?? 'other';
      aisles.update(aisle, (v) => v + 1, ifAbsent: () => 1);
      final key =
          '${e.addedAt.year}-${e.addedAt.month.toString().padLeft(2, '0')}';
      (months[key] ??= []).add(e);
      if (first == null || e.addedAt.isBefore(first)) first = e.addedAt;
    }

    final top = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });

    final buckets = months.entries.map((entry) {
      final parts = entry.key.split('-');
      return MonthBucket(
        year: int.parse(parts[0]),
        month: int.parse(parts[1]),
        total: entry.value.length,
        uniqueIngredients: entry.value
            .map((e) => e.ingredientId)
            .toSet()
            .length,
      );
    }).toList()..sort((a, b) => a.key.compareTo(b.key));

    return ShoppingInsights(
      varietyScore: counts.length,
      totalAdditions: entries.length,
      topIngredients: [
        for (final e in top.take(topCount))
          IngredientFrequency(
            ingredientId: e.key,
            label: ingredients[e.key]?.label ?? Localized({'en': e.key}),
            count: e.value,
          ),
      ],
      byMonth: buckets,
      aisleSpread: aisles,
      firstAddedAt: first,
    );
  }
}
