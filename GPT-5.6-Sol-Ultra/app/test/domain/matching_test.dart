import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/domain/domain.dart';

import 'test_fixtures.dart';

void main() {
  late RecipeMatcher matcher;

  setUp(() {
    matcher = RecipeMatcher(
      ontology: testOntology,
      ingredients: testIngredients,
    );
  });

  test('a recipe satisfying every hard constraint is visible', () {
    final recipe = testRecipe(attributes: const {'halal'});
    final profile = testProfile(requiredAttributes: const {'halal'});

    expect(matcher.isVisible(recipe, profile), isTrue);
    expect(matcher.evaluate(recipe, profile).failures, isEmpty);
  });

  test('compound vegan avoidance expands into concrete contains flags', () {
    final recipe = testRecipe(contains: const {'dairy'});
    final result = matcher.evaluate(
      recipe,
      testProfile(avoidFlags: const {'vegan'}),
    );

    expect(result.isVisible, isFalse);
    expect(result.hasFailure(MatchFailureType.avoidedClass), isTrue);
    expect(result.failures.single.values, contains('dairy'));
  });

  test('contains flags inferred from ingredient metadata are also safe', () {
    final recipe = testRecipe(
      ingredients: const [
        RecipeIngredient(ingredientId: 'parmesan', quantity: 30, unit: 'g'),
      ],
    );

    expect(
      matcher.isVisible(recipe, testProfile(avoidFlags: const {'dairy'})),
      isFalse,
    );
  });

  test('specific avoidance propagates from a parent to all descendants', () {
    final parmesanRecipe = testRecipe(
      ingredients: const [
        RecipeIngredient(ingredientId: 'parmesan', quantity: 30, unit: 'g'),
      ],
    );
    final appleRecipe = testRecipe(
      id: 'apple-toast',
      ingredients: const [
        RecipeIngredient(ingredientId: 'apple', quantity: 1, unit: 'piece'),
      ],
    );
    final profile = testProfile(avoidIngredients: const {'cheese'});

    expect(matcher.isVisible(parmesanRecipe, profile), isFalse);
    expect(matcher.isVisible(appleRecipe, profile), isTrue);
  });

  test('missing positive requirements, time, and calories all hard-filter', () {
    final recipe = testRecipe(minutes: 70, calories: 900);
    final result = matcher.evaluate(
      recipe,
      testProfile(
        requiredAttributes: const {'halal'},
        maxTime: 30,
        calories: 500,
        tolerance: 100,
      ),
    );

    expect(
      result.failures.map((failure) => failure.type),
      containsAll({
        MatchFailureType.missingRequiredAttribute,
        MatchFailureType.overTimeBudget,
        MatchFailureType.outsideCalorieTarget,
      }),
    );
  });

  test('per-dish calorie override relaxes only calories', () {
    final recipe = testRecipe(minutes: 70, calories: 900);
    final profile = testProfile(maxTime: 30, calories: 500, tolerance: 100);

    final result = matcher.evaluate(recipe, profile, ignoreCalorieTarget: true);
    expect(result.hasFailure(MatchFailureType.outsideCalorieTarget), isFalse);
    expect(result.hasFailure(MatchFailureType.overTimeBudget), isTrue);
  });
}
