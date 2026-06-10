import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// ISO-week helpers: a meal plan is keyed by `YYYY-Www` and slot `day.meal`.
class WeekId {
  const WeekId(this.year, this.week);
  final int year;
  final int week;

  String get key => '$year-W${week.toString().padLeft(2, '0')}';

  static WeekId of(DateTime date) {
    // ISO-8601 week number.
    final thursday = date.add(Duration(days: 4 - (date.weekday)));
    final firstDay = DateTime(thursday.year, 1, 1);
    final week = (((thursday.difference(firstDay).inDays) / 7).floor()) + 1;
    return WeekId(thursday.year, week);
  }

  /// Monday of this week (uses the supplied reference date's week math).
  WeekId addWeeks(int delta) {
    // Reconstruct an approximate date then recompute (safe across year edges).
    final approx = DateTime(year, 1, 1).add(Duration(days: (week - 1 + delta) * 7));
    return WeekId.of(approx);
  }

  @override
  bool operator ==(Object other) =>
      other is WeekId && other.year == year && other.week == week;
  @override
  int get hashCode => Object.hash(year, week);
}

const List<String> kDays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const List<String> kMeals = ['breakfast', 'lunch', 'dinner'];

/// Weekly meal grid (Mon–Sun × breakfast/lunch/dinner). No auto-planning.
class MealPlanService extends ChangeNotifier {
  MealPlanService(this._box);
  final Box _box; // key: weekKey, value: Map<'day.meal', recipeId>

  Map<String, String> week(String weekKey) {
    final raw = _box.get(weekKey) as Map?;
    if (raw == null) return {};
    return raw.map((k, v) => MapEntry(k as String, v as String));
  }

  String? slot(String weekKey, String day, String meal) =>
      week(weekKey)['$day.$meal'];

  Future<void> assign(String weekKey, String day, String meal, String recipeId) async {
    final w = week(weekKey)..['$day.$meal'] = recipeId;
    await _box.put(weekKey, w);
    notifyListeners();
  }

  Future<void> clearSlot(String weekKey, String day, String meal) async {
    final w = week(weekKey)..remove('$day.$meal');
    if (w.isEmpty) {
      await _box.delete(weekKey);
    } else {
      await _box.put(weekKey, w);
    }
    notifyListeners();
  }

  /// Drag-drop: move a recipe from one slot to another (swaps if target full).
  Future<void> move(String weekKey, String fromSlot, String toSlot) async {
    final w = week(weekKey);
    final moving = w[fromSlot];
    if (moving == null) return;
    final existing = w[toSlot];
    w[toSlot] = moving;
    if (existing != null) {
      w[fromSlot] = existing;
    } else {
      w.remove(fromSlot);
    }
    await _box.put(weekKey, w);
    notifyListeners();
  }

  /// All recipe ids assigned in a week (for shopping-list export).
  List<String> recipeIdsForWeek(String weekKey) => week(weekKey).values.toList();

  Map<String, dynamic> exportPlan() {
    final out = <String, dynamic>{};
    for (final key in _box.keys) {
      out[key as String] = week(key);
    }
    return out;
  }

  Future<void> importPlan(Map<String, dynamic> raw, {bool replace = false}) async {
    if (replace) await _box.clear();
    for (final entry in raw.entries) {
      await _box.put(entry.key, Map<String, String>.from(entry.value as Map));
    }
    notifyListeners();
  }
}
