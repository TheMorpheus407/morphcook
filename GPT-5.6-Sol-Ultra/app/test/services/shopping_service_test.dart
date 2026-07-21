import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/domain/models.dart';
import 'package:morphcook/services/shopping_service.dart';

void main() {
  const service = ShoppingListService();

  test('normalizes and aggregates clove aliases', () {
    final result = service.aggregate(const <ShoppingIngredientInput>[
      ShoppingIngredientInput(
        ingredientId: 'garlic',
        name: 'Garlic',
        quantity: 2,
        unit: 'cloves',
        aisle: 'produce',
        recipeId: 'a',
      ),
      ShoppingIngredientInput(
        ingredientId: ' GARLIC ',
        name: 'Garlic',
        quantity: 3,
        unit: 'Zehen',
        aisle: 'produce',
        recipeId: 'b',
      ),
    ]);

    expect(result, hasLength(1));
    expect(result.single.quantity, 5);
    expect(result.single.unit, 'clove');
    expect(result.single.sourceRecipeIds, <String>{'a', 'b'});
  });

  test('maps recipes using dictionary aisle and conversion metadata', () {
    final dictionary = IngredientDictionary(<IngredientNode>[
      IngredientNode(
        id: 'olive-oil',
        name: LocalizedText(const <String, String>{
          'en': 'Olive oil',
          'de': 'Olivenöl',
        }),
        aisle: 'pantry',
        volumeConvertible: true,
      ),
    ]);
    final result = service.aggregateRecipes(
      <Recipe>[_recipe('a', 1, 'tbsp'), _recipe('b', 15, 'ml')],
      ingredientDictionary: dictionary,
      languageCode: 'de',
      servingsByRecipeId: const <String, double>{'a': 4},
    );

    expect(result, hasLength(1));
    expect(result.single.name, 'Olivenöl');
    expect(result.single.aisle, 'pantry');
    expect(result.single.unit, 'tbsp');
    expect(result.single.quantity, 3);
    expect(result.single.sourceRecipeIds, <String>{'a', 'b'});
  });

  test('converts ml, tbsp, tsp and l only when explicitly compatible', () {
    final compatible = service.aggregate(const <ShoppingIngredientInput>[
      ShoppingIngredientInput(
        ingredientId: 'olive-oil',
        name: 'Olive oil',
        quantity: 30,
        unit: 'ml',
        aisle: 'pantry',
        volumeConvertible: true,
      ),
      ShoppingIngredientInput(
        ingredientId: 'olive-oil',
        name: 'Olive oil',
        quantity: 1,
        unit: 'tbsp',
        aisle: 'pantry',
        volumeConvertible: true,
      ),
      ShoppingIngredientInput(
        ingredientId: 'olive-oil',
        name: 'Olive oil',
        quantity: 1,
        unit: 'tsp',
        aisle: 'pantry',
        volumeConvertible: true,
      ),
      ShoppingIngredientInput(
        ingredientId: 'olive-oil',
        name: 'Olive oil',
        quantity: .001,
        unit: 'l',
        aisle: 'pantry',
        volumeConvertible: true,
      ),
    ]);
    expect(compatible, hasLength(1));
    expect(compatible.single.unit, 'ml');
    expect(compatible.single.quantity, 51);

    final unsafe = service.aggregate(const <ShoppingIngredientInput>[
      ShoppingIngredientInput(
        ingredientId: 'flour',
        name: 'Flour',
        quantity: 30,
        unit: 'ml',
        aisle: 'pantry',
      ),
      ShoppingIngredientInput(
        ingredientId: 'flour',
        name: 'Flour',
        quantity: 1,
        unit: 'tbsp',
        aisle: 'pantry',
      ),
    ]);
    expect(unsafe, hasLength(2));
  });

  test('never converts clove to volume or merges different ingredients', () {
    final result = service.aggregate(const <ShoppingIngredientInput>[
      ShoppingIngredientInput(
        ingredientId: 'garlic',
        name: 'Garlic',
        quantity: 2,
        unit: 'clove',
        aisle: 'produce',
        volumeConvertible: true,
      ),
      ShoppingIngredientInput(
        ingredientId: 'garlic',
        name: 'Garlic',
        quantity: 5,
        unit: 'ml',
        aisle: 'produce',
        volumeConvertible: true,
      ),
      ShoppingIngredientInput(
        ingredientId: 'ginger',
        name: 'Ginger',
        quantity: 5,
        unit: 'ml',
        aisle: 'produce',
        volumeConvertible: true,
      ),
    ]);
    expect(result, hasLength(3));
  });

  test('deduplication preserves sources, counts and checked state', () {
    final date = DateTime.utc(2026, 1, 2);
    final result = service.deduplicate(<ShoppingEntry>[
      ShoppingEntry(
        id: 'older',
        ingredientId: 'garlic',
        name: 'Garlic',
        quantity: 2,
        unit: 'cloves',
        aisle: 'produce',
        isChecked: true,
        sourceRecipeIds: const <String>{'a'},
        additionCount: 2,
        addedAt: date,
      ),
      ShoppingEntry(
        id: 'newer',
        ingredientId: 'garlic',
        name: 'Garlic',
        quantity: 3,
        unit: 'clove',
        aisle: 'produce',
        isChecked: true,
        sourceRecipeIds: const <String>{'b'},
        additionCount: 3,
        addedAt: date.add(const Duration(days: 1)),
      ),
    ]);

    expect(result, hasLength(1));
    expect(result.single.id, 'newer');
    expect(result.single.quantity, 5);
    expect(result.single.sourceRecipeIds, <String>{'a', 'b'});
    expect(result.single.additionCount, 5);
    expect(result.single.isChecked, isTrue);
    expect(result.single.addedAt, date);
  });

  test('groups by calm grocery aisle order and alphabetizes entries', () {
    ShoppingEntry entry(String id, String aisle, String name) => ShoppingEntry(
      id: id,
      ingredientId: id,
      name: name,
      quantity: 1,
      unit: 'piece',
      aisle: aisle,
    );

    final grouped = service.groupByAisle(<ShoppingEntry>[
      entry('salt', 'spices', 'Salt'),
      entry('apple', 'produce', 'Apple'),
      entry('banana', 'produce', 'Banana'),
      entry('special', 'world foods', 'Special'),
    ]);

    expect(grouped.keys, <String>['produce', 'spices', 'world foods']);
    expect(grouped['produce']!.map((item) => item.name), <String>[
      'Apple',
      'Banana',
    ]);
  });

  test('computes variety, frequency and seasonal month insights', () {
    final insights = service.insights(<ShoppingEntry>[
      ShoppingEntry(
        id: 'a',
        ingredientId: 'apple',
        name: 'Apple',
        quantity: 1,
        unit: 'piece',
        aisle: 'produce',
        additionCount: 4,
        addedAt: DateTime.utc(2026, 1, 1),
      ),
      ShoppingEntry(
        id: 'b',
        ingredientId: 'bread',
        name: 'Bread',
        quantity: 1,
        unit: 'loaf',
        aisle: 'bakery',
        additionCount: 2,
        addedAt: DateTime.utc(2026, 2, 1),
      ),
    ]);

    expect(insights.varietyScore, 2);
    expect(insights.topIngredients, <String, int>{'Apple': 4, 'Bread': 2});
    expect(insights.seasonalByMonth, <int, int>{1: 4, 2: 2});
  });
}

Recipe _recipe(String id, double quantity, String unit) => Recipe(
  id: id,
  dishId: 'dish-$id',
  name: LocalizedText(<String, String>{'en': id}),
  description: LocalizedText(const <String, String>{'en': ''}),
  timeMinutes: 10,
  caloriesPerServing: 100,
  servings: 2,
  nutrition: const Nutrition(
    calories: 100,
    proteinGrams: 1,
    carbohydrateGrams: 1,
    fatGrams: 1,
  ),
  ingredients: <RecipeIngredient>[
    RecipeIngredient(ingredientId: 'olive-oil', quantity: quantity, unit: unit),
  ],
  partitionId: 'core',
);
