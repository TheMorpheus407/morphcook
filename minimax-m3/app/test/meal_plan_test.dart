import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/models/meal_plan_entry.dart';

void main() {
  group('isoWeekKey', () {
    test('produces YYYY-WNN form', () {
      final key = isoWeekKey(DateTime(2026, 1, 5)); // Mon, week 2 of 2026
      expect(key, equals('2026-W02'));
    });

    test('week 1 boundary', () {
      // 2025-12-29 is a Monday, ISO-week 1 of 2026
      final key = isoWeekKey(DateTime(2025, 12, 29));
      expect(key.contains('W01'), isTrue);
    });
  });

  group('mondayOf', () {
    test('Wednesday → previous Monday', () {
      final m = mondayOf(DateTime(2026, 6, 3)); // Wed
      expect(m, equals(DateTime(2026, 6, 1)));
    });

    test('Monday → same day', () {
      final m = mondayOf(DateTime(2026, 6, 1));
      expect(m, equals(DateTime(2026, 6, 1)));
    });
  });
}
