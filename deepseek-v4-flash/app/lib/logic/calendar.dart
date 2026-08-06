import '../models/models.dart';

/// Calendar week helpers for the meal-plan "week album".
class CalendarWeek {
  final DateTime start; // Monday 00:00 local
  final int year;
  final int weekNumber;

  CalendarWeek({required this.year, required this.weekNumber, DateTime? start})
      : start = start ?? mondayOf(year, weekNumber);

  static const days = dayNames; // mon..sun

  /// ISO 8601 week number (Monday-based). Computed in UTC so DST hour
  /// shifts never skew the day count.
  static int isoWeek(DateTime d) {
    final utc = DateTime.utc(d.year, d.month, d.day);
    final thursday = utc.add(Duration(days: 4 - utc.weekday));
    final yearStart = DateTime.utc(thursday.year, 1, 1);
    return 1 + (thursday.difference(yearStart).inDays / 7).floor();
  }

  /// Monday of the ISO week (local midnight).
  static DateTime mondayOf(int year, int week) {
    final jan4 = DateTime.utc(year, 1, 4);
    final firstMonday = jan4.subtract(Duration(days: jan4.weekday - 1));
    final m = firstMonday.add(Duration(days: (week - 1) * 7));
    return DateTime(m.year, m.month, m.day);
  }

  static CalendarWeek of(DateTime d) {
    final utc = DateTime.utc(d.year, d.month, d.day);
    final thursday = utc.add(Duration(days: 4 - utc.weekday));
    final year = thursday.year;
    final week =
        1 + (thursday.difference(DateTime.utc(year, 1, 1)).inDays / 7).floor();
    return CalendarWeek(year: year, weekNumber: week);
  }

  /// Serialized key: "2026-W32".
  String get key => '$year-W${weekNumber.toString().padLeft(2, '0')}';

  static CalendarWeek fromKey(String key) {
    final parts = key.split('-W');
    return CalendarWeek(
        year: int.parse(parts[0]), weekNumber: int.parse(parts[1]));
  }

  DateTime dayOf(String day) {
    final idx = days.indexOf(day);
    return start.add(Duration(days: idx < 0 ? 0 : idx));
  }

  CalendarWeek get previous {
    final m = mondayOf(year, weekNumber).subtract(const Duration(days: 7));
    return of(m);
  }

  CalendarWeek get next {
    final m = mondayOf(year, weekNumber).add(const Duration(days: 7));
    return of(m);
  }

  bool get isCurrent {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return !today.isBefore(start) && today.isBefore(start.add(const Duration(days: 7)));
  }
}

String isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Slot label for a meal id in the given language.
String mealLabel(String lang, String meal) {
  const map = {
    'en': {'breakfast': 'Breakfast', 'lunch': 'Lunch', 'dinner': 'Dinner'},
    'de': {'breakfast': 'Frühstück', 'lunch': 'Mittagessen', 'dinner': 'Abendessen'},
  };
  return map[lang]?[meal] ?? meal;
}

/// Short day label for a weekday in the given language.
String dayLabel(String lang, String day) {
  const map = {
    'en': {
      'mon': 'Mon', 'tue': 'Tue', 'wed': 'Wed', 'thu': 'Thu',
      'fri': 'Fri', 'sat': 'Sat', 'sun': 'Sun',
    },
    'de': {
      'mon': 'Mo', 'tue': 'Di', 'wed': 'Mi', 'thu': 'Do',
      'fri': 'Fr', 'sat': 'Sa', 'sun': 'So',
    },
  };
  return map[lang]?[day] ?? day;
}
