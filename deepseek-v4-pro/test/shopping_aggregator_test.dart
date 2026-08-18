import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/shopping_aggregator.dart';
import 'package:morphcook/logic/units.dart';
import 'package:morphcook/models/ingredient.dart';
import 'package:morphcook/models/recipe.dart';
import 'package:morphcook/models/shopping.dart';

IngredientTree tree() => IngredientTree.fromJson(const {
      'tree': [
        {
          'id': 'produce',
          'name': {'en': 'Produce'},
          'children': [
            {
              'id': 'produce.garlic',
              'name': {'en': 'garlic'},
              'aisle': 'produce',
              'unit': {'kind': 'count', 'default': 'clove'},
            },
            {
              'id': 'produce.onion',
              'name': {'en': 'onion'},
              'aisle': 'produce',
              'unit': {'kind': 'count', 'default': 'piece'},
            },
          ],
        },
        {
          'id': 'oils',
          'name': {'en': 'Oils'},
          'children': [
            {
              'id': 'oils.olive-oil',
              'name': {'en': 'olive oil'},
              'aisle': 'pantry',
              'unit': {'kind': 'volume', 'default': 'ml'},
            },
          ],
        },
        {
          'id': 'baking',
          'name': {'en': 'Baking'},
          'children': [
            {
              'id': 'baking.flour',
              'name': {'en': 'flour'},
              'aisle': 'baking',
              'unit': {'kind': 'mass', 'default': 'g'},
            },
          ],
        },
      ]
    });

