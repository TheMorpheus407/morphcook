/// Meal-plan model: weekly grid Mon–Sun × breakfast/lunch/dinner.
/// Keys are ISO week ids ("2026-W34"); slot ids "mon.dinner".
library;

class MealSlot {
  final String day; // mon..sun
  final String meal; // breakfast | lunch | dinner
  const MealSlot(this.day, this.meal);

  String get id => '$day.$meal';
}

const mealDays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const mealKinds = ['breakfast', 'lunch', 'dinner'];

/// ISO-8601 week key, e.g. 2026-W34. Computed in UTC so DST transitions
/// can't skew the day difference.
String weekKeyOf(DateTime date) {
  final d = DateTime.utc(date.year, date.month, date.day);
  // ISO week: Thursday of the current week defines the year.
  final thursday = d.add(Duration(days: DateTime.thursday - d.weekday));
  final firstThursday = DateTime.utc(thursday.year, 1, 1);
  final week1Thursday = firstThursday
      .add(Duration(days: (DateTime.thursday - firstThursday.weekday) % 7));
  final week = thursday.difference(week1Thursday).inDays ~/ 7 + 1;
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

DateTime mondayOf(DateTime date) =>
    date.subtract(Duration(days: date.weekday - 1));

class MealPlan {
  /// weekKey -> (slotId -> recipeId)
  final Map<String, Map<String, String>> weeks;

  const MealPlan({this.weeks = const {}});

  Map<String, String> week(String weekKey) => weeks[weekKey] ?? const {};

  String? slot(String weekKey, String slotId) => week(weekKey)[slotId];

  MealPlan assign(String weekKey, String slotId, String? recipeId) {
    final next = <String, Map<String, String>>{
      for (final e in weeks.entries) e.key: Map.of(e.value),
    };
    final w = Map<String, String>.of(next[weekKey] ?? {});
    if (recipeId == null) {
      w.remove(slotId);
    } else {
      w[slotId] = recipeId;
    }
    next[weekKey] = w;
    return MealPlan(weeks: next);
  }

  /// All planned recipe ids of a week, in day×meal order (duplicates kept).
  List<String> recipesOfWeek(String weekKey) {
    final out = <String>[];
    for (final day in mealDays) {
      for (final meal in mealKinds) {
        final id = week(weekKey)['$day.$meal'];
        if (id != null) out.add(id);
      }
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
        for (final e in weeks.entries)
          e.key: e.value.map((k, v) => MapEntry(k, v)),
      };

  static MealPlan fromJson(Map<String, dynamic> json) => MealPlan(
        weeks: json.map((k, v) => MapEntry(
            k,
            (v as Map<String, dynamic>)
                .map((sk, sv) => MapEntry(sk, sv.toString())))),
      );
}
