/// ISO-week helpers for the meal plan grid.
library;

String isoWeekKey(DateTime date) {
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final year = thursday.year;
  final jan4 = DateTime(year, 1, 4);
  final jan4Weekday = jan4.weekday;
  final mondayOfWeek1 = jan4.subtract(Duration(days: jan4Weekday - 1));
  final week =
      ((thursday.difference(mondayOfWeek1).inDays) / 7).floor() + 1;
  return '$year-W${week.toString().padLeft(2, '0')}';
}

DateTime mondayOf(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return d.subtract(Duration(days: d.weekday - 1));
}

DateTime addWeeks(DateTime monday, int weeks) =>
    monday.add(Duration(days: 7 * weeks));

const weekDays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const mealSlots = ['breakfast', 'lunch', 'dinner'];

String slotKey(String week, String day, String slot) => '$week|$day|$slot';

({String week, String day, String slot})? parseSlotKey(String key) {
  final parts = key.split('|');
  if (parts.length != 3) return null;
  return (week: parts[0], day: parts[1], slot: parts[2]);
}
