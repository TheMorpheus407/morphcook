import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/models/shopping.dart';

void main() {
  group('IsoWeek', () {
    test('known ISO week anchors', () {
      // 2026-01-01 is a Thursday → week 1 of 2026
      expect(IsoWeek.of(DateTime(2026, 1, 1)), '2026-W01');
      // 2026-08-14 (today per project context) — Friday of week 33
      expect(IsoWeek.of(DateTime(2026, 8, 14)), '2026-W33');
      // A Monday stays in the same week
      expect(IsoWeek.of(DateTime(2026, 8, 10)), '2026-W33');
      // A Sunday belongs to the week started the Monday before
      expect(IsoWeek.of(DateTime(2026, 8, 16)), '2026-W33');
    });

    test('monday resolves back to the week start', () {
      expect(IsoWeek.mondayOf('2026-W33'), DateTime.utc(2026, 8, 10));
      expect(IsoWeek.mondayOf('2026-W01'), DateTime.utc(2025, 12, 29));
    });

    test('next and previous step by one week', () {
      expect(IsoWeek.next('2026-W33'), '2026-W34');
      expect(IsoWeek.previous('2026-W33'), '2026-W32');
      // 2026 is a 53-week year (starts on a Thursday); 2025 has 52
      expect(IsoWeek.next('2026-W52'), '2026-W53');
      expect(IsoWeek.previous('2026-W01'), '2025-W52');
      expect(IsoWeek.next('2026-W53'), '2027-W01');
    });

    test('year boundary: last days of 2025 belong to 2026-W01', () {
      expect(IsoWeek.of(DateTime(2025, 12, 31)), '2026-W01');
    });
  });

  group('meal plan slot constants', () {
    test('21 slots: 7 weekdays × 3 meals', () {
      expect(mealPlanSlots.length, 21);
      expect(mealPlanSlots.first, 'mon.breakfast');
      expect(mealPlanSlots.last, 'sun.dinner');
      expect(mealPlanWeekdays.length, 7);
      expect(mealPlanMeals.length, 3);
    });
  });
}
