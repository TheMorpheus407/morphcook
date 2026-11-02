import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/src/domain/shopping_aggregation.dart';
import 'package:morphcook/src/domain/unit_conversion.dart';
import 'package:morphcook/src/models/ingredient.dart';
import 'package:morphcook/src/models/recipe.dart';

import 'support/fixtures.dart';

Recipe recipeWith(
  String id,
  List<({String id, double quantity, String unit})> ingredients,
) {
  return Recipe(
    id: id,
    dishId: 'dish',
    title: en(id),
    heroText: en('hero'),
    capCaption: en('caption'),
    stripeColor: '#C4694D',
    ingredients: <RecipeIngredient>[
      for (final ingredient in ingredients)
        RecipeIngredient(
          ingredientId: ingredient.id,
          name: en(ingredient.id),
          quantity: ingredient.quantity,
          unit: ingredient.unit,
        ),
    ],
    steps: const <RecipeStep>[],
    contains: const <String>{},
    attributes: const <String, List<String>>{},
    diet: 'classic',
    timeMinutes: 20,
    calories: 500,
    macros: const Nutrition(calories: 500, protein: 20, carbs: 50, fat: 15),
    servings: 2,
    tags: en('tag'),
    mealSlots: const <String>['dinner'],
    partitionId: 'core',
  );
}

void main() {
  group('unit conversion', () {
    test('millilitres convert to tablespoons', () {
      expect(Units.convert(15, 'ml', 'tbsp'), closeTo(1, 0.001));
      expect(Units.convert(30, 'ml', 'tbsp'), closeTo(2, 0.001));
    });

    test('tablespoons convert to millilitres', () {
      expect(Units.convert(2, 'tbsp', 'ml'), closeTo(30, 0.001));
    });

    test('grams convert to kilograms', () {
      expect(Units.convert(1500, 'g', 'kg'), closeTo(1.5, 0.001));
    });

    test('ounces convert to grams', () {
      expect(Units.convert(1, 'oz', 'g'), closeTo(28.35, 0.01));
    });

    test('incompatible systems do not convert', () {
      expect(Units.convert(100, 'g', 'ml'), isNull);
      expect(Units.convert(2, 'clove', 'tbsp'), isNull);
    });

    test('an ingredient pinned to a system refuses the other one', () {
      expect(
        Units.convert(
          100,
          'ml',
          'tbsp',
          ingredientSystem: 'mass',
        ),
        isNull,
      );
    });

    test('the same unit converts to itself', () {
      expect(Units.convert(42, 'g', 'g'), 42);
    });

    test('large volumes read better in litres', () {
      expect(Units.preferredUnit('ml', 1500), 'l');
      expect(Units.preferredUnit('ml', 200), 'ml');
      expect(Units.preferredUnit('g', 1500), 'kg');
    });
  });

  group('aggregation', () {
    late IngredientTree ingredients;

    setUp(() {
      ingredients = buildIngredients();
    });

    test('the same ingredient in the same unit is added up', () {
      final items = ShoppingAggregator.aggregate(
        recipes: <Recipe>[
          recipeWith('a', <({String id, double quantity, String unit})>[
            (id: 'produce.garlic', quantity: 2, unit: 'clove'),
          ]),
          recipeWith('b', <({String id, double quantity, String unit})>[
            (id: 'produce.garlic', quantity: 3, unit: 'clove'),
          ]),
        ],
        ingredients: ingredients,
        lang: 'en',
      );

      expect(items.length, 1);
      expect(items.first.quantity, 5);
      expect(items.first.unit, 'clove');
      expect(items.first.recipeIds, containsAll(<String>['a', 'b']));
    });

    test('compatible units are folded together', () {
      final items = ShoppingAggregator.aggregate(
        recipes: <Recipe>[
          recipeWith('a', <({String id, double quantity, String unit})>[
            (id: 'pantry.oil', quantity: 30, unit: 'ml'),
          ]),
          recipeWith('b', <({String id, double quantity, String unit})>[
            (id: 'pantry.oil', quantity: 1, unit: 'tbsp'),
          ]),
        ],
        ingredients: ingredients,
        lang: 'en',
      );

      expect(items.length, 1);
      expect(items.first.quantity, closeTo(45, 0.001));
    });

    test('incompatible units stay on separate lines', () {
      final items = ShoppingAggregator.aggregate(
        recipes: <Recipe>[
          recipeWith('a', <({String id, double quantity, String unit})>[
            (id: 'pantry.flour', quantity: 100, unit: 'g'),
          ]),
          recipeWith('b', <({String id, double quantity, String unit})>[
            (id: 'pantry.flour', quantity: 1, unit: 'cup'),
          ]),
        ],
        ingredients: ingredients,
        lang: 'en',
      );

      expect(items.length, 2);
    });

    test('items are grouped by aisle, produce first', () {
      final items = ShoppingAggregator.aggregate(
        recipes: <Recipe>[
          recipeWith('a', <({String id, double quantity, String unit})>[
            (id: 'pantry.flour', quantity: 100, unit: 'g'),
            (id: 'produce.garlic', quantity: 2, unit: 'clove'),
          ]),
        ],
        ingredients: ingredients,
        lang: 'en',
      );

      expect(items.first.aisle, 'produce');
      expect(items.last.aisle, 'pantry');
    });

    test('checked ingredients are flagged', () {
      final items = ShoppingAggregator.aggregate(
        recipes: <Recipe>[
          recipeWith('a', <({String id, double quantity, String unit})>[
            (id: 'produce.garlic', quantity: 2, unit: 'clove'),
          ]),
        ],
        ingredients: ingredients,
        lang: 'en',
        checkedIngredientIds: <String>{'produce.garlic'},
      );

      expect(items.first.checked, isTrue);
    });

    test('an empty recipe list produces an empty list', () {
      final items = ShoppingAggregator.aggregate(
        recipes: const <Recipe>[],
        ingredients: ingredients,
        lang: 'en',
      );

      expect(items, isEmpty);
    });
  });

  group('formatting', () {
    test('whole numbers drop the decimal', () {
      expect(Units.format(5, 'clove'), '5 clove');
    });

    test('fractions keep two decimals', () {
      expect(Units.format(1.5, 'tbsp'), '1.5 tbsp');
    });
  });
}
