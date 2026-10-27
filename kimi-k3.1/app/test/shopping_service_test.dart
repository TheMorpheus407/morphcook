import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/models/user_data.dart';
import 'package:morphcook/services/shopping_service.dart';

import 'test_helpers.dart';

void main() {
  const service = ShoppingService();

  test('aggregates identical count units without converting cloves', () {
    final groups = service.aggregate([
      testRecipe(id: 'one', ingredients: [ingredient('garlic', 2, 'clove')]),
      testRecipe(id: 'two', ingredients: [ingredient('garlic', 3, 'clove')]),
    ]);
    expect(groups, hasLength(1));
    expect(groups.single.amount, 5);
    expect(groups.single.unit, 'clove');
    expect(groups.single.recipeIds, {'one', 'two'});
  });

  test('converts compatible ml and tablespoon volumes', () {
    final groups = service.aggregate([
      testRecipe(
        id: 'one',
        ingredients: [ingredient('milk', 200, 'ml', aisle: 'dairy')],
      ),
      testRecipe(
        id: 'two',
        ingredients: [ingredient('milk', 2, 'tbsp', aisle: 'dairy')],
      ),
    ]);
    expect(groups.single.amount, 230);
    expect(groups.single.unit, 'ml');
  });

  test('converts mass and scales by servings', () {
    final groups = service.aggregate(
      [
        testRecipe(
          id: 'one',
          servings: 2,
          ingredients: [ingredient('flour', 500, 'g')],
        ),
      ],
      servings: {'one': 4},
    );
    expect(groups.single.amount, 1);
    expect(groups.single.unit, 'kg');
  });

  test('keeps incompatible count units and notes separate', () {
    final groups = service.aggregate([
      testRecipe(
        id: 'one',
        ingredients: [
          ingredient('garlic', 2, 'clove'),
          ingredient('garlic', 1, 'piece'),
          ingredient('salt', null, 'to-taste'),
        ],
      ),
    ]);
    expect(groups, hasLength(3));
    expect(
      groups.map((group) => group.unit),
      containsAll(['clove', 'piece', 'to-taste']),
    );
  });

  test('insights count unique variety, frequencies and calendar months', () {
    final events = [
      ShoppingEvent(
        id: '1',
        ingredientId: 'garlic',
        recipeId: 'a',
        addedAt: DateTime.utc(2026, 1, 2),
        amount: 2,
        unit: 'clove',
      ),
      ShoppingEvent(
        id: '2',
        ingredientId: 'garlic',
        recipeId: 'b',
        addedAt: DateTime.utc(2026, 1, 8),
        amount: 3,
        unit: 'clove',
      ),
      ShoppingEvent(
        id: '3',
        ingredientId: 'basil',
        recipeId: 'b',
        addedAt: DateTime.utc(2026, 2, 8),
        amount: 1,
        unit: 'bunch',
      ),
    ];
    final insights = service.insights(events);
    expect(insights.varietyScore, 2);
    expect(insights.topIngredients.first.ingredientId, 'garlic');
    expect(insights.topIngredients.first.count, 2);
    expect(insights.months, hasLength(2));
    expect(insights.months[0].month, 2);
    expect(insights.months[1].additions, 2);
    expect(insights.months[1].uniqueIngredients, 1);
  });
}
