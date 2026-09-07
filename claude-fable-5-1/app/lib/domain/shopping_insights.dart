// Shopping Insights: variety score, top ingredients, seasonal breakdown.
import '../data/models/shopping.dart';

class IngredientCount {
  const IngredientCount(this.ingredientId, this.count);
  final String ingredientId;
  final int count;
}

class MonthBreakdown {
  const MonthBreakdown({required this.monthKey, required this.year, required this.month, required this.adds, required this.uniqueIngredients, required this.top});
  final String monthKey;
  final int year;
  final int month;
  final int adds;
  final int uniqueIngredients;
  final List<IngredientCount> top;
}

class ShoppingInsights {
  const ShoppingInsights({
    required this.totalAdds,
    required this.varietyScore,
    required this.topIngredients,
    required this.months,
    required this.since,
  });

  final int totalAdds;

  /// Unique ingredient count across the whole log.
  final int varietyScore;
  final List<IngredientCount> topIngredients;

  /// Newest month first.
  final List<MonthBreakdown> months;
  final DateTime? since;

  bool get isEmpty => totalAdds == 0;
}

ShoppingInsights computeInsights(Iterable<ShoppingLogEntry> log, {int topN = 10, int topPerMonth = 3}) {
  final counts = <String, int>{};
  final byMonth = <String, List<ShoppingLogEntry>>{};
  DateTime? since;
  var total = 0;
  for (final e in log) {
    total++;
    counts[e.ingredientId] = (counts[e.ingredientId] ?? 0) + 1;
    final key = '${e.addedAt.year}-${e.addedAt.month.toString().padLeft(2, '0')}';
    byMonth.putIfAbsent(key, () => []).add(e);
    if (since == null || e.addedAt.isBefore(since)) since = e.addedAt;
  }
  List<IngredientCount> top(Map<String, int> m, int n) {
    final list = [for (final e in m.entries) IngredientCount(e.key, e.value)]
      ..sort((a, b) {
        final c = b.count.compareTo(a.count);
        return c != 0 ? c : a.ingredientId.compareTo(b.ingredientId);
      });
    return list.take(n).toList();
  }

  final months = <MonthBreakdown>[];
  for (final e in byMonth.entries) {
    final mc = <String, int>{};
    for (final entry in e.value) {
      mc[entry.ingredientId] = (mc[entry.ingredientId] ?? 0) + 1;
    }
    final parts = e.key.split('-');
    months.add(MonthBreakdown(
      monthKey: e.key,
      year: int.parse(parts[0]),
      month: int.parse(parts[1]),
      adds: e.value.length,
      uniqueIngredients: mc.length,
      top: top(mc, topPerMonth),
    ));
  }
  months.sort((a, b) => b.monthKey.compareTo(a.monthKey));
  return ShoppingInsights(
    totalAdds: total,
    varietyScore: counts.length,
    topIngredients: top(counts, topN),
    months: months,
    since: since,
  );
}
