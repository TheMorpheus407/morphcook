import 'package:flutter_test/flutter_test.dart' hide Matcher;
import 'package:morphcook/logic/matching.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/recipe.dart';

import 'helpers.dart';

void main() {
  final matcher = Matcher(
    ontology: testOntology(),
    dictionary: testDictionary(),
  );

  test('visible when no filters apply', () {
    final recipe = testRecipe();
    expect(matcher.isVisible(recipe, const Profile()), isTrue);
  });

  test('compound vegan expands and hides dairy', () {
    final recipe = testRecipe(contains: {'dairy'});
    expect(matcher.isVisible(recipe, veganProfile()), isFalse);
    expect(
      matcher.reasons(recipe, veganProfile()),
      contains(HiddenReason.avoidedFlag),
    );
  });

  test('atomic pork flag hides pork recipe', () {
    final recipe = testRecipe(contains: {'pork'});
    final profile = const Profile(avoidFlags: {'pork'});
    expect(matcher.isVisible(recipe, profile), isFalse);
  });

  test('specific ingredient avoidance hides recipe', () {
    final recipe = testRecipe(
      ingredients: const [
        RecipeIngredient(ingredientId: 'apple', qty: 1, unit: 'piece'),
      ],
    );
    final profile = const Profile(avoidIngredients: {'apple'});
    expect(matcher.isVisible(recipe, profile), isFalse);
    expect(
      matcher.reasons(recipe, profile),
      contains(HiddenReason.avoidedIngredient),
    );
  });

  test('parent ingredient avoidance propagates to children', () {
    final recipe = testRecipe(
      ingredients: const [
        RecipeIngredient(ingredientId: 'whole-milk', qty: 100, unit: 'ml'),
      ],
    );
    final profile = const Profile(avoidIngredients: {'dairy'});
    expect(matcher.isVisible(recipe, profile), isFalse);
  });

  test('required attributes must be subset', () {
    final recipe = testRecipe(attributes: {'easy'});
    final profile = const Profile(requiredAttributes: {'halal'});
    expect(matcher.isVisible(recipe, profile), isFalse);
    expect(
      matcher.reasons(recipe, profile),
      contains(HiddenReason.missingAttribute),
    );
  });

  test('time budget is a hard filter', () {
    final recipe = testRecipe(timeMinutes: 50);
    final profile = const Profile(maxTimeMinutes: 30);
    expect(matcher.isVisible(recipe, profile), isFalse);
    expect(
      matcher.reasons(recipe, profile),
      contains(HiddenReason.overTimeBudget),
    );
  });

  test('calorie target is a hard filter within tolerance', () {
    final recipe = testRecipe(calories: 800);
    final profile = const Profile(calorieTarget: 500);
    expect(matcher.isVisible(recipe, profile), isFalse);
    expect(
      matcher.reasons(recipe, profile),
      contains(HiddenReason.outsideCalorieTarget),
    );
    expect(matcher.isVisible(recipe, profile, ignoreCalories: true), isTrue);
    expect(matcher.hiddenOnlyByCalories(recipe, profile), isTrue);
  });

  test('calorie within tolerance stays visible', () {
    final recipe = testRecipe(calories: 600);
    final profile = const Profile(calorieTarget: 500);
    expect(matcher.isVisible(recipe, profile), isTrue);
  });

  test('class and specific avoidance combine', () {
    final recipe = testRecipe(
      contains: {'dairy'},
      ingredients: const [
        RecipeIngredient(ingredientId: 'apple', qty: 1, unit: 'piece'),
      ],
    );
    final profile = const Profile(
      avoidFlags: {'vegan'},
      avoidIngredients: {'apple'},
    );
    final reasons = matcher.reasons(recipe, profile);
    expect(reasons, containsAll([HiddenReason.avoidedFlag, HiddenReason.avoidedIngredient]));
  });
}
