import 'package:flutter/foundation.dart';

import '../../domain/plan/meal_plan.dart';
import '../storage/storage.dart';

/// The weekly grid (Mon–Sun × breakfast/lunch/dinner). Assign, clear and move
/// slots; everything persists per week.
class MealPlanController extends ChangeNotifier {
  MealPlanController._(this._box) {
    _load();
  }

  static Future<MealPlanController> open(AppStorage storage) async {
    return MealPlanController._(await storage.records.open(Boxes.mealPlan));
  }

  final RecordBox _box;
  MealPlan _plan = MealPlan();

  MealPlan get plan => _plan;

  void _load() {
    final weeks = <String, Map<String, String>>{};
    for (final entry in _box.entries) {
      final json = _box.getJson(entry.key);
      if (json == null) continue;
      try {
        WeekKey.parse(entry.key);
        weeks[entry.key] = {for (final e in json.entries) e.key: e.value.toString()};
      } catch (_) {
        // Ignore records that are not a week.
      }
    }
    _plan = MealPlan(weeks);
  }

  String? recipeAt(WeekKey week, String slot) => _plan.recipeAt(week, slot);

  Future<void> assign(WeekKey week, String slot, String recipeId) => _apply(_plan.assign(week, slot, recipeId), [week]);

  Future<void> clear(WeekKey week, String slot) => _apply(_plan.clear(week, slot), [week]);

  /// Drag and drop between slots (also across weeks); occupied targets swap.
  Future<void> move(WeekKey fromWeek, String from, WeekKey toWeek, String to) =>
      _apply(_plan.move(fromWeek, from, toWeek, to), [fromWeek, toWeek]);

  Future<void> clearWeek(WeekKey week) async {
    var next = _plan;
    for (final slot in _plan.slotsOf(week).keys.toList()) {
      next = next.clear(week, slot);
    }
    await _apply(next, [week]);
  }

  Future<void> _apply(MealPlan next, Iterable<WeekKey> touched) async {
    _plan = next;
    notifyListeners();
    for (final week in touched.toSet()) {
      final slots = next.slotsOf(week);
      if (slots.isEmpty) {
        await _box.delete(week.toString());
      } else {
        await _box.putJson(week.toString(), <String, dynamic>{...slots});
      }
    }
  }

  /// Restores from a backup. Merge fills empty slots only.
  Future<void> restore(MealPlan incoming, {required bool replace}) async {
    final next = replace ? incoming : _plan.mergedWith(incoming);
    if (replace) await _box.clear();
    _plan = next;
    notifyListeners();
    for (final entry in next.weeks.entries) {
      await _box.putJson(entry.key, <String, dynamic>{...entry.value});
    }
  }

  Future<void> clearAll() async {
    _plan = MealPlan();
    await _box.clear();
    notifyListeners();
  }
}
