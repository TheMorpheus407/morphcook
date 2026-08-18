import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/insights.dart';
import 'package:morphcook/models/collections.dart';

void main() {
  test('variety and top counts', () {
    final history = [
      ShoppingItem(ingredientId: 'garlic', qty: 1, unit: 'clove', aisle: 'produce', addedAt: DateTime(2026, 3, 1)),
      ShoppingItem(ingredientId: 'garlic', qty: 2, unit: 'clove', aisle: 'produce', addedAt: DateTime(2026, 3, 8)),
      ShoppingItem(ingredientId: 'apple', qty: 1, unit: 'piece', aisle: 'produce', addedAt: DateTime(2026, 4, 2)),
    ];
    final insights = ShoppingInsights.compute(history);
    expect(insights.varietyScore, 2);
    expect(insights.topIngredients.first.key, 'garlic');
    expect(insights.topIngredients.first.value, 2);
    expect(insights.seasonalBreakdown.map((e) => e.key), ['2026-03', '2026-04']);
  });
}
