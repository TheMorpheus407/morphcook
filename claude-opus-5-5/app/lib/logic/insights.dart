import 'calendar.dart';

/// One ingredient added to the shopping list at a point in time.
class ShoppingLogEntry {
  const ShoppingLogEntry(this.ingredientId, this.at);

  factory ShoppingLogEntry.fromJson(Map<String, dynamic> j) =>
      ShoppingLogEntry(j['id'] as String, DateTime.parse(j['at'] as String));

  final String ingredientId;
  final DateTime at;

  Map<String, dynamic> toJson() => {'id': ingredientId, 'at': at.toIso8601String()};
}

class IngredientCount {
  const IngredientCount(this.ingredientId, this.count);
  final String ingredientId;
  final int count;
}

class MonthBreakdown {
  const MonthBreakdown({required this.month, required this.total, required this.unique, required this.top});

  /// `YYYY-MM`
  final String month;
  final int total;
  final int unique;
  final List<IngredientCount> top;
}

class ShoppingInsights {
  const ShoppingInsights({
    required this.varietyScore,
    required this.totalAdded,
    required this.top,
    required this.months,
  });

  /// Unique ingredient count across the whole log.
  final int varietyScore;
  final int totalAdded;
  final List<IngredientCount> top;

  /// Newest month first.
  final List<MonthBreakdown> months;

  bool get isEmpty => totalAdded == 0;
}

/// Pantry basics would drown every chart, so they are not counted.
const insightIgnored = {'salt', 'black-pepper', 'water'};

ShoppingInsights computeInsights(Iterable<ShoppingLogEntry> log, {int topN = 8}) {
  final entries = log.where((e) => !insightIgnored.contains(e.ingredientId)).toList();
  List<IngredientCount> countTop(Iterable<ShoppingLogEntry> es, int n) {
    final counts = <String, int>{};
    for (final e in es) {
      counts[e.ingredientId] = (counts[e.ingredientId] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.compareTo(b.key));
    return [for (final e in sorted.take(n)) IngredientCount(e.key, e.value)];
  }

  final byMonth = <String, List<ShoppingLogEntry>>{};
  for (final e in entries) {
    byMonth.putIfAbsent(monthKey(e.at), () => []).add(e);
  }
  final months = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));
  return ShoppingInsights(
    varietyScore: entries.map((e) => e.ingredientId).toSet().length,
    totalAdded: entries.length,
    top: countTop(entries, topN),
    months: [
      for (final m in months)
        MonthBreakdown(
          month: m,
          total: byMonth[m]!.length,
          unique: byMonth[m]!.map((e) => e.ingredientId).toSet().length,
          top: countTop(byMonth[m]!, 3),
        ),
    ],
  );
}
