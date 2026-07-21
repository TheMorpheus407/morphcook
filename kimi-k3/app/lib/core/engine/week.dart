/// ISO-8601 week helpers for the meal planner.
library;

/// '2026-W16' style key for the week containing [date].
String isoWeekKey(DateTime date) {
  // UTC to keep day arithmetic exact across DST transitions.
  final day = DateTime.utc(date.year, date.month, date.day);
  // Thursday of the current week determines the ISO week-year.
  final thursday = day.add(Duration(days: DateTime.thursday - day.weekday));
  final jan4 = DateTime.utc(thursday.year, 1, 4);
  final firstThursday =
      jan4.add(Duration(days: DateTime.thursday - jan4.weekday));
  final week = 1 + thursday.difference(firstThursday).inDays ~/ 7;
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

/// Monday of the week containing [date].
DateTime mondayOf(DateTime date) => DateTime(date.year, date.month, date.day)
    .subtract(Duration(days: date.weekday - 1));

/// Adds [weeks] to the week containing [date].
DateTime shiftWeeks(DateTime date, int weeks) =>
    date.add(Duration(days: 7 * weeks));

const weekDaySlots = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const mealSlots = ['breakfast', 'lunch', 'dinner'];

/// 'mon.dinner' style slot key.
String slotKey(int dayIndex, int mealIndex) =>
    '${weekDaySlots[dayIndex]}.${mealSlots[mealIndex]}';
