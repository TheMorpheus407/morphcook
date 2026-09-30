import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/domain/ranking.dart';

import '../support/fixtures.dart';

void main() {
  const ranking = Ranking();

  // 2026-09-28 is a Monday, 2026-09-26 a Saturday, 2026-09-27 a Sunday.
  DateTime at(int day, int hour, [int minute = 0]) => DateTime(2026, 9, day, hour, minute);
  final monday = at(28, 12);

  RankingContext ctx(DateTime now, {Map<String, DateTime> lastCooked = const <String, DateTime>{}}) =>
      RankingContext(now: now, lastCooked: lastCooked);

  group('base score', () {
    test('effort match: same 1, neighbour 0.5, far end 0', () {
      expect(ranking.effortMatch('easy', 'easy'), 1);
      expect(ranking.effortMatch('easy', 'medium'), 0.5);
      expect(ranking.effortMatch('hard', 'medium'), 0.5);
      expect(ranking.effortMatch('easy', 'hard'), 0);
      expect(ranking.effortMatch('bogus', 'hard'), 0);
    });

    test('time closeness: 1 at the budget, falling towards 0, 0 without a budget', () {
      expect(ranking.timeCloseness(60, 60), 1);
      expect(ranking.timeCloseness(30, 60), 0.5);
      expect(ranking.timeCloseness(120, 60), 0);
      expect(ranking.timeCloseness(300, 60), 0, reason: 'clamped');
      expect(ranking.timeCloseness(30, null), 0);
    });

    test('calorie closeness: 1 on target, 0 at the edge of the tolerance', () {
      const profile = Profile(calorieTarget: 500);
      expect(ranking.calorieCloseness(500, profile), 1);
      expect(ranking.calorieCloseness(575, profile), closeTo(0.5, 1e-9));
      expect(ranking.calorieCloseness(650, profile), 0);
      expect(ranking.calorieCloseness(900, profile), 0);
      expect(ranking.calorieCloseness(500, const Profile()), 0);
    });

    test('the order is required attributes, then effort, then time, then calories', () {
      const profile = Profile(
        requiredAttributes: {'keto'},
        preferredEffort: 'easy',
        maxTimeMinutes: 30,
        calorieTarget: 500,
      );

      // One required match outweighs a perfect effort match.
      const hasKeto = MetaFixture(
        id: 'keto',
        attributes: {'keto'},
        effort: 'hard',
        timeMinutes: 90,
        caloriesPerServing: 900,
      );
      const perfectRest = MetaFixture(id: 'rest', effort: 'easy', timeMinutes: 30, caloriesPerServing: 500);
      expect(ranking.baseScore(hasKeto, profile), greaterThan(ranking.baseScore(perfectRest, profile)));

      // Effort outweighs time and calories.
      const rightEffort = MetaFixture(id: 'e', effort: 'easy', timeMinutes: 200, caloriesPerServing: 1200);
      const rightTimeAndKcal = MetaFixture(id: 't', effort: 'medium', timeMinutes: 30, caloriesPerServing: 500);
      expect(ranking.baseScore(rightEffort, profile), greaterThan(ranking.baseScore(rightTimeAndKcal, profile)));

      // Time outweighs calories.
      const rightTime = MetaFixture(id: 't2', effort: 'easy', timeMinutes: 30, caloriesPerServing: 1200);
      const rightKcal = MetaFixture(id: 'k', effort: 'easy', timeMinutes: 200, caloriesPerServing: 500);
      expect(ranking.baseScore(rightTime, profile), greaterThan(ranking.baseScore(rightKcal, profile)));
    });

    test('match_count counts every satisfied required attribute', () {
      const profile = Profile(requiredAttributes: {'keto', 'high-protein', 'one-pot'});
      const two = MetaFixture(attributes: {'keto', 'one-pot'});
      const one = MetaFixture(attributes: {'keto'});
      expect(ranking.baseScore(two, profile) - ranking.baseScore(one, profile), 1000);
    });
  });

  group('time-aware ranking', () {
    const breakfast = MetaFixture(id: 'b', meal: ['breakfast'], effort: 'easy');
    const dinner = MetaFixture(id: 'd', meal: ['dinner'], effort: 'easy');

    test('morning (5am to 11am): breakfast +200', () {
      expect(ranking.timeBonus(breakfast, at(28, 5)), 200);
      expect(ranking.timeBonus(breakfast, at(28, 10, 59)), 200);
      expect(ranking.timeBonus(breakfast, at(28, 4, 59)), 0);
      expect(ranking.timeBonus(breakfast, at(28, 11)), 0);
      expect(ranking.timeBonus(dinner, at(28, 8)), 0, reason: 'only breakfast recipes');
    });

    test('evening (5pm to 9pm): dinner +90', () {
      expect(ranking.timeBonus(dinner, at(28, 17)), 90);
      expect(ranking.timeBonus(dinner, at(28, 20, 59)), 90);
      expect(ranking.timeBonus(dinner, at(28, 16, 59)), 0);
      expect(ranking.timeBonus(dinner, at(28, 21)), 0);
      expect(ranking.timeBonus(breakfast, at(28, 18)), 0);
    });

    test('weekend: medium and hard effort +90', () {
      const medium = MetaFixture(effort: 'medium');
      const hard = MetaFixture(effort: 'hard');
      const easy = MetaFixture(effort: 'easy');
      expect(ranking.timeBonus(medium, at(26, 14)), 90, reason: 'Saturday');
      expect(ranking.timeBonus(hard, at(27, 14)), 90, reason: 'Sunday');
      expect(ranking.timeBonus(easy, at(26, 14)), 0);
      expect(ranking.timeBonus(medium, at(28, 14)), 0, reason: 'Monday');
      expect(ranking.timeBonus(medium, at(25, 14)), 0, reason: 'Friday');
    });

    test('the bonuses stack', () {
      const sundayDinner = MetaFixture(meal: ['dinner'], effort: 'medium');
      expect(ranking.timeBonus(sundayDinner, at(27, 18)), 180);
      const saturdayBreakfast = MetaFixture(meal: ['breakfast'], effort: 'hard');
      expect(ranking.timeBonus(saturdayBreakfast, at(26, 8)), 290);
    });

    test('a meal with several types earns each bonus that applies', () {
      const both = MetaFixture(meal: ['breakfast', 'dinner'], effort: 'easy');
      expect(ranking.timeBonus(both, at(28, 8)), 200);
      expect(ranking.timeBonus(both, at(28, 18)), 90);
    });
  });

  group('staleness-aware ranking', () {
    const recipe = MetaFixture(id: 'old');

    test('cooked 30 or more days ago: +50', () {
      final now = at(28, 12);
      expect(ranking.stalenessBonus(recipe, ctx(now, lastCooked: {'old': now.subtract(const Duration(days: 30))})), 50);
      expect(
        ranking.stalenessBonus(recipe, ctx(now, lastCooked: {'old': now.subtract(const Duration(days: 200))})),
        50,
      );
    });

    test('cooked recently: nothing', () {
      final now = at(28, 12);
      expect(
        ranking.stalenessBonus(
          recipe,
          ctx(now, lastCooked: {'old': now.subtract(const Duration(days: 29, hours: 23))}),
        ),
        0,
      );
      expect(ranking.stalenessBonus(recipe, ctx(now, lastCooked: {'old': now})), 0);
    });

    test('never cooked: nothing', () {
      expect(ranking.stalenessBonus(recipe, ctx(at(28, 12))), 0);
      expect(ranking.stalenessBonus(recipe, ctx(at(28, 12), lastCooked: {'other': DateTime(2020)})), 0);
    });
  });

  group('the bonuses apply on top of the base score', () {
    test('total = base + time bonus + staleness bonus', () {
      const profile = Profile(preferredEffort: 'medium', maxTimeMinutes: 60);
      const recipe = MetaFixture(id: 'x', meal: ['dinner'], timeMinutes: 45);
      final now = at(27, 18); // Sunday evening
      final context = ctx(now, lastCooked: {'x': now.subtract(const Duration(days: 45))});
      final breakdown = ranking.breakdown(recipe, profile, context);
      expect(breakdown.base, ranking.baseScore(recipe, profile));
      expect(breakdown.timeBonus, 180);
      expect(breakdown.stalenessBonus, 50);
      expect(ranking.score(recipe, profile, context), breakdown.base + 230);
    });

    test('a morning breakfast beats a slightly better base score', () {
      const profile = Profile(preferredEffort: 'medium', maxTimeMinutes: 30);
      const lunch = MetaFixture(id: 'lunch', meal: ['lunch'], timeMinutes: 30);
      const breakfast = MetaFixture(id: 'brk', meal: ['breakfast'], timeMinutes: 20, effort: 'easy');
      final morning = ctx(at(28, 8));
      expect(ranking.score(breakfast, profile, morning), greaterThan(ranking.score(lunch, profile, morning)));
      final noon = ctx(at(28, 13));
      expect(ranking.score(breakfast, profile, noon), lessThan(ranking.score(lunch, profile, noon)));
    });

    test('a neglected recipe overtakes an otherwise equal fresh one', () {
      const profile = Profile();
      const a = MetaFixture(id: 'a');
      const b = MetaFixture(id: 'b');
      final context = ctx(monday, lastCooked: {'b': monday.subtract(const Duration(days: 60))});
      expect(ranking.sorted([a, b], profile, context).map((r) => r.id), ['b', 'a']);
    });
  });

  group('picking and sorting', () {
    test('bestOf picks the highest score, ties resolve by id', () {
      const profile = Profile(preferredEffort: 'easy');
      const easy = MetaFixture(id: 'z-easy', effort: 'easy');
      const hard = MetaFixture(id: 'a-hard', effort: 'hard');
      expect(ranking.bestOf([hard, easy], profile, ctx(monday))!.id, 'z-easy');
      const twin1 = MetaFixture(id: 'b-twin');
      const twin2 = MetaFixture(id: 'a-twin');
      expect(ranking.bestOf([twin1, twin2], profile, ctx(monday))!.id, 'a-twin');
    });

    test('bestOf of nothing is null', () {
      expect(ranking.bestOf(const <MetaFixture>[], const Profile(), ctx(monday)), isNull);
    });

    test('sorted is stable and deterministic', () {
      const profile = Profile();
      final recipes = [
        for (final id in ['c', 'a', 'b']) MetaFixture(id: id),
      ];
      expect(ranking.sorted(recipes, profile, ctx(monday)).map((r) => r.id), ['a', 'b', 'c']);
    });
  });
}
