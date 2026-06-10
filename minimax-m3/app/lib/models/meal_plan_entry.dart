enum MealSlot { breakfast, lunch, dinner }

extension MealSlotExt on MealSlot {
  String get id {
    switch (this) {
      case MealSlot.breakfast:
        return 'breakfast';
      case MealSlot.lunch:
        return 'lunch';
      case MealSlot.dinner:
        return 'dinner';
    }
  }

  static MealSlot fromId(String id) {
    switch (id) {
      case 'breakfast':
        return MealSlot.breakfast;
      case 'lunch':
        return MealSlot.lunch;
      default:
        return MealSlot.dinner;
    }
  }
}

class MealPlanEntry {
  /// ISO-8601 week key (e.g. "2026-W23").
  final String weekKey;

  /// 1..7 (Mon..Sun)
  final int weekday;
  final MealSlot slot;
  final String recipeId;

  const MealPlanEntry({
    required this.weekKey,
    required this.weekday,
    required this.slot,
    required this.recipeId,
  });

  String get slotKey =>
      '${_weekdayKey(weekday)}.${slot.id}'; // "mon.dinner"

  Map<String, dynamic> toJson() => {
        'week_key': weekKey,
        'weekday': weekday,
        'slot': slot.id,
        'recipe_id': recipeId,
      };

  factory MealPlanEntry.fromJson(Map<String, dynamic> json) => MealPlanEntry(
        weekKey: json['week_key'] as String,
        weekday: (json['weekday'] as num).toInt(),
        slot: MealSlotExt.fromId(json['slot'] as String),
        recipeId: json['recipe_id'] as String,
      );
}

String _weekdayKey(int weekday) {
  const names = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  if (weekday < 1 || weekday > 7) return 'mon';
  return names[weekday - 1];
}

/// Produces the ISO-week key for [date] in the form "YYYY-WNN".
String isoWeekKey(DateTime date) {
  // ISO-week computation (Mon = day 1)
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final year = thursday.year;
  final firstThursday = DateTime(year, 1, 4);
  final firstWeekStart =
      firstThursday.subtract(Duration(days: firstThursday.weekday - 1));
  final week =
      1 + ((thursday.difference(firstWeekStart).inDays) / 7).floor();
  return '$year-W${week.toString().padLeft(2, '0')}';
}

DateTime mondayOf(DateTime date) {
  return DateTime(date.year, date.month, date.day - (date.weekday - 1));
}
