/// The three meals of a day.
enum MealSlot {
  breakfast('breakfast', 'mon.breakfast'),
  lunch('lunch', 'mon.lunch'),
  dinner('dinner', 'mon.dinner');

  const MealSlot(this.id, this.slotPrefix);

  final String id;

  /// Key prefix used inside a week map (`mon.` + slot id).
  final String slotPrefix;

  static MealSlot? fromId(String id) {
    for (final slot in MealSlot.values) {
      if (slot.id == id) return slot;
    }
    return null;
  }
}

/// The days of a week, Monday first.
abstract final class Weekday {
  const Weekday._();

  static const List<String> ids = <String>[
    'mon',
    'tue',
    'wed',
    'thu',
    'fri',
    'sat',
    'sun',
  ];

  static String key(MealSlot slot, String weekdayId) => '$weekdayId.${slot.id}';
}

/// A week of meal assignments.
///
/// Keyed by ISO week (`2026-W16`), then by `weekday.slot` (`mon.dinner`).
class MealPlan {
  const MealPlan(this.weeks);

  factory MealPlan.empty() => const MealPlan(<String, Map<String, String>>{});

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    final weeks = <String, Map<String, String>>{};
    // The backup format stores the week map directly:
    //   { "2026-W16": { "mon.dinner": "recipe-id" } }
    // A nested `{ "weeks": … }` envelope is also accepted.
    final raw = json.containsKey('weeks')
        ? (json['weeks'] as Map<String, dynamic>? ?? <String, dynamic>{})
        : json;
    raw.forEach((weekKey, slots) {
      if (slots is Map) {
        weeks[weekKey] = slots.map(
          (slot, recipeId) => MapEntry('$slot', '$recipeId'),
        );
      }
    });
    return MealPlan(weeks);
  }

  final Map<String, Map<String, String>> weeks;

  Map<String, String> week(String weekKey) =>
      weeks[weekKey] ?? const <String, String>{};

  String? recipeFor(String weekKey, String slotKey) => week(weekKey)[slotKey];

  void assign(String weekKey, String slotKey, String recipeId) {
    final bucket = weeks.putIfAbsent(weekKey, () => <String, String>{});
    if (recipeId.isEmpty) {
      bucket.remove(slotKey);
      if (bucket.isEmpty) weeks.remove(weekKey);
    } else {
      bucket[slotKey] = recipeId;
    }
  }

  void clearSlot(String weekKey, String slotKey) {
    final bucket = weeks[weekKey];
    if (bucket == null) return;
    bucket.remove(slotKey);
    if (bucket.isEmpty) weeks.remove(weekKey);
  }

  MealPlan copyWith(Map<String, Map<String, String>> weeks) =>
      MealPlan(<String, Map<String, String>>{
        for (final entry in weeks.entries)
          entry.key: Map<String, String>.from(entry.value),
      });

  Map<String, dynamic> toJson() => <String, dynamic>{
        for (final entry in weeks.entries)
          entry.key: Map<String, String>.from(entry.value),
      };

  /// ISO-8601 week key, e.g. `2026-W16`.
  static String weekKeyFor(DateTime date) {
    final thursday = DateTime(date.year, date.month, date.day)
        .add(Duration(days: 4 - _isoWeekday(DateTime(date.year, date.month, date.day))));
    final year = thursday.year;
    final firstThursday = DateTime(year, 1, 4)
        .add(Duration(days: 4 - _isoWeekday(DateTime(year, 1, 4))));
    final week = 1 + ((thursday.difference(firstThursday).inDays) / 7).floor();
    return '$year-W${week.toString().padLeft(2, '0')}';
  }

  /// The Monday of the week containing [date].
  static DateTime mondayOf(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: _isoWeekday(day) - 1));
  }

  static int _isoWeekday(DateTime date) => date.weekday;

  /// Every week key from the week of [from] forward, [count] weeks long.
  static List<String> weekKeysFrom(DateTime from, int count) {
    final monday = mondayOf(from);
    return <String>[
      for (var i = 0; i < count; i++)
        weekKeyFor(monday.add(Duration(days: 7 * i))),
    ];
  }
}
