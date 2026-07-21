import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/services/shopping_aggregator.dart';

import 'support/recipe_factory.dart';

void main() {
  test('deduplicates exact ingredient units', () {
    final first = testRecipe(
      id: 'one',
      ingredients: [testIngredient(id: 'garlic', quantity: 2, unit: 'clove')],
    );
    final second = testRecipe(
      id: 'two',
      ingredients: [testIngredient(id: 'garlic', quantity: 3, unit: 'clove')],
    );
    final result = ShoppingAggregator.addRecipes([], [first, second]);
    expect(result, hasLength(1));
    expect(result.single.quantity, 5);
    expect(result.single.frequency, 2);
  });

  test('converts tablespoons and millilitres for compatible ingredients', () {
    final first = testRecipe(
      id: 'one',
      ingredients: [
        testIngredient(
          id: 'tahini',
          quantity: 30,
          unit: 'ml',
          volumeConvertible: true,
        ),
      ],
    );
    final second = testRecipe(
      id: 'two',
      ingredients: [
        testIngredient(
          id: 'tahini',
          quantity: 2,
          unit: 'tbsp',
          volumeConvertible: true,
        ),
      ],
    );
    final result = ShoppingAggregator.addRecipes([], [first, second]);
    expect(result.single.unit, 'ml');
    expect(result.single.quantity, 60);
  });

  test('normalizes kilograms and scales recipe servings', () {
    final recipe = testRecipe(
      id: 'one',
      ingredients: [testIngredient(id: 'potato', quantity: 1, unit: 'kg')],
    );
    final result = ShoppingAggregator.addRecipes(
      [],
      [recipe],
      servings: {'one': 4},
    );
    expect(result.single.unit, 'g');
    expect(result.single.quantity, 2000);
  });

  test('keeps incompatible units separate', () {
    final first = testRecipe(
      id: 'one',
      ingredients: [testIngredient(id: 'lemon', quantity: 1, unit: 'piece')],
    );
    final second = testRecipe(
      id: 'two',
      ingredients: [testIngredient(id: 'lemon', quantity: 20, unit: 'ml')],
    );
    expect(ShoppingAggregator.addRecipes([], [first, second]), hasLength(2));
  });
}
