import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/shopping.dart';
import 'package:morphcook/logic/units.dart';
import 'package:morphcook/models/recipe.dart';

import 'helpers.dart';

void main() {
  test('same unit garlic cloves add', () {
    final a = testRecipe(
      id: 'a',
      ingredients: const [
        RecipeIngredient(ingredientId: 'garlic', qty: 2, unit: 'clove'),
      ],
    );
    final b = testRecipe(
      id: 'b',
      ingredients: const [
        RecipeIngredient(ingredientId: 'garlic', qty: 3, unit: 'clove'),
      ],
    );
    final items = aggregate([(a, 1), (b, 1)], testDictionary());
    expect(items, hasLength(1));
    expect(items.single.quantity.amount, 5);
    expect(items.single.quantity.unit, 'clove');
  });

  test('ml and tbsp merge through volume', () {
    final a = testRecipe(
      id: 'a',
      ingredients: const [
        RecipeIngredient(ingredientId: 'whole-milk', qty: 30, unit: 'ml'),
      ],
    );
    final b = testRecipe(
      id: 'b',
      ingredients: const [
        RecipeIngredient(ingredientId: 'whole-milk', qty: 1, unit: 'tbsp'),
      ],
    );
    final items = aggregate([(a, 1), (b, 1)], testDictionary());
    expect(items, hasLength(1));
    expect(items.single.quantity.def.family, UnitFamily.volume);
    expect(items.single.quantity.amount * items.single.quantity.def.toBase, 45);
  });

  test('incompatible units stay separate', () {
    final a = testRecipe(
      ingredients: const [
        RecipeIngredient(ingredientId: 'garlic', qty: 200, unit: 'g'),
        RecipeIngredient(ingredientId: 'garlic', qty: 1, unit: 'piece'),
      ],
    );
    final items = aggregate([(a, 1)], testDictionary());
    expect(items, hasLength(2));
  });

  test('group by aisle', () {
    final a = testRecipe(
      ingredients: const [
        RecipeIngredient(ingredientId: 'garlic', qty: 1, unit: 'clove'),
        RecipeIngredient(ingredientId: 'whole-milk', qty: 100, unit: 'ml'),
      ],
    );
    final grouped = groupByAisle(aggregate([(a, 1)], testDictionary()));
    expect(grouped.keys, containsAll(['produce', 'dairy']));
  });
}
