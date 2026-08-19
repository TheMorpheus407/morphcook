import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/mealplan.dart';

void main() {
  group('weekKeyOf (ISO week)', () {
    test('plain wednesday mid-year', () {
      expect(weekKeyOf(DateTime(2026, 8, 19)), '2026-W34'); // wednesday
    });

    test('january 1 stays in its own week logic', () {
      // 2026-01-01 is a thursday → W01
      expect(weekKeyOf(DateTime(2026, 1, 1)), '2026-W01');
    });

    test('december 28 of a W53 year rolls correctly', () {
      // 2026-12-28 monday → ISO week 53 of 2026
      expect(weekKeyOf(DateTime(2026, 12, 28)), '2026-W53');
    });
  });

  group('MealPlan', () {
    test('assign and read slots', () {
      var plan = const MealPlan();
      plan = plan.assign('2026-W34', 'mon.dinner', 'doener-vegan');
      expect(plan.slot('2026-W34', 'mon.dinner'), 'doener-vegan');
      expect(plan.slot('2026-W34', 'tue.dinner'), isNull);
      expect(plan.slot('2026-W35', 'mon.dinner'), isNull);
    });

    test('assign null clears the slot', () {
      var plan = const MealPlan()
          .assign('2026-W34', 'mon.dinner', 'doener-vegan');
      plan = plan.assign('2026-W34', 'mon.dinner', null);
      expect(plan.slot('2026-W34', 'mon.dinner'), isNull);
    });

    test('recipesOfWeek lists in day×meal order', () {
      final plan = const MealPlan()
          .assign('2026-W34', 'tue.lunch', 'b')
          .assign('2026-W34', 'mon.breakfast', 'a')
          .assign('2026-W34', 'sun.dinner', 'c');
      expect(plan.recipesOfWeek('2026-W34'), ['a', 'b', 'c']);
    });

    test('weeks are independent', () {
      final plan = const MealPlan()
          .assign('2026-W34', 'mon.dinner', 'x')
          .assign('2026-W35', 'mon.dinner', 'y');
      expect(plan.slot('2026-W34', 'mon.dinner'), 'x');
      expect(plan.slot('2026-W35', 'mon.dinner'), 'y');
    });

    test('json roundtrip', () {
      final plan = const MealPlan()
          .assign('2026-W34', 'mon.dinner', 'doener-vegan')
          .assign('2026-W34', 'sun.lunch', 'hummus-classic');
      final restored = MealPlan.fromJson(plan.toJson());
      expect(restored.slot('2026-W34', 'mon.dinner'), 'doener-vegan');
      expect(restored.slot('2026-W34', 'sun.lunch'), 'hummus-classic');
    });

    test('assign is immutable', () {
      const plan = MealPlan();
      plan.assign('2026-W34', 'mon.dinner', 'x');
      expect(plan.weeks, isEmpty);
    });
  });

  group('mondayOf', () {
    test('returns the monday of the current week', () {
      expect(mondayOf(DateTime(2026, 8, 19)), DateTime(2026, 8, 17)); // wed → mon
      expect(mondayOf(DateTime(2026, 8, 17)), DateTime(2026, 8, 17));
      expect(mondayOf(DateTime(2026, 8, 23)), DateTime(2026, 8, 17)); // sun
    });
  });
}
