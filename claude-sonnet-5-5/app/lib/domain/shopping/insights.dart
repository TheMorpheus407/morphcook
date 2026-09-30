/// One ingredient landing on the shopping list.
class ShoppingEvent {
  const ShoppingEvent({required this.ingredientId, required this.at, this.recipeId});

  final String ingredientId;
  final DateTime at;
  final String? recipeId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'ingredient_id': ingredientId,
    'at': at.toUtc().toIso8601String(),
    if (recipeId != null) 'recipe_id': recipeId,
  };

  factory ShoppingEvent.fromJson(Map<String, dynamic> json) => ShoppingEvent(
    ingredientId: json['ingredient_id'] as String,
    at: DateTime.parse(json['at'] as String).toLocal(),
    recipeId: json['recipe_id'] as String?,
  );
}

class IngredientCount {
  const IngredientCount(this.ingredientId, this.count);
  final String ingredientId;
  final int count;
}

/// Shopping activity of one calendar month across all years (seasonality).
class MonthBreakdown {
  const MonthBreakdown({required this.month, required this.count, required this.top});

  /// 1 = January … 12 = December.
  final int month;
  final int count;
  final List<IngredientCount> top;
}

class ShoppingInsights {
  const ShoppingInsights({
    required this.varietyScore,
    required this.totalAdds,
    required this.topIngredients,
    required this.months,
  });

  /// Number of unique ingredients ever added.
  final int varietyScore;
  final int totalAdds;
  final List<IngredientCount> topIngredients;

  /// Always twelve entries, January to December.
  final List<MonthBreakdown> months;

  bool get isEmpty => totalAdds == 0;

  /// Words for the score: `starting`, `growing`, `varied` or `adventurous`.
  String get level {
    if (varietyScore < 10) return 'starting';
    if (varietyScore < 25) return 'growing';
    if (varietyScore < 50) return 'varied';
    return 'adventurous';
  }

  int get busiestMonthCount => months.fold<int>(0, (m, e) => e.count > m ? e.count : m);
}

/// Computes the Shopping Insights dashboard from the event log.
class InsightsCalculator {
  const InsightsCalculator._();

  static ShoppingInsights compute(Iterable<ShoppingEvent> events, {int topN = 10, int topPerMonth = 3}) {
    final overall = <String, int>{};
    final perMonth = <int, Map<String, int>>{for (var m = 1; m <= 12; m++) m: <String, int>{}};
    var total = 0;
    for (final event in events) {
      total++;
      overall[event.ingredientId] = (overall[event.ingredientId] ?? 0) + 1;
      final bucket = perMonth[event.at.month]!;
      bucket[event.ingredientId] = (bucket[event.ingredientId] ?? 0) + 1;
    }

    List<IngredientCount> top(Map<String, int> counts, int n) {
      final list = [for (final e in counts.entries) IngredientCount(e.key, e.value)];
      list.sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        return byCount != 0 ? byCount : a.ingredientId.compareTo(b.ingredientId);
      });
      return list.take(n).toList();
    }

    return ShoppingInsights(
      varietyScore: overall.length,
      totalAdds: total,
      topIngredients: top(overall, topN),
      months: [
        for (var m = 1; m <= 12; m++)
          MonthBreakdown(
            month: m,
            count: perMonth[m]!.values.fold<int>(0, (a, b) => a + b),
            top: top(perMonth[m]!, topPerMonth),
          ),
      ],
    );
  }
}
