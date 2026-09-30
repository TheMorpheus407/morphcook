/// Tiny date vocabulary so the masthead and history read naturally in both
/// languages without pulling in locale data.
const _months = {
  'en': [
    'january',
    'february',
    'march',
    'april',
    'may',
    'june',
    'july',
    'august',
    'september',
    'october',
    'november',
    'december',
  ],
  'de': [
    'januar',
    'februar',
    'märz',
    'april',
    'mai',
    'juni',
    'juli',
    'august',
    'september',
    'oktober',
    'november',
    'dezember',
  ],
};
const _weekdays = {
  'en': ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'],
  'de': ['montag', 'dienstag', 'mittwoch', 'donnerstag', 'freitag', 'samstag', 'sonntag'],
};

String monthName(int month, String lang) => (_months[lang] ?? _months['en']!)[month - 1];

String shortMonth(int month, String lang) {
  final m = monthName(month, lang);
  return m.length <= 4 ? m : m.substring(0, 3);
}

String weekdayName(int weekday, String lang) => (_weekdays[lang] ?? _weekdays['en']!)[weekday - 1];

/// "tuesday, 22 september 2026" / "dienstag, 22. september 2026"
String longDate(DateTime d, String lang) => lang == 'de'
    ? '${weekdayName(d.weekday, lang)}, ${d.day}. ${monthName(d.month, lang)} ${d.year}'
    : '${weekdayName(d.weekday, lang)}, ${d.day} ${monthName(d.month, lang)} ${d.year}';

/// "14–20 sep"
String dayRange(DateTime from, DateTime to, String lang) {
  if (from.month == to.month) return '${from.day}–${to.day} ${shortMonth(to.month, lang)}';
  return '${from.day} ${shortMonth(from.month, lang)} – ${to.day} ${shortMonth(to.month, lang)}';
}

/// "22 sep"
String shortDate(DateTime d, String lang) =>
    lang == 'de' ? '${d.day}. ${shortMonth(d.month, lang)}' : '${d.day} ${shortMonth(d.month, lang)}';

/// "september 2026" from "2026-09"
String monthKeyLabel(String key, String lang) {
  final parts = key.split('-');
  return '${monthName(int.parse(parts[1]), lang)} ${parts[0]}';
}
