import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/domain/matching.dart';
import 'package:morphcook/domain/profile.dart';

import 'support/fixtures.dart';

void main() {
  late RecipeMatcher matcher;

  setUp(() {
    matcher = RecipeMatcher(
      ontology: testOntology(),
      ingredients: testIngredients(),
    );
  });

  group('visible(recipe, profile)', () {
    test('an empty profile hides nothing', () {
      final ctx = matcher.contextFor(const Profile());
      final recipe = makeRecipe(id: 'r', contains: {'dairy', 'gluten', 'pork'});
      expect(matcher.isVisible(recipe, ctx), isTrue);
    });

    test('a raw avoid-flag intersecting contains hides the recipe', () {
      final ctx = matcher.contextFor(const Profile(avoidFlags: {'dairy'}));
      expect(
        matcher.isVisible(makeRecipe(id: 'a', contains: {'dairy'}), ctx),
        isFalse,
      );
      expect(
        matcher.isVisible(makeRecipe(id: 'b', contains: {'gluten'}), ctx),
        isTrue,
      );
    });

    test('a compound flag expands to every flag it stands for', () {
      final ctx = matcher.contextFor(const Profile(avoidFlags: {'vegan'}));
      expect(
        matcher.isVisible(makeRecipe(id: 'a', contains: {'egg'}), ctx),
        isFalse,
      );
      expect(
        matcher.isVisible(makeRecipe(id: 'b', contains: {'dairy'}), ctx),
        isFalse,
      );
      expect(
        matcher.isVisible(makeRecipe(id: 'c', contains: {'gluten'}), ctx),
        isTrue,
      );
    });

    test('halal expands to pork and alcohol but not to dairy', () {
      final ctx = matcher.contextFor(const Profile(avoidFlags: {'halal'}));
      expect(
        matcher.isVisible(makeRecipe(id: 'a', contains: {'pork'}), ctx),
        isFalse,
      );
      expect(
        matcher.isVisible(makeRecipe(id: 'b', contains: {'alcohol'}), ctx),
        isFalse,
      );
      expect(
        matcher.isVisible(makeRecipe(id: 'c', contains: {'dairy'}), ctx),
        isTrue,
      );
    });

    test('a specific ingredient avoidance hides the recipe', () {
      final ctx = matcher.contextFor(
        const Profile(avoidIngredients: {'apple'}),
      );
      expect(
        matcher.isVisible(makeRecipe(id: 'a', ingredientIds: {'apple'}), ctx),
        isFalse,
      );
      expect(
        matcher.isVisible(makeRecipe(id: 'b', ingredientIds: {'garlic'}), ctx),
        isTrue,
      );
    });

    test('avoiding a parent ingredient propagates to every descendant', () {
      final ctx = matcher.contextFor(
        const Profile(avoidIngredients: {'cheese'}),
      );
      expect(
        matcher.isVisible(
          makeRecipe(id: 'a', ingredientIds: {'parmesan'}),
          ctx,
        ),
        isFalse,
      );
      expect(
        matcher.isVisible(makeRecipe(id: 'b', ingredientIds: {'feta'}), ctx),
        isFalse,
      );
      expect(
        matcher.isVisible(
          makeRecipe(id: 'c', ingredientIds: {'olive-oil'}),
          ctx,
        ),
        isTrue,
      );
    });

    test('avoiding the root propagates through two levels', () {
      final ctx = matcher.contextFor(
        const Profile(avoidIngredients: {'dairy'}),
      );
      expect(
        matcher.isVisible(
          makeRecipe(id: 'a', ingredientIds: {'parmesan'}),
          ctx,
        ),
        isFalse,
      );
    });

    test('required attributes must all be present', () {
      final ctx = matcher.contextFor(
        const Profile(requiredAttributes: {'high-protein', 'one-pot'}),
      );
      expect(
        matcher.isVisible(
          makeRecipe(id: 'a', attributes: {'high-protein', 'one-pot'}),
          ctx,
        ),
        isTrue,
      );
      expect(
        matcher.isVisible(
          makeRecipe(id: 'b', attributes: {'high-protein'}),
          ctx,
        ),
        isFalse,
      );
    });

    test('time over budget hides the recipe, exactly at budget does not', () {
      final ctx = matcher.contextFor(const Profile(maxTimeMinutes: 30));
      expect(
        matcher.isVisible(makeRecipe(id: 'a', timeMinutes: 30), ctx),
        isTrue,
      );
      expect(
        matcher.isVisible(makeRecipe(id: 'b', timeMinutes: 31), ctx),
        isFalse,
      );
    });

    test('calories outside the tolerance band hide the recipe', () {
      final ctx = matcher.contextFor(
        const Profile(calorieTarget: 500, calorieTolerance: 100),
      );
      expect(
        matcher.isVisible(makeRecipe(id: 'a', calories: 600), ctx),
        isTrue,
      );
      expect(
        matcher.isVisible(makeRecipe(id: 'b', calories: 601), ctx),
        isFalse,
      );
      expect(
        matcher.isVisible(makeRecipe(id: 'c', calories: 400), ctx),
        isTrue,
      );
      expect(
        matcher.isVisible(makeRecipe(id: 'd', calories: 399), ctx),
        isFalse,
      );
    });

    test('no calorie target means no calorie filter', () {
      final ctx = matcher.contextFor(const Profile());
      expect(
        matcher.isVisible(makeRecipe(id: 'a', calories: 4000), ctx),
        isTrue,
      );
    });

    test('the per-dish override lifts only the calorie filter', () {
      const profile = Profile(
        calorieTarget: 400,
        calorieTolerance: 50,
        avoidFlags: {'dairy'},
      );
      final overridden = matcher.contextFor(profile, ignoreCalorieTarget: true);
      expect(
        matcher.isVisible(makeRecipe(id: 'a', calories: 900), overridden),
        isTrue,
      );
      expect(
        matcher.isVisible(
          makeRecipe(id: 'b', calories: 400, contains: {'dairy'}),
          overridden,
        ),
        isFalse,
      );
    });
  });

  group('rejection reasons', () {
    test('every failing condition is reported, not just the first', () {
      const profile = Profile(
        avoidFlags: {'dairy'},
        avoidIngredients: {'apple'},
        requiredAttributes: {'one-pot'},
        maxTimeMinutes: 10,
        calorieTarget: 300,
        calorieTolerance: 50,
      );
      final result = matcher.evaluate(
        makeRecipe(
          id: 'r',
          contains: {'dairy'},
          ingredientIds: {'apple'},
          timeMinutes: 90,
          calories: 900,
        ),
        matcher.contextFor(profile),
      );
      expect(result.visible, isFalse);
      expect(
        result.rejections,
        containsAll(<RejectionReason>[
          RejectionReason.containsAvoidedFlag,
          RejectionReason.containsAvoidedIngredient,
          RejectionReason.missingRequiredAttribute,
          RejectionReason.overTimeBudget,
          RejectionReason.outsideCalorieBand,
        ]),
      );
      expect(
        result.details,
        containsAll(<String>['dairy', 'apple', 'one-pot']),
      );
    });

    test('a passing recipe reports no reasons', () {
      final result = matcher.evaluate(
        makeRecipe(id: 'r'),
        matcher.contextFor(const Profile()),
      );
      expect(result.visible, isTrue);
      expect(result.rejections, isEmpty);
    });
  });

  group('filter', () {
    test('keeps order and drops only the clashes', () {
      final ctx = matcher.contextFor(const Profile(avoidFlags: {'gluten'}));
      final recipes = [
        makeRecipe(id: 'a'),
        makeRecipe(id: 'b', contains: {'gluten'}),
        makeRecipe(id: 'c'),
      ];
      expect(
        matcher.filter(recipes, ctx).map((r) => r.id),
        orderedEquals(<String>['a', 'c']),
      );
    });
  });
}
