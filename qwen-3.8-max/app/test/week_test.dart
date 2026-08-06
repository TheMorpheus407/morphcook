import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/week.dart';

void main() {
  group('iso weeks', () {
    test('week key matches ISO numbering', () {
      expect(isoWeekKey(DateTime(2026, 4, 15)), '2026-W16'); // Wednesday
      expect(isoWeekKey(DateTime(2026, 1, 1)), '2026-W01');
      // 2027-01-01 is a Friday belonging to ISO week 2026-W53
      expect(isoWeekKey(DateTime(2027, 1, 1)), '2026-W53');
    });

    test('mondayOf returns the Monday of that week', () {
      expect(mondayOf(DateTime(2026, 4, 15)), DateTime(2026, 4, 13));
      expect(mondayOf(DateTime(2026, 4, 13)), DateTime(2026, 4, 13));
      expect(mondayOf(DateTime(2026, 4, 19)), DateTime(2026, 4, 13));
    });

    test('addWeeks moves by whole weeks', () {
      expect(addWeeks(DateTime(2026, 4, 13), 1), DateTime(2026, 4, 20));
      expect(addWeeks(DateTime(2026, 4, 13), -2), DateTime(2026, 3, 30));
    });

    test('slot keys round-trip', () {
      final key = slotKey('2026-W16', 'mon', 'dinner');
      expect(key, '2026-W16|mon|dinner');
      final parsed = parseSlotKey(key);
      expect(parsed, isNotNull);
      expect(parsed!.week, '2026-W16');
      expect(parsed.day, 'mon');
      expect(parsed.slot, 'dinner');
      expect(parseSlotKey('nonsense'), isNull);
    });
  });
}
