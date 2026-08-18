/// Hand-rolled date helpers (no intl dependency): ISO week keys, bilingual
/// weekday / month names, week and date-line formatting.
class DateFmt {
  static const _weekdaysEn = [
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
  ];
  static const _weekdaysDe = [
    'montag', 'dienstag', 'mittwoch', 'donnerstag', 'freitag', 'samstag', 'sonntag'
  ];
  static const _weekdaysShortEn = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  static const _weekdaysShortDe = ['mo', 'di', 'mi', 'do', 'fr', 'sa', 'so'];
  static const _monthsEn = [
    'january', 'february', 'march', 'april', 'may', 'june', 'july',
    'august', 'september', 'october', 'november', 'december'
  ];
  static const _monthsDe = [
    'januar', 'februar', 'märz', 'april', 'mai', 'juni', 'juli',
    'august', 'september', 'oktober', 'november', 'dezember'
  ];
  static const _monthsShortEn = [
    'jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'
  ];
  static const _monthsShortDe = [
    'jan', 'feb', 'mär', 'apr', 'mai', 'jun', 'jul', 'aug', 'sep', 'okt', 'nov', 'dez'
  ];

  static String weekday(int weekdayIndex, String lang) {
    // DateTime.weekday: 1 = monday … 7 = sunday.
    final i = weekdayIndex - 1;
    return lang == 'de' ? _weekdaysDe[i] : _weekdaysEn[i];
  }

  static String weekdayShort(int weekdayIndex, String lang) {
    final i = weekdayIndex - 1;
    return lang == 'de' ? _weekdaysShortDe[i] : _weekdaysShortEn[i];
  }

  static String weekdayShortFromSlot(String slotDay, String lang) {
    final i = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'].indexOf(slotDay);
    return lang == 'de' ? _weekdaysShortDe[i] : _weekdaysShortEn[i];
  }

  static String month(int month, String lang) =>
      lang == 'de' ? _monthsDe[month - 1] : _monthsEn[month - 1];

  static String monthShort(int month, String lang) =>
      lang == 'de' ? _monthsShortDe[month - 1] : _monthsShortEn[month - 1];

  /// Newspaper date line: `saturday, august 15, 2026` / `samstag, 15. august 2026`.
  static String dateLine(DateTime date, String lang) {
    if (lang == 'de') {
      return '${weekday(date.weekday, 'de')}, ${date.day}. ${month(date.month, 'de')} ${date.year}';
    }
    return '${weekday(date.weekday, 'en')}, ${month(date.month, 'en')} ${date.day}, ${date.year}';
  }

  /// Short date for history rows: `aug 15` / `15. aug`.
  static String shortDate(DateTime date, String lang) => lang == 'de'
      ? '${date.day}. ${monthShort(date.month, 'de')}.'
      : '${monthShort(date.month, 'en')} ${date.day}';

  static String dateTime(DateTime date, String lang) =>
      '${shortDate(date, lang)} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

/// ISO-8601 week math (weeks start monday; week 1 contains the first
/// thursday of the year).
class IsoWeek {
  /// `2026-W33`.
  static String keyOf(DateTime date) {
    final thursday = date.add(Duration(days: DateTime.thursday - date.weekday));
    final year = thursday.year;
    final jan1 = DateTime(year, 1, 1);
    final firstThursday =
        jan1.add(Duration(days: (DateTime.thursday - jan1.weekday + 7) % 7));
    final week = ((thursday.difference(firstThursday).inDays) / 7).floor() + 1;
    return '$year-W${week.toString().padLeft(2, '0')}';
  }

  /// The monday of a week key.
  static DateTime mondayOf(String weekKey) {
    final parts = weekKey.split('-W');
    final year = int.parse(parts[0]);
    final week = int.parse(parts[1]);
    final jan1 = DateTime(year, 1, 1);
    final firstThursday =
        jan1.add(Duration(days: (DateTime.thursday - jan1.weekday + 7) % 7));
    final firstMonday = firstThursday.subtract(const Duration(days: 3));
    return firstMonday.add(Duration(days: 7 * (week - 1)));
  }

  /// Label like `W33 · aug 10 – aug 16`.
  static String label(String weekKey, String lang) {
    final monday = mondayOf(weekKey);
    final sunday = monday.add(const Duration(days: 6));
    final weekNumber = weekKey.split('-W')[1];
    if (lang == 'de') {
      return 'KW$weekNumber · ${monday.day}.–${sunday.day}. ${DateFmt.monthShort(sunday.month, 'de')}.';
    }
    return 'W$weekNumber · ${DateFmt.monthShort(monday.month, 'en')} ${monday.day} – '
        '${DateFmt.monthShort(sunday.month, 'en')} ${sunday.day}';
  }

  /// The next / previous week keys around [weekKey].
  static String next(String weekKey) => shift(weekKey, 1);

  static String previous(String weekKey) => shift(weekKey, -1);

  static String shift(String weekKey, int weeks) =>
      keyOf(mondayOf(weekKey).add(Duration(days: 7 * weeks)));

  static String current() => keyOf(DateTime.now());
}
