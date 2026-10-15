import '../models/localized_text.dart';
import '../models/recipe.dart';
import '../models/shopping_item.dart';

enum UnitFamily {
  volume,
  weight,
  count,
}

class ShoppingAggregator {
  const ShoppingAggregator._();

  static const Map<String, double> _volumeToMl = {
    'ml': 1.0,
    'tsp': 5.0,
    'tl': 5.0,
    'tbsp': 15.0,
    'el': 15.0,
    'cup': 240.0,
    'l': 1000.0,
  };

  static const Map<String, double> _weightToGrams = {
    'g': 1.0,
    'kg': 1000.0,
  };

  static UnitFamily familyOf(String unit) {
    final u = unit.trim().toLowerCase();
    if (_volumeToMl.containsKey(u)) return UnitFamily.volume;
    if (_weightToGrams.containsKey(u)) return UnitFamily.weight;
    return UnitFamily.count;
  }

  /// Checks whether two units can be combined via direct equality or
  /// volume/weight conversion (`ml ↔ tbsp ↔ tsp`, `g ↔ kg`).
  static bool areUnitsCompatible(String unitA, String unitB) {
    final a = unitA.trim().toLowerCase();
    final b = unitB.trim().toLowerCase();
    if (a == b) return true;
    final famA = familyOf(a);
    final famB = familyOf(b);
    if (famA == UnitFamily.count || famB == UnitFamily.count) {
      return a == b;
    }
    return famA == famB;
  }

  /// Combines (amountA, unitA) + (amountB, unitB) into a normalized (amount, unit).
  /// Examples:
  /// - 2 cloves + 3 cloves = 5 cloves
  /// - 30 ml + 1 tbsp = 3 tbsp (or 45 ml if target is ml)
  /// - 15 ml + 2 tbsp = 3 tbsp (45 ml)
  /// - 600 g + 0.5 kg = 1100 g
  static ({double amount, String unit}) combineAmounts(
    double amountA,
    String unitA,
    double amountB,
    String unitB,
  ) {
    final uA = unitA.trim().toLowerCase();
    final uB = unitB.trim().toLowerCase();

    if (uA == uB) {
      return (amount: amountA + amountB, unit: unitA);
    }

    final famA = familyOf(uA);
    final famB = familyOf(uB);

    if (famA == UnitFamily.volume && famB == UnitFamily.volume) {
      final totalMl =
          amountA * (_volumeToMl[uA] ?? 1.0) + amountB * (_volumeToMl[uB] ?? 1.0);
      // If either was tbsp and totalMl is cleanly divisible by 15 (and < 120ml), keep tbsp
      if ((uA == 'tbsp' || uB == 'tbsp') &&
          totalMl <= 120 &&
          (totalMl % 15).abs() < 0.01) {
        return (amount: totalMl / 15.0, unit: 'tbsp');
      }
      if ((uA == 'tsp' || uB == 'tsp') &&
          totalMl < 30 &&
          (totalMl % 5).abs() < 0.01) {
        return (amount: totalMl / 5.0, unit: 'tsp');
      }
      return (amount: totalMl, unit: 'ml');
    }

    if (famA == UnitFamily.weight && famB == UnitFamily.weight) {
      final totalGrams = amountA * (_weightToGrams[uA] ?? 1.0) +
          amountB * (_weightToGrams[uB] ?? 1.0);
      return (amount: totalGrams, unit: 'g');
    }

    // Fallback if incompatible count units
    return (amount: amountA + amountB, unit: unitA);
  }

  /// Converts a volume or weight quantity into a target unit (`ml ↔ tbsp`, `g ↔ kg`).
  static double? convertUnit(double amount, String fromUnit, String toUnit) {
    final from = fromUnit.trim().toLowerCase();
    final to = toUnit.trim().toLowerCase();
    if (from == to) return amount;
    if (_volumeToMl.containsKey(from) && _volumeToMl.containsKey(to)) {
      final ml = amount * _volumeToMl[from]!;
      return ml / _volumeToMl[to]!;
    }
    if (_weightToGrams.containsKey(from) && _weightToGrams.containsKey(to)) {
      final g = amount * _weightToGrams[from]!;
      return g / _weightToGrams[to]!;
    }
    return null;
  }

  /// Merges incoming recipe ingredients into an existing list of [ShoppingItem]s,
  /// deduplicating by ingredient ID + compatible unit family.
  static List<ShoppingItem> mergeIngredients({
    required List<ShoppingItem> existing,
    required List<RecipeIngredient> incoming,
    String? sourceRecipeId,
    double scaleFactor = 1.0,
  }) {
    final result = List<ShoppingItem>.from(existing);

    for (final ing in incoming) {
      final scaledAmount = ing.amount * scaleFactor;
      final matchIdx = result.indexWhere(
        (item) =>
            item.ingredientId == ing.id &&
            areUnitsCompatible(item.unit, ing.unit),
      );

      if (matchIdx >= 0) {
        final current = result[matchIdx];
        final combined = combineAmounts(
          current.amount,
          current.unit,
          scaledAmount,
          ing.unit,
        );
        final updatedSources = <String>{
          ...current.sourceRecipeIds,
          ?sourceRecipeId,
        }.toList();
        result[matchIdx] = current.copyWith(
          amount: combined.amount,
          unit: combined.unit,
          checked: false,
          sourceRecipeIds: updatedSources,
        );
      } else {
        result.add(
          ShoppingItem(
            id: '${ing.id}_${ing.unit}_${result.length}',
            ingredientId: ing.id,
            name: ing.name,
            amount: scaledAmount,
            unit: ing.unit,
            aisle: ing.aisle,
            checked: false,
            sourceRecipeIds:
                sourceRecipeId != null ? [sourceRecipeId] : const [],
          ),
        );
      }
    }

    return result;
  }

