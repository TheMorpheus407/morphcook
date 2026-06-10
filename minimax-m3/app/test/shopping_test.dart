import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/models/i18n_string.dart';
import 'package:morphcook/models/ingredient.dart';
import 'package:morphcook/models/recipe.dart';
import 'package:morphcook/shopping/unit_aggregator.dart';
import 'package:morphcook/shopping/units.dart';

void main() {
  group('Units', () {
    test('same unit aggregates', () {
      expect(Units.canAggregate('g', 'g'), isTrue);
    });

    test('mass family converts', () {
      expect(Units.canAggregate('g', 'kg'), isTrue);
      expect(Units.convert(1000, 'g', 'kg'), equals(1.0));
      expect(Units.convert(1, 'kg', 'g'), equals(1000.0));
    });

    test('volume family converts (ml ↔ tbsp)', () {
      expect(Units.canAggregate('ml', 'tbsp'), isTrue);
      expect(Units.convert(15, 'ml', 'tbsp'), closeTo(1, 0.01));
      expect(Units.convert(2, 'tbsp', 'ml'), closeTo(30, 0.01));
    });

    test('count units only aggregate if identical', () {
      expect(Units.canAggregate('clove', 'clove'), isTrue);
      expect(Units.canAggregate('clove', 'piece'), isFalse);
    });

    test('mass and volume never aggregate', () {
      expect(Units.canAggregate('g', 'ml'), isFalse);
    });

    test('prettify chooses readable unit', () {
      expect(Units.prettify(1500, 'g'), equals((1.5, 'kg')));
      expect(Units.prettify(800, 'g'), equals((800.0, 'g')));
      expect(Units.prettify(1500, 'ml'), equals((1.5, 'l')));
    });
  });

  group('ShoppingAggregator', () {
    final tree = IngredientTree.fromJson({
      'version': 1,
      'tree': [
        {'id': 'garlic', 'label': {'en': 'garlic'}},
        {'id': 'olive-oil', 'label': {'en': 'oil'}},
        {'id': 'flour', 'label': {'en': 'flour'}},
      ],
      'aisle_map': {
        'produce': ['garlic'],
        'pantry': ['olive-oil', 'flour'],
      },
    });

    Recipe r(String id, List<RecipeIngredient> ings) => Recipe(
          id: id,
          dishId: 'd',
          name: const I18nString({'en': 'r'}),
          variantLabel: const I18nString({'en': 'v'}),
          dietLabel: 'omnivore',
          summary: const I18nString({'en': ''}),
          contains: const [],
          attributes: const [],
          techniqueTags: const [],
          timeMinutes: 10,
          activeMinutes: 10,
          effort: 'easy',
          servings: 2,
          caloriesPerServing: 400,
          proteinG: 10,
          carbsG: 10,
          fatG: 10,
          ingredients: ings,
          steps: const [],
        );

    test('cloves of garlic sum across recipes (2 + 3 = 5)', () {
      final agg = ShoppingAggregator(tree);
      final out = agg.aggregate(
        {'r1': 1.0, 'r2': 1.0},
        [
          r('r1', [
            RecipeIngredient(id: 'garlic', qty: 2, unit: 'clove', name: const I18nString({'en': 'garlic'})),
          ]),
          r('r2', [
            RecipeIngredient(id: 'garlic', qty: 3, unit: 'clove', name: const I18nString({'en': 'garlic'})),
          ]),
        ],
      );
      expect(out.length, equals(1));
      expect(out.first.qty, equals(5));
      expect(out.first.unit, equals('clove'));
    });

    test('ml + tbsp aggregates (compatible volume family)', () {
      final agg = ShoppingAggregator(tree);
      final out = agg.aggregate(
        {'r1': 1.0, 'r2': 1.0},
        [
          r('r1', [
            RecipeIngredient(id: 'olive-oil', qty: 30, unit: 'ml', name: const I18nString({'en': 'oil'})),
          ]),
          r('r2', [
            RecipeIngredient(id: 'olive-oil', qty: 2, unit: 'tbsp', name: const I18nString({'en': 'oil'})),
          ]),
        ],
      );
      expect(out.length, equals(1));
      expect(out.first.qty, closeTo(60, 0.5)); // 30 ml + 30 ml = 60 ml
      expect(out.first.unit, equals('ml'));
    });

    test('1500g flour gets prettified to 1.5 kg', () {
      final agg = ShoppingAggregator(tree);
      final out = agg.aggregate(
        {'r1': 1.0, 'r2': 1.0},
        [
          r('r1', [
            RecipeIngredient(id: 'flour', qty: 750, unit: 'g', name: const I18nString({'en': 'flour'})),
          ]),
          r('r2', [
            RecipeIngredient(id: 'flour', qty: 750, unit: 'g', name: const I18nString({'en': 'flour'})),
          ]),
        ],
      );
      expect(out.length, equals(1));
      expect(out.first.qty, equals(1.5));
      expect(out.first.unit, equals('kg'));
    });

    test('servings multiplier scales quantities', () {
      final agg = ShoppingAggregator(tree);
      final out = agg.aggregate(
        {'r1': 2.0},
        [
          r('r1', [
            RecipeIngredient(id: 'garlic', qty: 2, unit: 'clove', name: const I18nString({'en': 'garlic'})),
          ]),
        ],
      );
      expect(out.first.qty, equals(4));
    });
  });
}
