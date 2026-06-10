import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/ranking.dart';
import 'package:morphcook/models/collections.dart';
import 'package:morphcook/models/profile.dart';

import 'helpers.dart';

void main() {
  // Fixed clocks: a Tuesday at noon as the neutral default.
  final tuesdayNoon = DateTime(2026, 6, 9, 12);
  final tuesdayMorning = DateTime(2026, 6, 9, 8);
  final tuesdayEvening = DateTime(2026, 6, 9, 18);
  final saturdayNoon = DateTime(2026, 6, 13, 12);

  Ranker rankerAt(DateTime t) => Ranker(now: () => t);

  group('base score', () {
    test('required-attribute matches dominate effort match', () {
      final ranker = rankerAt(tuesdayNoon);
      const profile = Profile(
          requiredAttributes: {'halal'}, preferredEffort: 'easy');
      final attrMatch = makeRecipe(
          id: 'a', attributes: {'halal'}, effort: 'hard');
      final effortMatch = makeRecipe(id: 'b', effort: 'easy');
      expect(ranker.baseScore(attrMatch, profile),
          greaterThan(ranker.baseScore(effortMatch, profile)));
    });

    test('effort match beats time closeness', () {
      final ranker = rankerAt(tuesdayNoon);
      const profile =
          Profile(preferredEffort: 'easy', maxTimeMinutes: 30);
      final effortMatch =
          makeRecipe(id: 'a', effort: 'easy', timeMinutes: 90);
      final timeClose =
          makeRecipe(id: 'b', effort: 'hard', timeMinutes: 30);
      expect(ranker.baseScore(effortMatch, profile),
          greaterThan(ranker.baseScore(timeClose, profile)));
    });

    test('calorie closeness breaks remaining ties', () {
      final ranker = rankerAt(tuesdayNoon);
      const profile = Profile(calorieTarget: 500);
      final close = makeRecipe(id: 'a', calories: 510);
      final far = makeRecipe(id: 'b', calories: 640);
      expect(ranker.baseScore(close, profile),
          greaterThan(ranker.baseScore(far, profile)));
    });
  });

  group('time-aware bonuses', () {
    test('breakfast gets +200 in the morning (5–11)', () {
      final ranker = rankerAt(tuesdayMorning);
      final breakfast = makeRecipe(meal: ['breakfast']);
      final dinner = makeRecipe(meal: ['dinner']);
      expect(ranker.contextBonus(breakfast), 200);
      expect(ranker.contextBonus(dinner), 0);
    });

    test('dinner gets +90 in the evening (17–21)', () {
      final ranker = rankerAt(tuesdayEvening);
      final dinner = makeRecipe(meal: ['lunch', 'dinner']);
      expect(ranker.contextBonus(dinner), 90);
    });

    test('weekend boosts medium and hard effort by +90', () {
      final ranker = rankerAt(saturdayNoon);
      expect(ranker.contextBonus(makeRecipe(effort: 'hard')), 90);
      expect(ranker.contextBonus(makeRecipe(effort: 'medium')), 90);
      expect(ranker.contextBonus(makeRecipe(effort: 'easy')), 0);
    });

    test('no bonuses on a weekday noon', () {
      final ranker = rankerAt(tuesdayNoon);
      expect(
          ranker.contextBonus(
              makeRecipe(effort: 'hard', meal: ['breakfast', 'dinner'])),
          0);
    });

    test('bonuses stack (weekend evening, hard dinner recipe)', () {
      final ranker = rankerAt(DateTime(2026, 6, 13, 18));
      expect(
          ranker.contextBonus(
              makeRecipe(effort: 'hard', meal: ['dinner'])),
          180);
    });
  });

  group('staleness bonus', () {
    test('+50 when last cooked 30+ days ago', () {
      final ranker = rankerAt(tuesdayNoon);
      final recipe = makeRecipe(id: 'r');
      final history = [
        HistoryEntry(
            recipeId: 'r',
            cookedAt: tuesdayNoon.subtract(const Duration(days: 31))),
      ];
      expect(ranker.stalenessBonus(recipe, history), 50);
    });

    test('no bonus when never cooked or cooked recently', () {
      final ranker = rankerAt(tuesdayNoon);
      final recipe = makeRecipe(id: 'r');
      expect(ranker.stalenessBonus(recipe, const []), 0);
      final recent = [
        HistoryEntry(
            recipeId: 'r',
            cookedAt: tuesdayNoon.subtract(const Duration(days: 5))),
      ];
      expect(ranker.stalenessBonus(recipe, recent), 0);
    });

    test('most recent cook decides', () {
      final ranker = rankerAt(tuesdayNoon);
      final recipe = makeRecipe(id: 'r');
      final history = [
        HistoryEntry(
            recipeId: 'r',
            cookedAt: tuesdayNoon.subtract(const Duration(days: 90))),
        HistoryEntry(
            recipeId: 'r',
            cookedAt: tuesdayNoon.subtract(const Duration(days: 3))),
      ];
      expect(ranker.stalenessBonus(recipe, history), 0);
    });
  });

  group('pickBest', () {
    test('selects highest total score among visible variants', () {
      final ranker = rankerAt(tuesdayMorning);
      const profile = Profile(preferredEffort: 'easy');
      final breakfastEasy = makeRecipe(
          id: 'breakfast-easy', effort: 'easy', meal: ['breakfast']);
      final dinnerEasy =
          makeRecipe(id: 'dinner-easy', effort: 'easy', meal: ['dinner']);
      final best = ranker
          .pickBest([dinnerEasy, breakfastEasy], profile, const []);
      expect(best?.id, 'breakfast-easy');
    });

    test('returns null for no candidates', () {
      final ranker = rankerAt(tuesdayNoon);
      expect(ranker.pickBest(const [], const Profile(), const []), isNull);
    });
  });
}
