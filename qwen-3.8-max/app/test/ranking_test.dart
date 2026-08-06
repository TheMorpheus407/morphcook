import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/models.dart';
import 'package:morphcook/data/profile.dart';
import 'package:morphcook/domain/ranking.dart';

Recipe _recipe({
  String id = 'r1',
  List<String> mealSlots = const ['dinner'],
  String effort = 'easy',
}) =>
    Recipe(
      id: id,
      dishId: 'd1',
      title: {'en': id},
      blurb: const {},
      handwritten: const {},
      dietAxis: 'classic',
      effortAxis: effort,
      calorieLevelAxis: 'standard',
      contains: const [],
      attributes: const [],
      techniques: const [],
      effort: effort,
      timeMinutes: 20,
      timeBucket: 't30',
      calorieBucket: 'c600',
      servings: 2,
      caloriesPerServing: 500,
      proteinG: 1,
      carbsG: 1,
      fatG: 1,
      mealSlots: mealSlots,
      tags: const [],
      ingredients: const [],
      ingredientIds: const [],
      steps: const [],
    );

void main() {
  group('time-aware ranking', () {
    test('breakfast gets +200 in the morning (5am–11am)', () {
      final breakfast = _recipe(mealSlots: ['breakfast']);
      final dinner = _recipe(mealSlots: ['dinner']);
      final morning = RankingContext(
        now: DateTime(2026, 8, 5, 8, 30), // Wednesday
        lastCooked: const {},
      );
      expect(timeOfDayBonus(breakfast, morning), 200);
      expect(timeOfDayBonus(dinner, morning), 0);
      // outside the window
      final noon = RankingContext(
        now: DateTime(2026, 8, 5, 12, 0),
        lastCooked: const {},
      );
      expect(timeOfDayBonus(breakfast, noon), 0);
    });

    test('dinner gets +90 in the evening (5pm–9pm)', () {
      final dinner = _recipe(mealSlots: ['dinner']);
      final evening = RankingContext(
        now: DateTime(2026, 8, 5, 19, 0),
        lastCooked: const {},
      );
      expect(timeOfDayBonus(dinner, evening), 90);
      final lateNight = RankingContext(
        now: DateTime(2026, 8, 5, 22, 0),
        lastCooked: const {},
      );
      expect(timeOfDayBonus(dinner, lateNight), 0);
    });

    test('weekend boosts medium and hard effort by +90', () {
      final hard = _recipe(effort: 'hard');
      final easy = _recipe(effort: 'easy');
      final saturday = RankingContext(
        now: DateTime(2026, 8, 8, 12, 0), // Saturday
        lastCooked: const {},
      );
      expect(saturday.isWeekend, isTrue);
      expect(timeOfDayBonus(hard, saturday), 90);
      expect(timeOfDayBonus(easy, saturday), 0);
      final wednesday = RankingContext(
        now: DateTime(2026, 8, 5, 12, 0),
        lastCooked: const {},
      );
      expect(timeOfDayBonus(hard, wednesday), 0);
    });
  });

  group('staleness-aware ranking', () {
    test('not cooked in 30+ days gets +50', () {
      final now = DateTime(2026, 8, 5);
      final ctx = RankingContext(now: now, lastCooked: {
        'r1': now.subtract(const Duration(days: 31)),
      });
      expect(stalenessBonus(_recipe(), ctx), 50);
    });

    test('recently cooked gets no bonus', () {
      final now = DateTime(2026, 8, 5);
      final ctx = RankingContext(now: now, lastCooked: {
        'r1': now.subtract(const Duration(days: 3)),
      });
      expect(stalenessBonus(_recipe(), ctx), 0);
    });

    test('never cooked gets no bonus', () {
      final ctx = RankingContext(
        now: DateTime(2026, 8, 5),
        lastCooked: const {},
      );
      expect(stalenessBonus(_recipe(), ctx), 0);
    });
  });

  test('rankRecipe combines base, variant, temporal and staleness scores',
      () {
    final now = DateTime(2026, 8, 8, 19, 0); // Saturday evening
    final ctx = RankingContext(now: now, lastCooked: {
      'r1': now.subtract(const Duration(days: 40)),
    });
    final hardDinner = _recipe(effort: 'hard', mealSlots: ['dinner']);
    final dish = Dish(
      id: 'd1',
      name: const {'en': 'Dish'},
      hero: const {},
      capCaption: const {},
      stripeColor: '#000000',
      recipeIds: const ['r1'],
      partitionId: 'core',
      secondaryPartitions: const [],
      cuisineTags: const [],
      frequencyTier: 1,
      categories: const [],
      mealSlots: const [],
      tags: const [],
    );
    final score = rankRecipe(hardDinner, dish, Profile(), ctx);
    // base (4-1)*40=120 + variant part + 90 evening + 90 weekend + 50 stale
    expect(score, greaterThanOrEqualTo(120 + 90 + 90 + 50));
  });
}
