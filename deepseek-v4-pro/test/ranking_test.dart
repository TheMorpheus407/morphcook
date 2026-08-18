import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/matching.dart' as engine;
import 'package:morphcook/logic/ranking.dart';
import 'package:morphcook/models/ingredient.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/recipe.dart';

Recipe recipe({
  required String id,
  Set<String> mealTypes = const {'dinner'},
  String effort = 'easy',
  int time = 30,
  int calories = 500,
}) {
  return Recipe(
    id: id,
    dishId: 'dish',
    name: {'en': id},
    blurb: const {},
    contains: const {},
    ingredientIds: const [],
    attributes: const {},
    effort: effort,
    timeMinutes: time,
    timeBucket: 'le30',
    caloriesPerServing: calories,
    calorieBucket: 'le600',
    servings: 2,
    cuisine: 'test',
    mealTypes: mealTypes,
    technique: const {},
    tags: const {},
    stripeColors: const [],
    caption: const {},
    ingredients: const [],
    steps: const [],
    nutrition: const Nutrition(),
  );
}

void main() {
  final matcher = engine.Matcher(ingredientTree: IngredientTree.fromJson(const {'tree': []}));
  const ranker = Ranker();
  const profile = Profile();

  group('time-aware context', () {
    test('morning 5–11 boosts breakfast by 200', () {
      final breakfast = recipe(id: 'b', mealTypes: {'breakfast'});
      final dinner = recipe(id: 'd', mealTypes: {'dinner'});
      final morning = DateTime(2026, 8, 14, 8);
      final breakfastScore = ranker.totalScore(breakfast, profile, matcher, morning);
      final dinnerScore = ranker.totalScore(dinner, profile, matcher, morning);
      expect(breakfastScore - dinnerScore >= 200 - 90, isTrue);
      expect(ranker.isMorning(morning), isTrue);
    });

    test('evening 17–21 boosts dinner by 90', () {
      final dinner = recipe(id: 'd', mealTypes: {'dinner'});
      final lunch = recipe(id: 'l', mealTypes: {'lunch'});
      final evening = DateTime(2026, 8, 14, 19);
      final dinnerScore = ranker.totalScore(dinner, profile, matcher, evening);
      final lunchScore = ranker.totalScore(lunch, profile, matcher, evening);
      expect(dinnerScore - lunchScore, greaterThanOrEqualTo(90));
      expect(ranker.isEvening(evening), isTrue);
    });

    test('weekend boosts medium/hard recipes by 90', () {
      final hard = recipe(id: 'h', effort: 'hard');
      final easy = recipe(id: 'e', effort: 'easy');
      final saturday = DateTime(2026, 8, 15); // a Saturday
      expect(ranker.isWeekend(saturday), isTrue);
      final hardScore = ranker.totalScore(hard, profile, matcher, saturday);
      final easyScore = ranker.totalScore(easy, profile, matcher, saturday);
      expect(hardScore - easyScore, greaterThanOrEqualTo(90));

      final monday = DateTime(2026, 8, 10); // a Monday
      expect(ranker.isWeekend(monday), isFalse);
    });
  });

  group('staleness-aware ranking', () {
    test('not cooked in 30+ days gets +50', () {
      final r = recipe(id: 'r');
      final now = DateTime(2026, 8, 14);
      final stale = {r.id: DateTime(2026, 7, 1)}; // 44 days ago
      expect(ranker.stalenessBonus(r, now, stale), 50);
    });

    test('recently cooked gets no bonus', () {
      final r = recipe(id: 'r');
      final now = DateTime(2026, 8, 14);
      final recent = {r.id: DateTime(2026, 8, 10)};
      expect(ranker.stalenessBonus(r, now, recent), 0);
    });

    test('never cooked gets no bonus', () {
      final r = recipe(id: 'r');
      final now = DateTime(2026, 8, 14);
      expect(ranker.stalenessBonus(r, now, null), 0);
      expect(ranker.stalenessBonus(r, now, {}), 0);
    });

    test('exactly 30 days is not stale (needs 30+)', () {
      final r = recipe(id: 'r');
      final now = DateTime(2026, 8, 14);
      final thirty = {r.id: DateTime(2026, 7, 15)};
      expect(ranker.stalenessBonus(r, now, thirty), 0);
    });
  });

  group('rank', () {
    test('sorts visible recipes best-first', () {
      final a = recipe(id: 'a', mealTypes: {'breakfast'});
      final b = recipe(id: 'b', mealTypes: {'dinner'});
      final morning = DateTime(2026, 8, 14, 8);
      final ranked = ranker.rank([b, a], profile, matcher, now: morning);
      expect(ranked.first.id, 'a');
    });

    test('invisible recipes are dropped', () {
      final hidden = Recipe(
        id: 'hidden',
        dishId: 'dish',
        name: {'en': 'hidden'},
        blurb: const {},
        contains: {'pork'},
        ingredientIds: const [],
        attributes: const {},
        effort: 'easy',
        timeMinutes: 20,
        timeBucket: 'le30',
        caloriesPerServing: 500,
        calorieBucket: 'le600',
        servings: 2,
        cuisine: 'test',
        mealTypes: const {'dinner'},
        technique: const {},
        tags: const {},
        stripeColors: const [],
        caption: const {},
        ingredients: const [],
        steps: const [],
        nutrition: const Nutrition(),
      );
      final visible = recipe(id: 'v');
      final p = profile.copyWith(avoidFlags: {'pork'});
      final ranked = ranker.rank([hidden, visible], p, matcher);
      expect(ranked.map((r) => r.id), ['v']);
    });
  });
}
