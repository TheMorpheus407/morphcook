/// ISO-8601 week helpers for the meal plan (`2026-W16`) and history.
class IsoWeek {
  const IsoWeek(this.year, this.week);

  factory IsoWeek.of(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    // Thursday of this week decides the ISO year.
    final thursday = d.add(Duration(days: 4 - d.weekday));
    final jan1 = DateTime.utc(thursday.year, 1, 1);
    final week = 1 + thursday.difference(jan1).inDays ~/ 7;
    return IsoWeek(thursday.year, week);
  }

  factory IsoWeek.parse(String key) {
    final m = RegExp(r'^(\d{4})-W(\d{2})$').firstMatch(key);
    if (m == null) throw FormatException('bad week key', key);
    return IsoWeek(int.parse(m.group(1)!), int.parse(m.group(2)!));
  }

  final int year;
  final int week;

  String get key => '$year-W${week.toString().padLeft(2, '0')}';

  /// Monday of this week (local date, midnight).
  DateTime get monday {
    final jan4 = DateTime(year, 1, 4);
    final week1Monday = jan4.subtract(Duration(days: jan4.weekday - 1));
    return DateTime(week1Monday.year, week1Monday.month, week1Monday.day + (week - 1) * 7);
  }

  IsoWeek shift(int weeks) {
    final m = monday;
    return IsoWeek.of(DateTime(m.year, m.month, m.day + 7 * weeks + 3));
  }

  @override
  bool operator ==(Object other) => other is IsoWeek && other.year == year && other.week == week;

  @override
  int get hashCode => Object.hash(year, week);

  @override
  String toString() => key;
}

const weekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const mealSlots = ['breakfast', 'lunch', 'dinner'];

String slotKey(int weekdayIndex, String meal) => '${weekdayKeys[weekdayIndex]}.$meal';

String monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
