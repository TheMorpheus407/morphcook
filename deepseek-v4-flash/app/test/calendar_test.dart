import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/calendar.dart';
import 'package:morphcook/models/models.dart';

void main() {
  group('ISO weeks', () {
    test('2026-01-01 is week 1 of 2026 (Thursday)', () {
      final w = CalendarWeek.of(DateTime(2026, 1, 1));
      expect(w.weekNumber, 1);
      expect(w.year, 2026);
    });

    test('2025-12-29 (Monday) belongs to week 1 of 2026', () {
      final w = CalendarWeek.of(DateTime(2025, 12, 29));
      expect(w.weekNumber, 1);
      expect(w.year, 2026);
    });

    test('2026-08-05 is week 32', () {
      final w = CalendarWeek.of(DateTime(2026, 8, 5));
      expect(w.weekNumber, 32);
    });

    test('mondayOf(2026, 32) is 2026-08-03', () {
      final m = CalendarWeek.mondayOf(2026, 32);
      expect(m.year, 2026);
      expect(m.month, 8);
      expect(m.day, 3);
    });

    test('week key roundtrip', () {
      final w = CalendarWeek.of(DateTime(2026, 8, 5));
      expect(w.key, '2026-W32');
      expect(CalendarWeek.fromKey(w.key).weekNumber, 32);
    });

    test('previous/next navigation', () {
      final w = CalendarWeek.of(DateTime(2026, 8, 5));
      expect(w.previous.key, '2026-W31');
      expect(w.next.key, '2026-W33');
      expect(w.next.previous.key, w.key);
    });

    test('year boundary: 2027-01-01 is week 53 of 2026', () {
      final w = CalendarWeek.of(DateTime(2027, 1, 1));
      expect(w.year, 2026);
      expect(w.weekNumber, 53);
    });

    test('week spanning two months', () {
      final w = CalendarWeek.of(DateTime(2026, 8, 31)); // Monday
      expect(w.key, '2026-W36');
    });
  });

  test('dayOf walks from Monday', () {
    final w = CalendarWeek.of(DateTime(2026, 8, 3));
    expect(w.dayOf('mon'), DateTime(2026, 8, 3));
    expect(w.dayOf('sun'), DateTime(2026, 8, 9));
  });

  test('slot keys', () {
    expect(slotKey('mon', 'dinner'), 'mon.dinner');
  });

  test('labels', () {
    expect(mealLabel('en', 'breakfast'), 'Breakfast');
    expect(mealLabel('de', 'dinner'), 'Abendessen');
    expect(dayLabel('de', 'wed'), 'Mi');
    expect(dayLabel('en', 'sun'), 'Sun');
  });
}