  /// Aggregates ingredients across multiple recipes into a deduplicated list
  /// sorted by aisle.
  static List<ShoppingItem> aggregateRecipes(
    List<Recipe> recipes, {
    Map<String, double>? scaleByRecipeId,
  }) {
    var list = <ShoppingItem>[];
    for (final recipe in recipes) {
      final scale = scaleByRecipeId?[recipe.id] ?? 1.0;
      list = mergeIngredients(
        existing: list,
        incoming: recipe.ingredients,
        sourceRecipeId: recipe.id,
        scaleFactor: scale,
      );
    }
    return list;
  }

  /// Groups shopping items by supermarket aisle in a canonical order.
  static Map<String, List<ShoppingItem>> groupByAisle(List<ShoppingItem> items) {
    const aisleOrder = [
      'produce',
      'bakery',
      'dairy',
      'meat_seafood',
      'pantry',
      'spices',
    ];
    final grouped = <String, List<ShoppingItem>>{};
    for (final aisle in aisleOrder) {
      final matching = items.where((i) => i.aisle == aisle).toList();
      if (matching.isNotEmpty) {
        grouped[aisle] = matching;
      }
    }
    for (final item in items) {
      if (!aisleOrder.contains(item.aisle)) {
        grouped.putIfAbsent(item.aisle, () => []).add(item);
      }
    }
    return grouped;
  }

  static String aisleLabel(String aisle, String lang) {
    if (lang == 'de') {
      switch (aisle) {
        case 'produce':
          return 'Obst, Gemüse & Kräuter';
        case 'bakery':
          return 'Backwaren';
        case 'dairy':
          return 'Milchprodukte & Eier';
        case 'meat_seafood':
          return 'Fleisch & Meeresfrüchte';
        case 'pantry':
          return 'Vorrat & Konserven';
        case 'spices':
          return 'Gewürze & Öle';
        default:
          return aisle;
      }
    }
    switch (aisle) {
      case 'produce':
        return 'Produce & Fresh Herbs';
      case 'bakery':
        return 'Bakery';
      case 'dairy':
        return 'Dairy & Eggs';
      case 'meat_seafood':
        return 'Meat & Seafood';
      case 'pantry':
        return 'Pantry & Dry Goods';
      case 'spices':
        return 'Spices & Oils';
      default:
        return aisle;
    }
  }

  /// Computes Shopping Insights analytics (Variety Score, Top Added Ingredients,
  /// and Seasonal Breakdown grouped by month).
  static ShoppingInsightsData computeInsights(
    List<ShoppingLogEntry> logs,
    List<ShoppingItem> currentItems,
  ) {
    // Combine historical logs with current items if logs are empty
    final effectiveLogs = <ShoppingLogEntry>[
      ...logs,
      if (logs.isEmpty)
        for (final item in currentItems)
          ShoppingLogEntry(
            ingredientId: item.ingredientId,
            name: item.name,
            addedAt: DateTime.now(),
            aisle: item.aisle,
          ),
    ];

    final countByIngredient = <String, int>{};
    final nameByIngredient = <String, LocalizedText>{};
    final aisleByIngredient = <String, String>{};
    final logsByMonth = <int, List<ShoppingLogEntry>>{};

    for (final entry in effectiveLogs) {
      countByIngredient[entry.ingredientId] =
          (countByIngredient[entry.ingredientId] ?? 0) + 1;
      nameByIngredient[entry.ingredientId] = entry.name;
      aisleByIngredient[entry.ingredientId] = entry.aisle;
      logsByMonth.putIfAbsent(entry.addedAt.month, () => []).add(entry);
    }

    final topIngredients = countByIngredient.entries
        .map(
          (e) => TopIngredientStat(
            ingredientId: e.key,
            name: nameByIngredient[e.key] ?? LocalizedText({'en': e.key}),
            count: e.value,
            aisle: aisleByIngredient[e.key] ?? 'pantry',
          ),
        )
        .toList()
      ..sort((a, b) {
        final cmp = b.count.compareTo(a.count);
        if (cmp != 0) return cmp;
        return a.ingredientId.compareTo(b.ingredientId);
      });

    final seasonalBreakdown = <SeasonalMonthStat>[];
    for (int month = 1; month <= 12; month++) {
      final monthLogs = logsByMonth[month] ?? const [];
      if (monthLogs.isEmpty) continue;
      final monthCounts = <String, int>{};
      for (final l in monthLogs) {
        monthCounts[l.ingredientId] = (monthCounts[l.ingredientId] ?? 0) + 1;
      }
      final monthTop = monthCounts.entries
          .map(
            (e) => TopIngredientStat(
              ingredientId: e.key,
              name: nameByIngredient[e.key] ?? LocalizedText({'en': e.key}),
              count: e.value,
              aisle: aisleByIngredient[e.key] ?? 'pantry',
            ),
          )
          .toList()
        ..sort((a, b) => b.count.compareTo(a.count));

      seasonalBreakdown.add(
        SeasonalMonthStat(
          month: month,
          totalAdditions: monthLogs.length,
          uniqueIngredients: monthCounts.length,
          topIngredients: monthTop.take(5).toList(),
        ),
      );
    }

    return ShoppingInsightsData(
      varietyScore: countByIngredient.length,
      totalAdditions: effectiveLogs.length,
      topAddedIngredients: topIngredients,
      seasonalBreakdown: seasonalBreakdown,
    );
  }
}
