import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/engine/week.dart';

void main() {
  group('isoWeekKey', () {
    test('known ISO weeks', () {
      // 2026-07-20 is a Monday of ISO week 30.
      expect(isoWeekKey(DateTime(2026, 7, 20)), '2026-W30');
      expect(isoWeekKey(DateTime(2026, 7, 26)), '2026-W30');
      expect(isoWeekKey(DateTime(2026, 7, 27)), '2026-W31');
    });

    test('year boundary: 2026-01-01 belongs to 2026-W01', () {
      expect(isoWeekKey(DateTime(2026, 1, 1)), '2026-W01');
    });

    test('year boundary: 2025-12-29 belongs to 2026-W01', () {
      expect(isoWeekKey(DateTime(2025, 12, 29)), '2026-W01');
    });

    test('2024 leap-year boundary: 2024-12-30 is 2025-W01', () {
      expect(isoWeekKey(DateTime(2024, 12, 30)), '2025-W01');
    });
  });

  group('week helpers', () {
    test('mondayOf returns the Monday of the same week', () {
      expect(mondayOf(DateTime(2026, 7, 26)), DateTime(2026, 7, 20));
      expect(mondayOf(DateTime(2026, 7, 20)), DateTime(2026, 7, 20));
    });

    test('shiftWeeks moves whole weeks', () {
      expect(shiftWeeks(DateTime(2026, 7, 20), 1), DateTime(2026, 7, 27));
      expect(shiftWeeks(DateTime(2026, 7, 20), -2), DateTime(2026, 7, 6));
    });

    test('slotKey builds mon.dinner style keys', () {
      expect(slotKey(0, 2), 'mon.dinner');
      expect(slotKey(6, 0), 'sun.breakfast');
      expect(weekDaySlots, hasLength(7));
      expect(mealSlots, ['breakfast', 'lunch', 'dinner']);
    });
  });
}
