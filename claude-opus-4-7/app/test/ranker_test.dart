import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/matching/ranker.dart';
import 'package:morphcook/models/localized.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/recipe.dart';

Recipe _r(
  String id, {
  List<String> attributes = const [],
  String effort = 'medium',
  int time = 30,
  int calories = 500,
}) =>
    Recipe(
      id: id,
      dishId: 'd',
      name: Localized({'en': id}),
      description: const Localized({'en': ''}),
      variantTag: const Localized({'en': 'classic'}),
      contains: const [],
      attributes: attributes,
      effort: effort,
      timeMinutes: time,
      caloriesPerServing: calories,
      servings: 2,
      ingredients: const [],
      steps: const [],
      cuisineTags: const [],
      partitionId: 'core',
      secondaryPartitions: const [],
      frequencyTier: 1,
      ingredientIds: const {},
    );

void main() {
  group('Ranker', () {
    test('preferred effort wins', () {
      final ranker = Ranker(now: DateTime(2026, 5, 21, 13)); // mid-day weekday
      final easy = _r('easy', effort: 'easy');
      final hard = _r('hard', effort: 'hard');
      final p = const Profile(preferredEffort: 'easy');
      expect(ranker.pickBest([hard, easy], p)?.id, 'easy');
    });

    test('breakfast bonus at morning', () {
      final ranker = Ranker(now: DateTime(2026, 5, 21, 8));
      final breakfast =
          _r('br', attributes: ['breakfast'], effort: 'easy', time: 20);
      final dinner = _r('di', attributes: ['dinner'], effort: 'easy', time: 20);
      final p = const Profile();
      expect(ranker.pickBest([dinner, breakfast], p)?.id, 'br');
    });

    test('dinner bonus at evening', () {
      final ranker = Ranker(now: DateTime(2026, 5, 21, 19));
      final breakfast =
          _r('br', attributes: ['breakfast'], effort: 'medium', time: 30);
      final dinner = _r('di', attributes: ['dinner'], effort: 'medium', time: 30);
      final p = const Profile();
      expect(ranker.pickBest([breakfast, dinner], p)?.id, 'di');
    });

    test('weekend boost favours medium/hard', () {
      final saturday = DateTime(2026, 5, 23, 14);
      final ranker = Ranker(now: saturday);
      final easy = _r('e', effort: 'easy', time: 20);
      final medium = _r('m', effort: 'medium', time: 60);
      final p = const Profile(preferredEffort: 'medium');
      expect(ranker.pickBest([easy, medium], p)?.id, 'm');
    });

    test('staleness bonus for >30-day-old cook', () {
      final now = DateTime(2026, 5, 21, 12);
      final old = now.subtract(const Duration(days: 35));
      final ranker = Ranker(
        now: now,
        lastCookedAt: {'stale': old, 'fresh': now.subtract(const Duration(days: 2))},
      );
      final stale = _r('stale', effort: 'easy', time: 20);
      final fresh = _r('fresh', effort: 'easy', time: 20);
      final p = const Profile(preferredEffort: 'easy');
      // both equally preferred — stale gets +50 → wins
      expect(ranker.pickBest([fresh, stale], p)?.id, 'stale');
    });

    test('calorie closeness scores higher', () {
      final ranker = Ranker(now: DateTime(2026, 5, 21, 13));
      final a = _r('a', calories: 500);
      final b = _r('b', calories: 700);
      final p = const Profile(calorieTarget: 500);
      expect(ranker.pickBest([a, b], p)?.id, 'a');
    });
  });
}
