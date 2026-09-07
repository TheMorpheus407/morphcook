/// ISO-week helpers. Week keys look like `2026-W16`; slot keys like `mon.dinner`.
const List<String> dayCodes = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Monday of the ISO week containing [date].
DateTime mondayOf(DateTime date) {
  final d = dateOnly(date);
  // Calendar arithmetic, not Duration: a Duration crosses DST boundaries.
  return DateTime(d.year, d.month, d.day - (d.weekday - 1));
}

/// [date] plus [days] whole calendar days (DST-safe).
DateTime addDays(DateTime date, int days) => DateTime(date.year, date.month, date.day + days);

int isoWeekNumber(DateTime date) {
  final d = dateOnly(date);
  final thursday = addDays(d, 4 - d.weekday);
  final firstThursdayYear = DateTime(thursday.year, 1, 4);
  final week1Monday = mondayOf(firstThursdayYear);
  return ((thursday.difference(week1Monday).inDays) ~/ 7) + 1;
}

int isoWeekYear(DateTime date) {
  final d = dateOnly(date);
  return addDays(d, 4 - d.weekday).year;
}

String weekKeyOf(DateTime date) =>
    '${isoWeekYear(date)}-W${isoWeekNumber(date).toString().padLeft(2, '0')}';

/// Monday date for a `YYYY-Www` key. Invalid keys return the current week's Monday.
DateTime mondayOfWeekKey(String key) {
  final m = RegExp(r'^(\d{4})-W(\d{1,2})$').firstMatch(key);
  if (m == null) return mondayOf(DateTime.now());
  final year = int.parse(m.group(1)!);
  final week = int.parse(m.group(2)!);
  final jan4 = DateTime(year, 1, 4);
  return addDays(mondayOf(jan4), (week - 1) * 7);
}

String shiftWeekKey(String key, int weeks) => weekKeyOf(addDays(mondayOfWeekKey(key), 7 * weeks));

String slotKey(int weekday, String meal) => '${dayCodes[(weekday - 1).clamp(0, 6)]}.$meal';

/// (weekday 1..7, meal) from `mon.dinner`.
(int, String)? parseSlotKey(String key) {
  final parts = key.split('.');
  if (parts.length != 2) return null;
  final idx = dayCodes.indexOf(parts[0]);
  if (idx < 0) return null;
  return (idx + 1, parts[1]);
}
