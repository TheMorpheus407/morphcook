import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/domain/domain.dart';

import 'test_fixtures.dart';

void main() {
  late VariantMatrix matrix;

  setUp(() {
    matrix = VariantMatrix([
      testRecipe(
        id: 'vegan-easy-balanced',
        diet: 'vegan',
        effort: 'easy',
        calorieLevel: 'balanced',
      ),
      testRecipe(
        id: 'vegan-medium-light',
        diet: 'vegan',
        effort: 'medium',
        calorieLevel: 'light',
        calories: 430,
      ),
      testRecipe(
        id: 'classic-hard-hearty',
        diet: 'classic',
        effort: 'hard',
        calorieLevel: 'hearty',
        calories: 760,
        contains: const {'beef'},
      ),
    ]);
  });

  test('orders known dimensions and finds exact combinations', () {
    expect(matrix.dimensions, ['diet', 'effort', 'calorie_level']);
    expect(
      matrix
          .recipeFor(
            VariantSelection(const {
              'diet': 'vegan',
              'effort': 'easy',
              'calorie_level': 'balanced',
            }),
          )
          ?.id,
      'vegan-easy-balanced',
    );
  });

  test('shows impossible options disabled instead of hiding them', () {
    final selection = VariantSelection(const {
      'diet': 'vegan',
      'effort': 'easy',
      'calorie_level': 'balanced',
    });
    final effortState = matrix.stateFor('effort', selection);
    final hard = effortState.options.singleWhere(
      (option) => option.value == 'hard',
    );

    expect(effortState.options.map((option) => option.value), contains('hard'));
    expect(hard.available, isFalse);
    expect(hard.unavailableNote!.resolve('en'), contains('No'));
  });

  test(
    'changing one dimension enables only recipes with other axes intact',
    () {
      final selection = VariantSelection(const {
        'diet': 'vegan',
        'effort': 'easy',
        'calorie_level': 'balanced',
      });
      final effortState = matrix.stateFor('effort', selection);

      expect(
        effortState.options
            .singleWhere((option) => option.value == 'medium')
            .available,
        isFalse,
        reason: 'medium exists, but only with the light calorie axis',
      );
    },
  );

  test('profile defaults always select a real, visible recipe', () {
    final matcher = RecipeMatcher(
      ontology: testOntology,
      ingredients: testIngredients,
    );
    final profile = testProfile(
      avoidFlags: const {'vegan'},
      effort: 'easy',
      tolerance: 200,
    );
    final selection = matrix.defaultsFor(
      profile,
      matcher: matcher,
      now: DateTime(2026, 7, 6, 14),
    );

    expect(selection['diet'], 'vegan');
    expect(matrix.recipeFor(selection), isNotNull);
  });

  test('rejects variants from multiple dishes', () {
    expect(
      () => VariantMatrix([
        testRecipe(dishId: 'one'),
        testRecipe(id: 'two', dishId: 'two'),
      ]),
      throwsArgumentError,
    );
  });
}
