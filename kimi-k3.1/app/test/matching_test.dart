import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/services/matching.dart';

import 'test_helpers.dart';

void main() {
  group('RecipeMatcher', () {
    test('expands compound avoid flags', () {
      final matcher = testMatcher();
      final recipe = testRecipe(contains: {'dairy'});
      expect(matcher.visible(recipe, testProfile()), isTrue);
      expect(
        matcher.visible(recipe, testProfile(avoidFlags: {'vegan'})),
        isFalse,
      );
      expect(
        matcher.match(recipe, testProfile(avoidFlags: {'vegan'})).reasons,
        contains(MatchReason.avoidedFlag),
      );
    });

    test('specific avoidance propagates from parent to descendants only', () {
      final matcher = testMatcher();
      final parmesan = testRecipe(ingredientIds: {'parmesan'});
      expect(
        matcher.visible(parmesan, testProfile(avoidIngredients: {'dairy'})),
        isFalse,
      );
      expect(
        matcher.visible(parmesan, testProfile(avoidIngredients: {'cheese'})),
        isFalse,
      );
      expect(
        matcher.visible(parmesan, testProfile(avoidIngredients: {'garlic'})),
        isTrue,
      );
      expect(
        matcher.visible(
          testRecipe(ingredientIds: {'dairy'}),
          testProfile(avoidIngredients: {'parmesan'}),
        ),
        isTrue,
      );
    });

    test('class and specific avoidance combine', () {
      final recipe = testRecipe(
        contains: {'gluten'},
        ingredientIds: {'cilantro'},
      );
      final matcher = testMatcher();
      expect(
        matcher.visible(recipe, testProfile(avoidFlags: {'gluten-free'})),
        isFalse,
      );
      expect(
        matcher.visible(recipe, testProfile(avoidIngredients: {'cilantro'})),
        isFalse,
      );
    });

    test('required attributes, time and calorie are hard filters', () {
      final matcher = testMatcher();
      final recipe = testRecipe(time: 60, calories: 850);
      final profile = testProfile(
        requiredAttributes: {'halal'},
        maxTime: 45,
        tolerance: 100,
      );
      final result = matcher.match(recipe, profile);
      expect(result.reasons, {
        MatchReason.requiredAttribute,
        MatchReason.tooMuchTime,
        MatchReason.outsideCalories,
      });
      expect(matcher.visible(recipe, profile, ignoreCalories: true), isFalse);
      final withAttributes = testRecipe(
        attributes: {'easy', 'halal'},
        time: 60,
        calories: 850,
      );
      expect(
        matcher.visible(withAttributes, profile, ignoreCalories: true),
        isFalse,
      );
      expect(
        matcher.visible(testRecipe(attributes: {'easy', 'halal'}), profile),
        isTrue,
      );
    });

    test(
      'calorie tolerance is inclusive and override only relaxes calories',
      () {
        final matcher = testMatcher();
        expect(
          matcher.visible(testRecipe(calories: 700), testProfile()),
          isTrue,
        );
        expect(
          matcher.visible(testRecipe(calories: 701), testProfile()),
          isFalse,
        );
        expect(
          matcher.visible(
            testRecipe(calories: 701, time: 50),
            testProfile(),
            ignoreCalories: true,
          ),
          isFalse,
        );
      },
    );
  });

  group('ranking', () {
    final mondayMorning = DateTime(2026, 4, 13, 7);
    final mondayEvening = DateTime(2026, 4, 13, 18);

    test('morning breakfast receives exactly 200 bonus', () {
      final matcher = testMatcher();
      final breakfast = testRecipe(attributes: {'easy', 'breakfast'});
      final plain = testRecipe(id: 'r2');
      expect(
        matcher.score(breakfast, testProfile(), now: mondayMorning) -
            matcher.score(plain, testProfile(), now: mondayMorning),
        200,
      );
    });

    test('dinner and weekend medium bonuses are applied after base score', () {
      final matcher = testMatcher();
      final recipe = testRecipe(
        attributes: {'medium', 'dinner'},
        dimensions: {
          'diet': 'classic',
          'effort': 'medium',
          'calorie': 'regular',
        },
      );
      final plain = testRecipe(id: 'r2');
      expect(
        matcher.score(recipe, testProfile(), now: mondayEvening) -
            matcher.score(plain, testProfile(), now: mondayEvening),
        90 - 10000,
      );
      expect(
        matcher.score(recipe, testProfile(), now: DateTime(2026, 4, 18, 12)) -
            matcher.score(plain, testProfile(), now: DateTime(2026, 4, 18, 12)),
        90 - 10000,
      );
    });

    test('only recipes cooked 30 or more days ago get staleness boost', () {
      final matcher = testMatcher();
      final recipe = testRecipe();
      final profile = testProfile();
      final base = matcher.score(recipe, profile, now: mondayMorning);
      expect(matcher.score(recipe, profile, now: mondayMorning), base);
      expect(
        matcher.score(
          recipe,
          profile,
          now: mondayMorning,
          lastCooked: mondayMorning.subtract(const Duration(days: 29)),
        ),
        base,
      );
      expect(
        matcher.score(
          recipe,
          profile,
          now: mondayMorning,
          lastCooked: mondayMorning.subtract(const Duration(days: 30)),
        ),
        base + 50,
      );
    });
  });

  test('best variant applies filters then preferences', () {
    final matcher = testMatcher();
    final easy = testRecipe(id: 'easy');
    final medium = testRecipe(
      id: 'medium',
      attributes: {'medium'},
      dimensions: {'diet': 'classic', 'effort': 'medium', 'calorie': 'regular'},
    );
    final best = matcher.bestVariant(
      testDish(['medium', 'easy']),
      {'easy': easy, 'medium': medium},
      testProfile(),
      now: mondayMorningForTest,
    );
    expect(best?.id, 'easy');
  });

  test(
    'variant options retain exact other dimensions and explain unreachable combos',
    () {
      final resolver = VariantResolver(testMatcher());
      final current = testRecipe(id: 'classic');
      final veganEasy = testRecipe(
        id: 'vegan-easy',
        dimensions: {'diet': 'vegan', 'effort': 'easy', 'calorie': 'regular'},
      );
      final veganMediumLight = testRecipe(
        id: 'vegan-medium-light',
        attributes: {'medium'},
        dimensions: {'diet': 'vegan', 'effort': 'medium', 'calorie': 'light'},
      );
      final options = resolver.options(
        axis: 'diet',
        current: current,
        variants: [current, veganEasy, veganMediumLight],
        profile: testProfile(),
        values: ['classic', 'vegan', 'keto'],
      );
      expect(options[1].enabled, isTrue);
      expect(options[1].recipe?.id, 'vegan-easy');
      expect(options[2].enabled, isFalse);
      expect(
        options[2].unavailableReason,
        VariantUnavailableReason.noCombination,
      );
      final effort = resolver.options(
        axis: 'effort',
        current: veganEasy,
        variants: [current, veganEasy, veganMediumLight],
        profile: testProfile(),
        values: ['easy', 'medium'],
      );
      expect(
        effort[1].unavailableReason,
        VariantUnavailableReason.noCombination,
      );
    },
  );
}

final mondayMorningForTest = DateTime(2026, 4, 13, 7);
