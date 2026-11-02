import 'package:flutter/foundation.dart';

import '../models/meal_plan.dart';
import '../models/recipe.dart';
import 'local_store.dart';

/// The weekly meal plan.
///
/// Monday to Sunday, three slots a day. The user assigns recipes by hand —
/// there is no auto-planning and no nutrition rollup in v1.
class MealPlanController extends ChangeNotifier {
  MealPlanController(this._store) {
    _plan = MealPlan.fromJson(_store.readMap(StoreKeys.mealPlan));
  }

  final KeyValueStore _store;
  late MealPlan _plan;

  MealPlan get plan => _plan;

  Map<String, String> week(String weekKey) => _plan.week(weekKey);

  String? recipeFor(String weekKey, String slotKey) =>
      _plan.recipeFor(weekKey, slotKey);

  /// Assigns a recipe to a slot. An empty [recipeId] clears the slot.
  void assign(String weekKey, String slotKey, String recipeId) {
    final next = _plan.copyWith(_plan.weeks);
    next.assign(weekKey, slotKey, recipeId);
    _plan = next;
    notifyListeners();
    _persist();
  }

  void clear(String weekKey, String slotKey) {
    final next = _plan.copyWith(_plan.weeks);
    next.clearSlot(weekKey, slotKey);
    _plan = next;
    notifyListeners();
    _persist();
  }

  /// Moves a recipe from one slot to another — used by drag and drop.
  void move(
    String fromWeek,
    String fromSlot,
    String toWeek,
    String toSlot,
  ) {
    final recipeId = _plan.recipeFor(fromWeek, fromSlot);
    if (recipeId == null) return;
    final next = _plan.copyWith(_plan.weeks);
    next.clearSlot(fromWeek, fromSlot);
    next.assign(toWeek, toSlot, recipeId);
    _plan = next;
    notifyListeners();
    _persist();
  }

  /// Every recipe id used in the plan, without duplicates.
  List<String> get allRecipeIds {
    final ids = <String>{};
    for (final slots in _plan.weeks.values) {
      ids.addAll(slots.values);
    }
    return ids.toList(growable: false);
  }

  /// The distinct recipes used in the plan, resolved against the corpus.
  List<Recipe> resolve(List<Recipe> universe) {
    final byId = <String, Recipe>{for (final recipe in universe) recipe.id: recipe};
    final seen = <String>{};
    final result = <Recipe>[];
    for (final id in allRecipeIds) {
      if (!seen.add(id)) continue;
      final recipe = byId[id];
      if (recipe != null) result.add(recipe);
    }
    return result;
  }

  void replaceAll(MealPlan plan) {
    _plan = plan;
    notifyListeners();
    _persist();
  }

  void _persist() => _store.writeMap(StoreKeys.mealPlan, _plan.toJson());
}
