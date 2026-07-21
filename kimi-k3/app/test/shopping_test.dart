import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/engine/shopping.dart';
import 'package:morphcook/core/models/recipe.dart';

Recipe recipeWith(String id, List<Ingredient> ingredients) => Recipe(
      id: id,
      dishId: 'd',
      title: {'en': id},
      dimensions: const {},
      contains: const {},
      attributes: const {},
      timeMinutes: 30,
      caloriesPerServing: 500,
      servings: 2,
      ingredients: ingredients,
      steps: const [],
      macros: const Macros(proteinG: 0, carbsG: 0, fatG: 0),
    );

Ingredient ing(String id, double amount, String unit,
        {String aisle = 'pantry'}) =>
    Ingredient(id: id, name: {'en': id}, amount: amount, unit: unit,
        aisle: aisle);

void main() {
  final agg = ShoppingAggregator();

  group('ShoppingAggregator', () {
    test('identical units sum (garlic 2 + 3 = 5 cloves)', () {
      final items = agg.aggregate([
        recipeWith('a', [ing('garlic', 2, 'cloves', aisle: 'produce')]),
        recipeWith('b', [ing('garlic', 3, 'cloves', aisle: 'produce')]),
      ]);
      expect(items, hasLength(1));
      expect(items.single.amount, 5);
      expect(items.single.unit, 'cloves');
      expect(items.single.sourceRecipeIds, {'a', 'b'});
    });

    test('ml and tbsp merge for compatible volume units', () {
      final items = agg.aggregate([
        recipeWith('a', [ing('milk', 150, 'ml')]),
        recipeWith('b', [ing('milk', 2, 'tbsp')]),
      ]);
      expect(items, hasLength(1));
      // 150ml + 2*15ml = 180 (in whichever display unit survived).
      final ml = items.single.unit == 'ml'
          ? items.single.amount
          : items.single.amount * 15;
      expect(ml, closeTo(180, 0.001));
    });

    test('incompatible units of the same ingredient stay separate', () {
      final items = agg.aggregate([
        recipeWith('a', [ing('flour', 200, 'g')]),
        recipeWith('b', [ing('flour', 1, 'cup')]),
      ]);
      expect(items, hasLength(2));
    });

    test('different ingredients never merge', () {
      final items = agg.aggregate([
        recipeWith('a', [ing('salt', 1, 'tsp'), ing('sugar', 1, 'tsp')]),
      ]);
      expect(items, hasLength(2));
    });

    test('results group by aisle, sorted', () {
      final items = agg.aggregate([
        recipeWith('a', [
          ing('salt', 1, 'tsp', aisle: 'spices'),
          ing('apple', 2, 'pcs', aisle: 'produce'),
          ing('milk', 100, 'ml', aisle: 'dairy'),
        ]),
      ]);
      expect(items.map((i) => i.aisle).toList(),
          ['dairy', 'produce', 'spices']);
    });

    test('kg converts into g lines', () {
      final items = agg.aggregate([
        recipeWith('a', [ing('flour', 1, 'kg')]),
        recipeWith('b', [ing('flour', 250, 'g')]),
      ]);
      expect(items, hasLength(1));
      final grams =
          items.single.unit == 'g' ? items.single.amount : items.single.amount * 1000;
      expect(grams, closeTo(1250, 0.001));
    });
  });

  group('ShoppingInsights', () {
    test('variety score counts unique ingredients', () {
      final insights = ShoppingInsights([
        (ingredientId: 'a', at: 0),
        (ingredientId: 'a', at: 1),
        (ingredientId: 'b', at: 2),
      ]);
      expect(insights.varietyScore, 2);
    });

    test('top ingredients by frequency', () {
      final insights = ShoppingInsights([
        (ingredientId: 'a', at: 0),
        (ingredientId: 'b', at: 1),
        (ingredientId: 'a', at: 2),
        (ingredientId: 'a', at: 3),
        (ingredientId: 'b', at: 4),
      ]);
      final top = insights.topIngredients();
      expect(top.first.key, 'a');
      expect(top.first.value, 3);
      expect(top[1].value, 2);
    });

    test('seasonal breakdown groups by month', () {
      final july = DateTime(2026, 7, 10).millisecondsSinceEpoch;
      final jan = DateTime(2026, 1, 10).millisecondsSinceEpoch;
      final insights = ShoppingInsights([
        (ingredientId: 'a', at: july),
        (ingredientId: 'b', at: july),
        (ingredientId: 'c', at: jan),
      ]);
      final byMonth = insights.byMonth();
      expect(byMonth[7], 2);
      expect(byMonth[1], 1);
    });
  });
}
