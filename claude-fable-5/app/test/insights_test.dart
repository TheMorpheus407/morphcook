import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/insights.dart';
import 'package:morphcook/models/collections.dart';

ShoppingItem item(String id, DateTime at) => ShoppingItem(
    ingredientId: id, qty: 1, unit: 'piece', aisle: 'produce', addedAt: at);

void main() {
  group('ShoppingInsights', () {
    test('empty history yields zeros', () {
      final insights = ShoppingInsights.compute(const []);
      expect(insights.varietyScore, 0);
      expect(insights.topIngredients, isEmpty);
      expect(insights.seasonalBreakdown, isEmpty);
    });

    test('variety score counts unique ingredients', () {
      final t = DateTime(2026, 3, 1);
      final insights = ShoppingInsights.compute([
        item('garlic', t), item('garlic', t), item('onion', t),
      ]);
      expect(insights.varietyScore, 2);
    });

    test('top ingredients sorted by frequency, capped at topN', () {
      final t = DateTime(2026, 3, 1);
      final history = [
        for (var i = 0; i < 5; i++) item('garlic', t),
        for (var i = 0; i < 3; i++) item('onion', t),
        for (var i = 0; i < 12; i++) item('ingredient-$i', t),
      ];
      final insights = ShoppingInsights.compute(history, topN: 3);
      expect(insights.topIngredients, hasLength(3));
      expect(insights.topIngredients.first.key, 'garlic');
      expect(insights.topIngredients.first.value, 5);
      expect(insights.topIngredients[1].key, 'onion');
    });

    test('seasonal breakdown groups by month in order', () {
      final insights = ShoppingInsights.compute([
        item('a', DateTime(2026, 3, 5)),
        item('b', DateTime(2026, 1, 10)),
        item('c', DateTime(2026, 3, 20)),
        item('d', DateTime(2025, 12, 24)),
      ]);
      expect(insights.seasonalBreakdown.map((e) => e.key).toList(),
          ['2025-12', '2026-01', '2026-03']);
      expect(insights.seasonalBreakdown.last.value, 2);
    });
  });
}
