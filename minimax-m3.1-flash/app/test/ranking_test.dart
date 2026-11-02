import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/src/domain/ranking.dart';
import 'package:morphcook/src/models/recipe.dart';

import 'support/fixtures.dart';

void main() {
  group('time context', () {
    test('breakfast recipes get a bonus in the morning', () {
      final breakfast = buildRecipe(
        id: 'breakfast',
        mealSlots: <String>['breakfast'],
      );
      final dinner = buildRecipe(
        id: 'dinner',
        mealSlots: <String>['dinner'],
      );
      final morning = DateTime(2026, 4, 18, 8);

      expect(Ranking.timeContextBonus(breakfast, morning), 200);
      expect(Ranking.timeContextBonus(dinner, morning), 0);
    });

    test('dinner recipes get a bonus in the evening', () {
      final dinner = buildRecipe(
        id: 'dinner',
        mealSlots: <String>['dinner'],
      );
      final evening = DateTime(2026, 4, 18, 19);

      expect(Ranking.timeContextBonus(dinner, evening), 90);
    });

    test('the morning window runs from five to eleven', () {
      expect(Ranking.isMorningContext(DateTime(2026, 4, 18, 5)), isTrue);
      expect(Ranking.isMorningContext(DateTime(2026, 4, 18, 10, 59)), isTrue);
      expect(Ranking.isMorningContext(DateTime(2026, 4, 18, 11)), isFalse);
      expect(Ranking.isMorningContext(DateTime(2026, 4, 18, 4, 59)), isFalse);
    });

    test('the evening window runs from five to nine', () {
      expect(Ranking.isEveningContext(DateTime(2026, 4, 18, 17)), isTrue);
      expect(Ranking.isEveningContext(DateTime(2026, 4, 18, 20, 59)), isTrue);
      expect(Ranking.isEveningContext(DateTime(2026, 4, 18, 21)), isFalse);
    });

    test('medium and hard recipes get a bonus at the weekend', () {
      final medium = buildRecipe(id: 'medium', effort: 'medium');
      final hard = buildRecipe(id: 'hard', effort: 'hard');
      final easy = buildRecipe(id: 'easy', effort: 'easy');
      final saturday = DateTime(2026, 4, 18, 12);

      expect(Ranking.timeContextBonus(medium, saturday), 90);
      expect(Ranking.timeContextBonus(hard, saturday), 90);
      expect(Ranking.timeContextBonus(easy, saturday), 0);
    });

    test('a weekday gets no weekend bonus', () {
      final medium = buildRecipe(effort: 'medium');
      final wednesday = DateTime(2026, 4, 15, 12);

      expect(Ranking.timeContextBonus(medium, wednesday), 0);
    });
  });

  group('staleness', () {
    test('a recipe untouched for thirty days gets a bonus', () {
      final recipe = buildRecipe(id: 'stale');
      final now = DateTime(2026, 4, 18);
      final lastCooked = <String, DateTime>{
        'stale': now.subtract(const Duration(days: 31)),
      };

      expect(Ranking.stalenessBonus(recipe, lastCooked, now), 50);
    });

    test('a recently cooked recipe gets nothing', () {
      final recipe = buildRecipe(id: 'recent');
      final now = DateTime(2026, 4, 18);
      final lastCooked = <String, DateTime>{
        'recent': now.subtract(const Duration(days: 3)),
      };

      expect(Ranking.stalenessBonus(recipe, lastCooked, now), 0);
    });

    test('a never cooked recipe gets nothing', () {
      final recipe = buildRecipe(id: 'never');

      expect(Ranking.stalenessBonus(recipe, <String, DateTime>{}, DateTime(2026, 4, 18)), 0);
    });
  });

  group('sorting', () {
    test('the time bonus pushes a breakfast recipe to the top', () {
      final breakfast = buildRecipe(
        id: 'breakfast',
        mealSlots: <String>['breakfast'],
      );
      final dinner = buildRecipe(
        id: 'dinner',
        mealSlots: <String>['dinner'],
      );

      final sorted = Ranking.sort(
        <Recipe>[dinner, breakfast],
        now: DateTime(2026, 4, 18, 8),
      );

      expect(sorted.first.id, 'breakfast');
    });

    test('the staleness bonus breaks a tie', () {
      final stale = buildRecipe(id: 'stale');
      final fresh = buildRecipe(id: 'fresh');
      final now = DateTime(2026, 4, 18);

      final sorted = Ranking.sort(
        <Recipe>[fresh, stale],
        now: now,
        lastCookedAt: <String, DateTime>{
          'stale': now.subtract(const Duration(days: 40)),
          'fresh': now.subtract(const Duration(days: 2)),
        },
      );

      expect(sorted.first.id, 'stale');
    });

    test('the base score is respected', () {
      final a = buildRecipe(id: 'a');
      final b = buildRecipe(id: 'b');

      final sorted = Ranking.sort(
        <Recipe>[a, b],
        now: DateTime(2026, 4, 18, 12),
        baseScore: (recipe) => recipe.id == 'b' ? 10 : 0,
      );

      expect(sorted.first.id, 'b');
    });
  });
}