void main() {
  group('Units', () {
    test('volume conversions', () {
      expect(Units.toCanonical(2, 'tbsp'), (value: 30.0, unit: 'ml'));
      expect(Units.toCanonical(1, 'cup'), (value: 240.0, unit: 'ml'));
      expect(Units.toCanonical(3, 'tsp'), (value: 15.0, unit: 'ml'));
      expect(Units.toCanonical(1, 'l'), (value: 1000.0, unit: 'ml'));
      expect(Units.toCanonical(30, 'ml'), (value: 30.0, unit: 'ml'));
    });

    test('mass conversions', () {
      expect(Units.toCanonical(2, 'kg'), (value: 2000.0, unit: 'g'));
      expect(Units.toCanonical(500, 'g'), (value: 500.0, unit: 'g'));
    });

    test('count units are identity', () {
      expect(Units.toCanonical(2, 'clove'), (value: 2.0, unit: 'clove'));
    });

    test('kind lookup', () {
      expect(Units.kindOf('ml'), 'volume');
      expect(Units.kindOf('g'), 'mass');
      expect(Units.kindOf('clove'), 'count');
    });

    test('display formatting', () {
      expect(Units.format(60, 'ml'), '4 tbsp');
      expect(Units.format(30, 'ml'), '2 tbsp');
      expect(Units.format(250, 'ml'), '250 ml');
      expect(Units.format(1500, 'g'), '1.5 kg');
      expect(Units.format(1000, 'ml'), '1 l');
      expect(Units.format(5, 'clove'), '5 clove');
      expect(Units.format(5, 'ml'), '1 tsp');
      expect(Units.format(240, 'ml'), '16 tbsp');
      expect(Units.format(2000, 'ml'), '2 l');
    });
  });

  group('ShoppingAggregator', () {
    test('garlic 2 cloves + garlic 3 cloves = 5 cloves', () {
      final entries = [
        ShoppingEntry(
          ingredientId: 'produce.garlic',
          amount: 2,
          unit: 'clove',
          addedAt: DateTime(2026, 1, 1),
        ),
        ShoppingEntry(
          ingredientId: 'produce.garlic',
          amount: 3,
          unit: 'clove',
          addedAt: DateTime(2026, 1, 1),
        ),
      ];
      final lines = ShoppingAggregator.aggregate(entries, tree());
      expect(lines, hasLength(1));
      expect(lines.first.amount, 5);
      expect(lines.first.unit, 'clove');
      expect(lines.first.display, '5 clove');
    });

    test('ml ↔ tbsp conversion: 30 ml + 2 tbsp = 60 ml', () {
      final entries = [
        ShoppingEntry(
          ingredientId: 'oils.olive-oil',
          amount: 30,
          unit: 'ml',
          addedAt: DateTime(2026, 1, 1),
        ),
        ShoppingEntry(
          ingredientId: 'oils.olive-oil',
          amount: 2,
          unit: 'tbsp',
          addedAt: DateTime(2026, 1, 1),
        ),
      ];
      final lines = ShoppingAggregator.aggregate(entries, tree());
      expect(lines, hasLength(1));
      expect(lines.first.amount, 60);
      expect(lines.first.unit, 'ml');
      expect(lines.first.display, '4 tbsp');
    });

    test('g ↔ kg conversion', () {
      final entries = [
        ShoppingEntry(
          ingredientId: 'baking.flour',
          amount: 500,
          unit: 'g',
          addedAt: DateTime(2026, 1, 1),
        ),
        ShoppingEntry(
          ingredientId: 'baking.flour',
          amount: 1,
          unit: 'kg',
          addedAt: DateTime(2026, 1, 1),
        ),
      ];
      final lines = ShoppingAggregator.aggregate(entries, tree());
      expect(lines, hasLength(1));
      expect(lines.first.amount, 1500);
      expect(lines.first.display, '1.5 kg');
    });

    test('different ingredients stay separate', () {
      final entries = [
        ShoppingEntry(
          ingredientId: 'produce.garlic',
          amount: 2,
          unit: 'clove',
          addedAt: DateTime(2026, 1, 1),
        ),
        ShoppingEntry(
          ingredientId: 'produce.onion',
          amount: 1,
          unit: 'piece',
          addedAt: DateTime(2026, 1, 1),
        ),
      ];
      final lines = ShoppingAggregator.aggregate(entries, tree());
      expect(lines, hasLength(2));
    });

    test('checked entries are excluded', () {
      final entries = [
        ShoppingEntry(
          ingredientId: 'produce.garlic',
          amount: 2,
          unit: 'clove',
          checked: true,
          addedAt: DateTime(2026, 1, 1),
        ),
        ShoppingEntry(
          ingredientId: 'produce.onion',
          amount: 1,
          unit: 'piece',
          addedAt: DateTime(2026, 1, 1),
        ),
      ];
      final lines = ShoppingAggregator.aggregate(entries, tree());
      expect(lines, hasLength(1));
      expect(lines.first.ingredientId, 'produce.onion');
    });

    test('grouped by aisle in stable order', () {
      final entries = [
        ShoppingEntry(
          ingredientId: 'baking.flour',
          amount: 500,
          unit: 'g',
          addedAt: DateTime(2026, 1, 1),
        ),
        ShoppingEntry(
          ingredientId: 'produce.onion',
          amount: 1,
          unit: 'piece',
          addedAt: DateTime(2026, 1, 1),
        ),
        ShoppingEntry(
          ingredientId: 'oils.olive-oil',
          amount: 30,
          unit: 'ml',
          addedAt: DateTime(2026, 1, 1),
        ),
      ];
      final lines = ShoppingAggregator.aggregate(entries, tree());
      final grouped = ShoppingAggregator.groupByAisle(lines);
      expect(grouped.keys.toList(), ['produce', 'pantry', 'baking']);
    });

    test('unknown ingredient lands in other aisle', () {
      final entries = [
        ShoppingEntry(
          ingredientId: 'mystery.thing',
          amount: 1,
          unit: 'piece',
          addedAt: DateTime(2026, 1, 1),
        ),
      ];
      final lines = ShoppingAggregator.aggregate(entries, tree());
      expect(lines.first.aisle, 'other');
    });

    test('entriesFromRecipe scales servings', () {
      final recipe = Recipe(
        id: 'r',
        dishId: 'd',
        name: {'en': 'r'},
        blurb: const {},
        contains: const {},
        ingredientIds: const ['produce.garlic'],
        attributes: const {},
        effort: 'easy',
        timeMinutes: 10,
        timeBucket: 'le15',
        caloriesPerServing: 100,
        calorieBucket: 'le400',
        servings: 2,
        cuisine: 'test',
        mealTypes: const {'dinner'},
        technique: const {},
        tags: const {},
        stripeColors: const [],
        caption: const {},
        ingredients: [
          RecipeIngredient(id: 'produce.garlic', amount: 2, unit: 'clove'),
        ],
        steps: const [],
        nutrition: const Nutrition(),
      );
      final entries =
          ShoppingAggregator.entriesFromRecipe(recipe, scale: 2.0);
      expect(entries.single.amount, 4);
    });
  });
}
