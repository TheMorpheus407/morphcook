import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/src/domain/matching.dart';
import 'package:morphcook/src/models/ingredient.dart';
import 'package:morphcook/src/models/ontology.dart';
import 'package:morphcook/src/models/recipe.dart';

import 'support/fixtures.dart';

void main() {
  late Ontology ontology;
  late IngredientTree ingredients;
  late RecipeMatcher matcher;

  setUp(() {
    ontology = buildOntology();
    ingredients = buildIngredients();
    matcher = RecipeMatcher(ontology: ontology, ingredients: ingredients);
  });

  group('flag matching', () {
    test('a recipe with no conflicting flags is visible', () {
      final recipe = buildRecipe(contains: <String>{'gluten'});
      expect(matcher.isVisible(recipe, buildProfile()), isTrue);
    });

    test('a contains-flag the user avoids hides the recipe', () {
      final recipe = buildRecipe(contains: <String>{'pork'});
      final profile = buildProfile(avoidFlags: <String>{'pork'});

      final result = matcher.evaluate(recipe, profile);

      expect(result.visible, isFalse);
      expect(result.primaryReason, VisibilityReason.containsFlag);
      expect(result.conflictingFlags, contains('pork'));
    });

    test('a compound avoid-flag expands to its primitives', () {
      final recipe = buildRecipe(contains: <String>{'dairy'});
      final profile = buildProfile(avoidFlags: <String>{'vegan'});

      expect(matcher.isVisible(recipe, profile), isFalse);
    });

    test('expansion reaches nested flags', () {
      expect(
        matcher.expandedAvoidFlags(<String>{'vegan'}),
        containsAll(<String>['pork', 'dairy', 'egg', 'honey']),
      );
    });

    test('an unknown avoid-flag is treated as a primitive', () {
      expect(
        matcher.expandedAvoidFlags(<String>{'mystery'}),
        contains('mystery'),
      );
    });

    test('a self-referential flag expands without looping forever', () {
      // `gluten` expands into the primitive `gluten`, and `dairy` expands
      // into itself plus `dairy-lactose`. The taxonomy is allowed to look
      // like this; the expansion must still terminate.
      expect(
        matcher.expandedAvoidFlags(<String>{'gluten'}),
        contains('gluten'),
      );
      expect(
        matcher.expandedAvoidFlags(<String>{'dairy'}),
        containsAll(<String>['dairy', 'dairy-lactose']),
      );
    });

    test('a class-level toggle hides the recipes it stands for', () {
      final recipe = buildRecipe(contains: <String>{'gluten'});
      final profile = buildProfile(avoidFlags: <String>{'gluten'});

      expect(matcher.isVisible(recipe, profile), isFalse);
    });

    test('halal only excludes pork, alcohol and non-halal gelatin', () {
      final withChicken = buildRecipe(contains: <String>{'poultry'});
      final profile = buildProfile(avoidFlags: <String>{'halal'});

      expect(matcher.isVisible(withChicken, profile), isTrue);
    });
  });

  group('ingredient matching', () {
    test('avoiding a specific ingredient hides the recipe', () {
      final recipe = buildRecipe(ingredientIds: <String>['produce.garlic']);
      final profile = buildProfile(
        avoidIngredients: <String>{'produce.garlic'},
      );

      final result = matcher.evaluate(recipe, profile);

      expect(result.visible, isFalse);
      expect(result.primaryReason, VisibilityReason.ingredient);
    });

    test('avoiding a parent excludes every descendant', () {
      final recipe = buildRecipe(ingredientIds: <String>['dairy.milk.whole']);
      final profile = buildProfile(avoidIngredients: <String>{'dairy'});

      expect(matcher.isVisible(recipe, profile), isFalse);
    });

    test('avoiding a leaf does not exclude its siblings', () {
      final recipe = buildRecipe(
        ingredientIds: <String>['produce.herbs.cilantro'],
      );
      final profile = buildProfile(
        avoidIngredients: <String>{'produce.garlic'},
      );

      expect(matcher.isVisible(recipe, profile), isTrue);
    });

    test('avoiding a leaf excludes its own children', () {
      final recipe = buildRecipe(
        ingredientIds: <String>['produce.herbs.cilantro'],
      );
      final profile = buildProfile(
        avoidIngredients: <String>{'produce.herbs'},
      );

      expect(matcher.isVisible(recipe, profile), isFalse);
    });
  });

  group('required attributes', () {
    test('a recipe without the required attribute is hidden', () {
      final recipe = buildRecipe(certifications: <String>{'vegan'});
      final profile = buildProfile(requiredAttributes: <String>{'halal'});

      final result = matcher.evaluate(recipe, profile);

      expect(result.visible, isFalse);
      expect(result.primaryReason, VisibilityReason.missingAttribute);
      expect(result.missingAttributes, contains('halal'));
    });

    test('a recipe carrying the required attribute is visible', () {
      final recipe = buildRecipe(certifications: <String>{'halal'});
      final profile = buildProfile(requiredAttributes: <String>{'halal'});

      expect(matcher.isVisible(recipe, profile), isTrue);
    });
  });

  group('time and calories', () {
    test('a recipe longer than the budget is hidden', () {
      final recipe = buildRecipe(timeMinutes: 90);
      final profile = buildProfile(maxTimeMinutes: 45);

      final result = matcher.evaluate(recipe, profile);

      expect(result.visible, isFalse);
      expect(result.primaryReason, VisibilityReason.tooSlow);
    });

    test('a recipe inside the time budget is visible', () {
      final recipe = buildRecipe(timeMinutes: 45);
      final profile = buildProfile(maxTimeMinutes: 45);

      expect(matcher.isVisible(recipe, profile), isTrue);
    });

    test('a recipe outside the calorie tolerance is hidden', () {
      final recipe = buildRecipe(calories: 900);
      final profile = buildProfile(calorieTarget: 500, calorieTolerance: 50);

      final result = matcher.evaluate(recipe, profile);

      expect(result.visible, isFalse);
      expect(result.primaryReason, VisibilityReason.calorieTarget);
    });

    test('the calorie tolerance is symmetric', () {
      final below = buildRecipe(calories: 450);
      final above = buildRecipe(calories: 550);
      final profile = buildProfile(calorieTarget: 500, calorieTolerance: 50);

      expect(matcher.isVisible(below, profile), isTrue);
      expect(matcher.isVisible(above, profile), isTrue);
    });
  });

  group('the calorie override', () {
    test('relaxes only the calorie filter', () {
      final recipe = buildRecipe(calories: 900, contains: <String>{'pork'});
      final profile = buildProfile(
        avoidFlags: <String>{'pork'},
        calorieTarget: 500,
        calorieTolerance: 50,
      );

      expect(
        matcher.isVisibleWithCalorieOverride(
          recipe,
          profile,
          allowOutsideCalorieTarget: true,
        ),
        isFalse,
      );
    });

    test('lets a recipe that is only outside the target through', () {
      final recipe = buildRecipe(calories: 900);
      final profile = buildProfile(calorieTarget: 500, calorieTolerance: 50);

      expect(
        matcher.isVisibleWithCalorieOverride(
          recipe,
          profile,
          allowOutsideCalorieTarget: true,
        ),
        isTrue,
      );
    });
  });

  group('variant selection', () {
    test('prefers the variant matching the preferred effort', () {
      final easy = buildRecipe(id: 'easy', effort: 'easy');
      final hard = buildRecipe(id: 'hard', effort: 'hard');
      final profile = buildProfile(preferredEffort: 'easy');

      final best = matcher.bestVariant(<Recipe>[hard, easy], profile);

      expect(best?.id, 'easy');
    });

    test('prefers a variant carrying the required attributes', () {
      final plain = buildRecipe(id: 'plain');
      final halal = buildRecipe(id: 'halal', certifications: <String>{'halal'});
      final profile = buildProfile(requiredAttributes: <String>{'halal'});

      final best = matcher.bestVariant(<Recipe>[plain, halal], profile);

      expect(best?.id, 'halal');
    });

    test('falls back to the closest calorie count', () {
      final far = buildRecipe(id: 'far', calories: 400);
      final near = buildRecipe(id: 'near', calories: 590);
      final profile = buildProfile(calorieTarget: 600, calorieTolerance: 200);

      final best = matcher.bestVariant(<Recipe>[far, near], profile);

      expect(best?.id, 'near');
    });

    test('returns null when nothing passes', () {
      final recipe = buildRecipe(contains: <String>{'pork'});
      final profile = buildProfile(avoidFlags: <String>{'pork'});

      expect(matcher.bestVariant(<Recipe>[recipe], profile), isNull);
    });
  });

  group('filtering', () {
    test('keeps only the visible recipes', () {
      final visible = buildRecipe(id: 'visible');
      final hidden = buildRecipe(id: 'hidden', contains: <String>{'pork'});
      final profile = buildProfile(avoidFlags: <String>{'pork'});

      final result = matcher.filter(<Recipe>[visible, hidden], profile);

      expect(result.map((recipe) => recipe.id), <String>['visible']);
    });
  });
}
