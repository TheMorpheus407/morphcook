/// Weekly meal plan: ISO week id → slot id → recipe id.
/// Slots are `mon.breakfast` … `sun.dinner`.
library;

const List<String> planDays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const List<String> planMeals = ['breakfast', 'lunch', 'dinner'];

String slotId(String day, String meal) => '$day.$meal';

/// ISO-8601 week id, e.g. `2026-W16`. Computed on UTC dates so DST shifts
/// can't truncate the day count; the ISO year comes from the week's Thursday.
String weekIdFor(DateTime date) {
  final d = DateTime.utc(date.year, date.month, date.day);
  final monday = d.subtract(Duration(days: d.weekday - 1));
  final thursday = monday.add(const Duration(days: 3));
  final isoYear = thursday.year;
  final dayOfYear = thursday.difference(DateTime.utc(isoYear, 1, 1)).inDays + 1;
  final week = ((dayOfYear - thursday.weekday + 10) / 7).floor();
  return '$isoYear-W${week.toString().padLeft(2, '0')}';
}

/// The monday (local midnight) of the ISO week [weekId] belongs to.
DateTime mondayOfWeek(String weekId) {
  final match = RegExp(r'^(\d{4})-W(\d{2})$').firstMatch(weekId);
  if (match == null) {
    throw FormatException('invalid week id: $weekId');
  }
  final year = int.parse(match.group(1)!);
  final week = int.parse(match.group(2)!);
  // January 4th is always in ISO week 1. Work in UTC (no DST), then return
  // the plain local calendar date.
  final jan4 = DateTime.utc(year, 1, 4);
  final week1Monday = jan4.subtract(Duration(days: jan4.weekday - 1));
  final monday = week1Monday.add(Duration(days: (week - 1) * 7));
  return DateTime(monday.year, monday.month, monday.day);
}

List<String> allSlotIds() => [
      for (final meal in planMeals)
        for (final day in planDays) slotId(day, meal)
    ];

/// The meal-plan store shape: weekId → { slotId → recipeId }.
typedef MealPlanMap = Map<String, Map<String, String>>;
