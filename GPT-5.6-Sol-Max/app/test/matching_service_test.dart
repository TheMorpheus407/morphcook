import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/services/matching_service.dart';

import 'support/recipe_factory.dart';

void main() {
  group('RecipeMatcher.visible', () {
    const base = UserProfile(
      maxTimeMinutes: 45,
      calorieTarget: 600,
      calorieTolerance: 100,
    );

    test('accepts a recipe satisfying every hard filter', () {
      final recipe = testRecipe(
        attributes: {'easy', 'halal'},
        ingredients: [testIngredient(id: 'tomato')],
      );
      expect(
        RecipeMatcher.visible(
          recipe,
          base.copyWith(requiredAttributes: {'halal'}),
        ),
        isTrue,
      );
    });

    test('rejects intersecting class flags', () {
      final recipe = testRecipe(contains: {'dairy'});
      expect(
        RecipeMatcher.visible(recipe, base.copyWith(avoidFlags: {'dairy'})),
        isFalse,
      );
    });

    test('rejects specific avoided ingredients', () {
      final recipe = testRecipe(ingredients: [testIngredient(id: 'cilantro')]);
      expect(
        RecipeMatcher.visible(
          recipe,
          base.copyWith(avoidIngredients: {'cilantro'}),
        ),
        isFalse,
      );
    });

    test('uses expanded hierarchy and compound sets when provided', () {
      final recipe = testRecipe(
        contains: {'egg'},
        ingredients: [testIngredient(id: 'parmesan')],
      );
      expect(
        RecipeMatcher.visible(
          recipe,
          base.copyWith(avoidFlags: {'vegan'}, avoidIngredients: {'cheese'}),
          expandedAvoidFlags: {'egg', 'dairy'},
          expandedAvoidIngredients: {'cheese', 'parmesan'},
        ),
        isFalse,
      );
    });

    test('requires all positive attributes', () {
      final recipe = testRecipe(attributes: {'easy', 'halal'});
      expect(
        RecipeMatcher.visible(
          recipe,
          base.copyWith(requiredAttributes: {'halal', 'kosher'}),
        ),
        isFalse,
      );
    });

    test('enforces time and calories independently', () {
      expect(RecipeMatcher.visible(testRecipe(timeMinutes: 46), base), isFalse);
      expect(RecipeMatcher.visible(testRecipe(calories: 701), base), isFalse);
      expect(
        RecipeMatcher.visible(
          testRecipe(calories: 701),
          base,
          ignoreCalories: true,
        ),
        isTrue,
      );
    });
  });

  group('RecipeMatcher ranking', () {
    const profile = UserProfile(
      maxTimeMinutes: 60,
      calorieTarget: 600,
      preferredEffort: 'medium',
    );

    test('prioritizes required attributes then effort and closeness', () {
      final required = testRecipe(
        id: 'required',
        attributes: {'easy', 'halal'},
        effort: 'easy',
        calories: 500,
      );
      final effort = testRecipe(
        id: 'effort',
        attributes: {'medium'},
        effort: 'medium',
      );
      final ranked = RecipeMatcher.ranked([
        effort,
        required,
      ], profile.copyWith(requiredAttributes: {'halal'}));
      expect(ranked.first.id, 'required');
    });

    test('adds morning, evening and weekend context bonuses', () {
      final breakfast = testRecipe(
        id: 'breakfast',
        effort: 'medium',
        attributes: {'medium'},
        mealTypes: {'breakfast'},
      );
      final dinner = testRecipe(
        id: 'dinner',
        effort: 'medium',
        attributes: {'medium'},
        mealTypes: {'dinner'},
      );
      expect(
        RecipeMatcher.rankScore(
              breakfast,
              profile,
              now: DateTime(2026, 7, 6, 8),
            ) -
            RecipeMatcher.rankScore(
              dinner,
              profile,
              now: DateTime(2026, 7, 6, 8),
            ),
        200,
      );
      expect(
        RecipeMatcher.rankScore(
              dinner,
              profile,
              now: DateTime(2026, 7, 6, 18),
            ) -
            RecipeMatcher.rankScore(
              breakfast,
              profile,
              now: DateTime(2026, 7, 6, 18),
            ),
        90,
      );
      final hard = testRecipe(id: 'hard', effort: 'hard', attributes: {'hard'});
      final weekday = RecipeMatcher.rankScore(
        hard,
        profile,
        now: DateTime(2026, 7, 8, 13),
      );
      final weekend = RecipeMatcher.rankScore(
        hard,
        profile,
        now: DateTime(2026, 7, 11, 13),
      );
      expect(weekend - weekday, 90);
    });

    test('boosts only recipes last cooked at least 30 days ago', () {
      final recipe = testRecipe(effort: 'medium', attributes: {'medium'});
      final now = DateTime(2026, 7, 10, 12);
      final never = RecipeMatcher.rankScore(recipe, profile, now: now);
      final recent = RecipeMatcher.rankScore(
        recipe,
        profile,
        now: now,
        lastCooked: now.subtract(const Duration(days: 29)),
      );
      final stale = RecipeMatcher.rankScore(
        recipe,
        profile,
        now: now,
        lastCooked: now.subtract(const Duration(days: 30)),
      );
      expect(recent, never);
      expect(stale - never, 50);
    });
  });
}
