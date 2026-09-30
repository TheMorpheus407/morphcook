/// Monday to Sunday, in grid order.
const List<String> planDays = <String>['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/// The three slots of a day.
const List<String> planMeals = <String>['breakfast', 'lunch', 'dinner'];

/// `mon.dinner`
String slotKey(String day, String meal) => '$day.$meal';

/// An ISO 8601 week such as `2026-W16`.
class WeekKey implements Comparable<WeekKey> {
  const WeekKey(this.year, this.week);

  final int year;
  final int week;

  /// The ISO week that contains [date].
  factory WeekKey.fromDate(DateTime date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    // The Thursday of a week decides its ISO year and number.
    final thursday = day.add(Duration(days: 4 - day.weekday));
    final dayOfYear = thursday.difference(DateTime.utc(thursday.year, 1, 1)).inDays + 1;
    return WeekKey(thursday.year, (dayOfYear - 1) ~/ 7 + 1);
  }

  factory WeekKey.parse(String text) {
    final match = RegExp(r'^(\d{4})-W(\d{2})$').firstMatch(text);
    if (match == null) throw FormatException('Not a week key: $text');
    return WeekKey(int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  /// Monday (local midnight) of this week.
  DateTime get monday {
    final jan4 = DateTime.utc(year, 1, 4);
    final firstMonday = jan4.subtract(Duration(days: jan4.weekday - 1));
    final monday = firstMonday.add(Duration(days: (week - 1) * 7));
    return DateTime(monday.year, monday.month, monday.day);
  }

  /// Calendar date of [day] (`mon` … `sun`) within this week.
  DateTime dateOf(String day) {
    final m = monday;
    return DateTime(m.year, m.month, m.day + planDays.indexOf(day));
  }

  WeekKey plusWeeks(int weeks) {
    final m = monday;
    return WeekKey.fromDate(DateTime(m.year, m.month, m.day + 7 * weeks));
  }

  @override
  int compareTo(WeekKey other) => year != other.year ? year.compareTo(other.year) : week.compareTo(other.week);

  @override
  bool operator ==(Object other) => other is WeekKey && other.year == year && other.week == week;

  @override
  int get hashCode => Object.hash(year, week);

  @override
  String toString() => '$year-W${week.toString().padLeft(2, '0')}';
}

/// The weekly grid: week key -> slot key -> recipe id.
///
/// Immutable; every change returns a new plan so it can be diffed and tested.
class MealPlan {
  MealPlan([Map<String, Map<String, String>>? weeks])
    : _weeks = {
        for (final e in (weeks ?? const <String, Map<String, String>>{}).entries)
          if (e.value.isNotEmpty) e.key: Map<String, String>.unmodifiable(e.value),
      };

  final Map<String, Map<String, String>> _weeks;

  Map<String, Map<String, String>> get weeks => _weeks;
  bool get isEmpty => _weeks.isEmpty;

  Map<String, String> slotsOf(WeekKey week) => _weeks[week.toString()] ?? const <String, String>{};

  String? recipeAt(WeekKey week, String slot) => slotsOf(week)[slot];

  MealPlan _replaceWeek(WeekKey week, Map<String, String> slots) {
    final next = {for (final e in _weeks.entries) e.key: Map<String, String>.of(e.value)};
    if (slots.isEmpty) {
      next.remove(week.toString());
    } else {
      next[week.toString()] = slots;
    }
    return MealPlan(next);
  }

  MealPlan assign(WeekKey week, String slot, String recipeId) {
    return _replaceWeek(week, {...slotsOf(week), slot: recipeId});
  }

  MealPlan clear(WeekKey week, String slot) {
    final slots = Map<String, String>.of(slotsOf(week))..remove(slot);
    return _replaceWeek(week, slots);
  }

  /// Drag and drop: moves [from] onto [to]; an occupied target swaps places.
  MealPlan move(WeekKey fromWeek, String from, WeekKey toWeek, String to) {
    final moving = recipeAt(fromWeek, from);
    if (moving == null || (fromWeek == toWeek && from == to)) return this;
    final displaced = recipeAt(toWeek, to);
    var next = assign(toWeek, to, moving);
    next = displaced == null ? next.clear(fromWeek, from) : next.assign(fromWeek, from, displaced);
    return next;
  }

  /// Recipe ids of a week in reading order (Monday breakfast first), keeping
  /// repeats so that cooking a dish twice buys it twice.
  List<String> recipeIdsOf(WeekKey week) {
    final slots = slotsOf(week);
    return [
      for (final day in planDays)
        for (final meal in planMeals)
          if (slots[slotKey(day, meal)] != null) slots[slotKey(day, meal)]!,
    ];
  }

  /// Additive merge: slots that are already taken keep their recipe.
  MealPlan mergedWith(MealPlan other) {
    final next = {for (final e in _weeks.entries) e.key: Map<String, String>.of(e.value)};
    for (final e in other._weeks.entries) {
      final target = next.putIfAbsent(e.key, () => <String, String>{});
      for (final slot in e.value.entries) {
        target.putIfAbsent(slot.key, () => slot.value);
      }
    }
    return MealPlan(next);
  }

  Map<String, dynamic> toJson() => {
    for (final key in (_weeks.keys.toList()..sort()))
      key: {for (final slot in _weeks[key]!.entries) slot.key: slot.value},
  };

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    return MealPlan({
      for (final e in json.entries)
        e.key: {for (final s in (e.value as Map).entries) s.key.toString(): s.value.toString()},
    });
  }
}
