import 'package:flutter_test/flutter_test.dart';

import 'package:morphcook/core/util/dates.dart';
import 'package:morphcook/core/models/user_data.dart';

void main() {
  group('IsoWeek', () {
    test('computes ISO-8601 week keys (weeks start monday)', () {
      expect(IsoWeek.keyOf(DateTime(2026, 1, 1)), '2026-W01');
      expect(IsoWeek.keyOf(DateTime(2026, 8, 12)), '2026-W33');
      // 2026 starts on a thursday → it has 53 ISO weeks.
      expect(IsoWeek.keyOf(DateTime(2026, 12, 28)), '2026-W53');
    });

    test('mondayOf is always a monday', () {
      for (final key in ['2026-W33', '2026-W01', '2026-W53', '2026-W09']) {
        expect(IsoWeek.mondayOf(key).weekday, DateTime.monday, reason: key);
      }
    });

    test('shift moves by whole weeks', () {
      expect(IsoWeek.shift('2026-W33', 1), '2026-W34');
      expect(IsoWeek.shift('2026-W34', -1), '2026-W33');
      // Across the year boundary (2026 → 2027).
      expect(IsoWeek.shift('2026-W53', 1), '2027-W01');
    });

    test('labels are localized', () {
      final en = IsoWeek.label('2026-W33', 'en');
      final de = IsoWeek.label('2026-W33', 'de');
      expect(en, contains('W33'));
      expect(de, contains('KW33'));
    });
  });

  group('DateFmt', () {
    test('date lines are bilingual', () {
      final date = DateTime(2026, 8, 15); // a saturday
      expect(DateFmt.dateLine(date, 'en'), 'saturday, august 15, 2026');
      expect(DateFmt.dateLine(date, 'de'), 'samstag, 15. august 2026');
    });

    test('short dates', () {
      expect(DateFmt.shortDate(DateTime(2026, 8, 5), 'en'), 'aug 5');
      expect(DateFmt.shortDate(DateTime(2026, 8, 5), 'de'), '5. aug.');
    });

    test('weekday names from slot ids', () {
      expect(DateFmt.weekdayShortFromSlot('mon', 'en'), 'mon');
      expect(DateFmt.weekdayShortFromSlot('mon', 'de'), 'mo');
    });
  });

  group('MealPlan', () {
    test('assign, read and clear slots', () {
      final plan = MealPlan();
      plan.assign('2026-W33', 'mon.dinner', 'doener-vegan');
      expect(plan.recipeAt('2026-W33', 'mon.dinner'), 'doener-vegan');
      plan.clear('2026-W33', 'mon.dinner');
      expect(plan.recipeAt('2026-W33', 'mon.dinner'), isNull);
    });

    test('drag & drop moves and swaps', () {
      final plan = MealPlan();
      plan.assign('2026-W33', 'mon.dinner', 'a');
      plan.assign('2026-W33', 'tue.dinner', 'b');
      plan.move('2026-W33', 'mon.dinner', '2026-W33', 'tue.dinner');
      expect(plan.recipeAt('2026-W33', 'tue.dinner'), 'a');
      expect(plan.recipeAt('2026-W33', 'mon.dinner'), 'b'); // swapped
    });

    test('drag onto an empty slot moves without swap', () {
      final plan = MealPlan();
      plan.assign('2026-W33', 'mon.dinner', 'a');
      plan.move('2026-W33', 'mon.dinner', '2026-W34', 'fri.lunch');
      expect(plan.recipeAt('2026-W34', 'fri.lunch'), 'a');
      expect(plan.recipeAt('2026-W33', 'mon.dinner'), isNull);
    });

    test('week export lists assigned recipes in day/meal order', () {
      final plan = MealPlan();
      plan.assign('2026-W33', 'sun.dinner', 'late');
      plan.assign('2026-W33', 'mon.breakfast', 'early');
      expect(plan.recipesOfWeek('2026-W33'), ['early', 'late']);
    });

    test('json round trip', () {
      final plan = MealPlan.fromJson({
        '2026-W33': {'mon.dinner': 'x'}
      });
      expect(plan.recipeAt('2026-W33', 'mon.dinner'), 'x');
      expect(MealPlan.fromJson(plan.toJson()).recipeAt('2026-W33', 'mon.dinner'), 'x');
    });
  });
}
