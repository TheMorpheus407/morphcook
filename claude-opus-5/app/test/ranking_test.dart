import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/domain/profile.dart';
import 'package:morphcook/domain/ranking.dart';

import 'support/fixtures.dart';

void main() {
  const ranker = Ranker();

  // A Wednesday at 14:00 — no time-of-day and no weekend bonus applies.
  final neutral = DateTime(2026, 7, 22, 14);
  final morning = DateTime(2026, 7, 22, 8);
  final evening = DateTime(2026, 7, 22, 19);
  final saturday = DateTime(2026, 7, 25, 14);

  group('base ordering', () {
    test('attribute matches dominate every other term', () {
      const profile = Profile(
        requiredAttributes: {'high-protein'},
        preferredEffort: 'easy',
        maxTimeMinutes: 60,
        calorieTarget: 500,
      );
      final withAttr = makeRecipe(
        id: 'a',
        attributes: {'high-protein'},
        effort: 'hard',
        timeMinutes: 60,
        calories: 900,
      );
      final withoutAttr = makeRecipe(
        id: 'b',
        effort: 'easy',
        timeMinutes: 5,
        calories: 500,
      );
      expect(
        ranker.score(withAttr, profile, now: neutral),
        greaterThan(ranker.score(withoutAttr, profile, now: neutral)),
      );
    });

    test(
      'an exact effort match beats an adjacent one, which beats a distant one',
      () {
        const profile = Profile(preferredEffort: 'easy', maxTimeMinutes: 60);
        double at(String effort) => ranker.breakdown(
          makeRecipe(id: effort, effort: effort),
          profile,
          now: neutral,
        )['effort']!;
        expect(at('easy'), greaterThan(at('medium')));
        expect(at('medium'), greaterThan(at('hard')));
      },
    );

    test('a quicker recipe beats a slower one, all else equal', () {
      const profile = Profile(maxTimeMinutes: 60);
      final quick = makeRecipe(id: 'q', timeMinutes: 15);
      final slow = makeRecipe(id: 's', timeMinutes: 55);
      expect(
        ranker.score(quick, profile, now: neutral),
        greaterThan(ranker.score(slow, profile, now: neutral)),
      );
    });

    test('closer to the calorie target beats further away', () {
      const profile = Profile(calorieTarget: 500, maxTimeMinutes: 60);
      final close = makeRecipe(id: 'c', calories: 510);
      final far = makeRecipe(id: 'f', calories: 900);
      expect(
        ranker.score(close, profile, now: neutral),
        greaterThan(ranker.score(far, profile, now: neutral)),
      );
    });

    test('time closeness outranks calorie closeness', () {
      const profile = Profile(maxTimeMinutes: 60, calorieTarget: 500);
      final fastWrongCalories = makeRecipe(
        id: 'a',
        timeMinutes: 5,
        calories: 1000,
      );
      final slowRightCalories = makeRecipe(
        id: 'b',
        timeMinutes: 60,
        calories: 500,
      );
      expect(
        ranker.score(fastWrongCalories, profile, now: neutral),
        greaterThan(ranker.score(slowRightCalories, profile, now: neutral)),
      );
    });
  });

  group('time-aware bonuses', () {
    test('breakfast gets +200 between 05:00 and 11:00', () {
      const profile = Profile();
      final breakfast = makeRecipe(id: 'b', mealSlots: ['breakfast']);
      final base = ranker.breakdown(
        breakfast,
        profile,
        now: neutral,
      )['context']!;
      final bonus = ranker.breakdown(
        breakfast,
        profile,
        now: morning,
      )['context']!;
      expect(base, 0);
      expect(bonus, RankingBonuses.morningBreakfast.toDouble());
    });

    test('the morning bonus does not apply at 11:00 sharp', () {
      const profile = Profile();
      final breakfast = makeRecipe(id: 'b', mealSlots: ['breakfast']);
      final at11 = ranker.breakdown(
        breakfast,
        profile,
        now: DateTime(2026, 7, 22, 11),
      )['context']!;
      expect(at11, 0);
    });

    test('dinner gets +90 between 17:00 and 21:00', () {
      const profile = Profile();
      final dinner = makeRecipe(id: 'd', mealSlots: ['dinner'], effort: 'easy');
      expect(
        ranker.breakdown(dinner, profile, now: evening)['context'],
        RankingBonuses.eveningDinner.toDouble(),
      );
      expect(ranker.breakdown(dinner, profile, now: neutral)['context'], 0);
    });

    test('medium and hard effort get +90 at the weekend, easy does not', () {
      const profile = Profile();
      for (final effort in ['medium', 'hard']) {
        expect(
          ranker.breakdown(
            makeRecipe(id: effort, effort: effort),
            profile,
            now: saturday,
          )['context'],
          RankingBonuses.weekendEffort.toDouble(),
          reason: '$effort should get the weekend bonus',
        );
      }
      expect(
        ranker.breakdown(
          makeRecipe(id: 'easy', effort: 'easy'),
          profile,
          now: saturday,
        )['context'],
        0,
      );
    });

    test('bonuses stack', () {
      const profile = Profile();
      final sundayEvening = DateTime(2026, 7, 26, 19);
      final recipe = makeRecipe(id: 'r', mealSlots: ['dinner'], effort: 'hard');
      expect(
        ranker.breakdown(recipe, profile, now: sundayEvening)['context'],
        (RankingBonuses.eveningDinner + RankingBonuses.weekendEffort)
            .toDouble(),
      );
    });
  });

  group('staleness bonus', () {
    test('a recipe untouched for 30+ days gets +50', () {
      const profile = Profile();
      final recipe = makeRecipe(id: 'r');
      final stale = neutral.subtract(const Duration(days: 31));
      expect(
        ranker.breakdown(
          recipe,
          profile,
          now: neutral,
          lastCookedAt: stale,
        )['staleness'],
        RankingBonuses.staleRecipe.toDouble(),
      );
    });

    test('exactly 30 days counts as stale', () {
      const profile = Profile();
      final recipe = makeRecipe(id: 'r');
      final boundary = neutral.subtract(const Duration(days: 30));
      expect(
        ranker.breakdown(
          recipe,
          profile,
          now: neutral,
          lastCookedAt: boundary,
        )['staleness'],
        RankingBonuses.staleRecipe.toDouble(),
      );
    });

    test('recently cooked gets no bonus', () {
      const profile = Profile();
      final recipe = makeRecipe(id: 'r');
      final recent = neutral.subtract(const Duration(days: 3));
      expect(
        ranker.breakdown(
          recipe,
          profile,
          now: neutral,
          lastCookedAt: recent,
        )['staleness'],
        0,
      );
    });

    test('never cooked gets no bonus', () {
      const profile = Profile();
      expect(
        ranker.breakdown(
          makeRecipe(id: 'r'),
          profile,
          now: neutral,
        )['staleness'],
        0,
      );
    });
  });

  group('sort and best', () {
    test('ties break on the authored default, then on id', () {
      const profile = Profile();
      final a = makeRecipe(id: 'zzz', isDefault: true);
      final b = makeRecipe(id: 'aaa');
      final sorted = ranker.sort([b, a], profile, now: neutral);
      expect(sorted.first.id, 'zzz');
    });

    test('best returns the top-scoring recipe', () {
      const profile = Profile(
        requiredAttributes: {'high-protein'},
        maxTimeMinutes: 60,
      );
      final winner = makeRecipe(id: 'w', attributes: {'high-protein'});
      final loser = makeRecipe(id: 'l');
      expect(ranker.best([loser, winner], profile, now: neutral)?.id, 'w');
    });

    test('best on an empty list is null', () {
      expect(ranker.best(const [], const Profile(), now: neutral), isNull);
    });

    test('the staleness bonus can flip an otherwise even pair', () {
      const profile = Profile(maxTimeMinutes: 60);
      final fresh = makeRecipe(id: 'a-fresh');
      final neglected = makeRecipe(id: 'b-neglected');
      final sorted = ranker.sort(
        [fresh, neglected],
        profile,
        now: neutral,
        lastCookedByRecipe: {
          'b-neglected': neutral.subtract(const Duration(days: 60)),
        },
      );
      expect(sorted.first.id, 'b-neglected');
    });
  });
}
