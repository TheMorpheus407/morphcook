import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/domain/plan/meal_plan.dart';

void main() {
  group('WeekKey', () {
    test('the spec example: 2026-W16 starts on Monday 13 April 2026', () {
      final week = WeekKey.parse('2026-W16');
      expect(week.monday, DateTime(2026, 4, 13));
      expect(WeekKey.fromDate(DateTime(2026, 4, 18)), week, reason: 'the exported_at date of the spec');
      expect(week.toString(), '2026-W16');
    });

    test('ISO week numbers, including the year boundaries', () {
      expect(WeekKey.fromDate(DateTime(2026, 1, 1)).toString(), '2026-W01');
      expect(WeekKey.fromDate(DateTime(2025, 12, 29)).toString(), '2026-W01', reason: 'Monday of week 1 of 2026');
      expect(WeekKey.fromDate(DateTime(2024, 12, 30)).toString(), '2025-W01');
      expect(WeekKey.fromDate(DateTime(2020, 12, 31)).toString(), '2020-W53');
      expect(WeekKey.fromDate(DateTime(2021, 1, 3)).toString(), '2020-W53');
      expect(WeekKey.fromDate(DateTime(2021, 1, 4)).toString(), '2021-W01');
      expect(WeekKey.fromDate(DateTime(2026, 12, 31)).toString(), '2026-W53');
    });

    test('Monday to Sunday all belong to one week', () {
      final monday = DateTime(2026, 9, 28);
      final key = WeekKey.fromDate(monday);
      for (var d = 0; d < 7; d++) {
        expect(WeekKey.fromDate(monday.add(Duration(days: d))), key);
      }
      expect(WeekKey.fromDate(monday.add(const Duration(days: 7))), isNot(key));
    });

    test('monday and dateOf are inverse to fromDate', () {
      final key = WeekKey.fromDate(DateTime(2026, 9, 30));
      expect(key.monday, DateTime(2026, 9, 28));
      expect(key.dateOf('mon'), DateTime(2026, 9, 28));
      expect(key.dateOf('wed'), DateTime(2026, 9, 30));
      expect(key.dateOf('sun'), DateTime(2026, 10, 4));
    });

    test('plusWeeks crosses years in both directions', () {
      final key = WeekKey.parse('2026-W52');
      expect(key.plusWeeks(1).toString(), '2026-W53');
      expect(key.plusWeeks(2).toString(), '2027-W01');
      expect(WeekKey.parse('2027-W01').plusWeeks(-1).toString(), '2026-W53');
      expect(key.plusWeeks(0), key);
    });

    test('ordering and equality', () {
      final a = WeekKey.parse('2026-W09');
      final b = WeekKey.parse('2026-W10');
      final c = WeekKey.parse('2027-W01');
      expect(a.compareTo(b), lessThan(0));
      expect(c.compareTo(b), greaterThan(0));
      expect(a, WeekKey(2026, 9));
      expect({a, WeekKey(2026, 9)}, hasLength(1));
    });

    test('a malformed key is rejected', () {
      expect(() => WeekKey.parse('2026-16'), throwsFormatException);
      expect(() => WeekKey.parse('W16'), throwsFormatException);
    });
  });

  group('the grid', () {
    test('Monday to Sunday by breakfast, lunch and dinner', () {
      expect(planDays, ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']);
      expect(planMeals, ['breakfast', 'lunch', 'dinner']);
      expect(slotKey('mon', 'dinner'), 'mon.dinner');
    });
  });

  group('MealPlan', () {
    final week = WeekKey.parse('2026-W16');
    final next = WeekKey.parse('2026-W17');

    test('assign puts a recipe into a slot and leaves the original untouched', () {
      final empty = MealPlan();
      final plan = empty.assign(week, 'mon.dinner', 'recipe-1');
      expect(plan.recipeAt(week, 'mon.dinner'), 'recipe-1');
      expect(empty.recipeAt(week, 'mon.dinner'), isNull);
      expect(empty.isEmpty, isTrue);
    });

    test('assigning to a taken slot replaces it', () {
      final plan = MealPlan().assign(week, 'mon.dinner', 'a').assign(week, 'mon.dinner', 'b');
      expect(plan.recipeAt(week, 'mon.dinner'), 'b');
    });

    test('clear empties a slot, and an empty week disappears', () {
      final plan = MealPlan().assign(week, 'mon.dinner', 'a');
      final cleared = plan.clear(week, 'mon.dinner');
      expect(cleared.recipeAt(week, 'mon.dinner'), isNull);
      expect(cleared.weeks, isEmpty);
    });

    test('moving to a free slot relocates the recipe', () {
      final plan = MealPlan().assign(week, 'mon.dinner', 'a').move(week, 'mon.dinner', week, 'tue.lunch');
      expect(plan.recipeAt(week, 'mon.dinner'), isNull);
      expect(plan.recipeAt(week, 'tue.lunch'), 'a');
    });

    test('moving onto an occupied slot swaps the two', () {
      final plan = MealPlan()
          .assign(week, 'mon.dinner', 'a')
          .assign(week, 'tue.lunch', 'b')
          .move(week, 'mon.dinner', week, 'tue.lunch');
      expect(plan.recipeAt(week, 'mon.dinner'), 'b');
      expect(plan.recipeAt(week, 'tue.lunch'), 'a');
    });

    test('moving between weeks works', () {
      final plan = MealPlan().assign(week, 'mon.dinner', 'a').move(week, 'mon.dinner', next, 'mon.dinner');
      expect(plan.recipeAt(week, 'mon.dinner'), isNull);
      expect(plan.recipeAt(next, 'mon.dinner'), 'a');
    });

    test('moving an empty slot or onto itself changes nothing', () {
      final plan = MealPlan().assign(week, 'mon.dinner', 'a');
      expect(identical(plan.move(week, 'tue.lunch', week, 'wed.lunch'), plan), isTrue);
      expect(identical(plan.move(week, 'mon.dinner', week, 'mon.dinner'), plan), isTrue);
    });

    test('recipeIdsOf reads in grid order and keeps repeats', () {
      final plan = MealPlan()
          .assign(week, 'fri.dinner', 'pizza')
          .assign(week, 'mon.breakfast', 'oats')
          .assign(week, 'mon.dinner', 'pizza')
          .assign(week, 'sun.lunch', 'soup');
      expect(plan.recipeIdsOf(week), ['oats', 'pizza', 'pizza', 'soup']);
      expect(plan.recipeIdsOf(next), isEmpty);
    });

    test('merging keeps what is already there and adds what is missing', () {
      final local = MealPlan().assign(week, 'mon.dinner', 'mine');
      final incoming = MealPlan()
          .assign(week, 'mon.dinner', 'theirs')
          .assign(week, 'tue.dinner', 'theirs-2')
          .assign(next, 'mon.lunch', 'theirs-3');
      final merged = local.mergedWith(incoming);
      expect(merged.recipeAt(week, 'mon.dinner'), 'mine');
      expect(merged.recipeAt(week, 'tue.dinner'), 'theirs-2');
      expect(merged.recipeAt(next, 'mon.lunch'), 'theirs-3');
    });

    test('JSON follows the backup format', () {
      final plan = MealPlan().assign(week, 'mon.dinner', 'recipe-id-3');
      expect(plan.toJson(), {
        '2026-W16': {'mon.dinner': 'recipe-id-3'},
      });
      final back = MealPlan.fromJson(plan.toJson());
      expect(back.recipeAt(week, 'mon.dinner'), 'recipe-id-3');
    });

    test('empty weeks are dropped when a plan is built', () {
      final plan = MealPlan({
        '2026-W16': <String, String>{},
        '2026-W17': {'mon.dinner': 'a'},
      });
      expect(plan.weeks.keys, ['2026-W17']);
    });
  });
}
