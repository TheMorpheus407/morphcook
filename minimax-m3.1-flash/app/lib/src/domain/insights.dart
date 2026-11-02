import '../models/history.dart';
import '../models/recipe.dart';

/// How often an ingredient shows up across the user's cooking.
class IngredientFrequency {
  const IngredientFrequency({
    required this.ingredientId,
    required this.name,
    required this.count,
  });

  final String ingredientId;
  final String name;
  final int count;
}

/// The analytics behind the Shopping Insights dashboard.
class ShoppingInsights {
  const ShoppingInsights({
    required this.varietyScore,
    required this.topIngredients,
    required this.monthlyBreakdown,
    required this.totalRecipes,
    required this.totalIngredientUses,
  });

  const ShoppingInsights.empty()
      : varietyScore = 0,
        topIngredients = const <IngredientFrequency>[],
        monthlyBreakdown = const <int, int>{},
        totalRecipes = 0,
        totalIngredientUses = 0;

  /// How many distinct ingredients the user reaches for.
  final int varietyScore;

  /// The most-used ingredients, with their frequency.
  final List<IngredientFrequency> topIngredients;

  /// How many cooks happened in each month (1–12).
  final Map<int, int> monthlyBreakdown;

  final int totalRecipes;
  final int totalIngredientUses;

  /// The busiest month, if any.
  int? get peakMonth {
    if (monthlyBreakdown.isEmpty) return null;
    var peak = 1;
    var value = -1;
    monthlyBreakdown.forEach((month, count) {
      if (count > value) {
        value = count;
        peak = month;
      }
    });
    return peak;
  }

  /// The count for a given month.
  int countForMonth(int month) => monthlyBreakdown[month] ?? 0;

  /// Computes the insights for a set of recipes and a cooking history.
  static ShoppingInsights analyze({
    required List<Recipe> recipes,
    required List<CookingEntry> history,
    required Map<String, String> ingredientNames,
    String lang = 'en',
  }) {
    final counts = <String, int>{};
    var totalUses = 0;

    for (final recipe in recipes) {
      for (final ingredient in recipe.ingredients) {
        counts.update(
          ingredient.ingredientId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
        totalUses++;
      }
    }

    final top = counts.entries.map((entry) {
      final name = ingredientNames[entry.key] ?? entry.key;
      return IngredientFrequency(
        ingredientId: entry.key,
        name: name,
        count: entry.value,
      );
    }).toList()
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        if (byCount != 0) return byCount;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    final monthly = <int, int>{};
    for (final entry in history) {
      final month = entry.cookedAt.month;
      monthly.update(month, (value) => value + 1, ifAbsent: () => 1);
    }

    return ShoppingInsights(
      varietyScore: counts.length,
      topIngredients: top,
      monthlyBreakdown: monthly,
      totalRecipes: recipes.length,
      totalIngredientUses: totalUses,
    );
  }
}
