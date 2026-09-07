import '../../core/week.dart';

const List<String> mealsOfDay = ['breakfast', 'lunch', 'dinner'];

/// Weekly grid Mon–Sun × breakfast/lunch/dinner, keyed like the backup
/// format: `{"2026-W16": {"mon.dinner": "recipe-id"}}`.
class MealPlan {
  MealPlan([Map<String, Map<String, String>>? weeks]) : weeks = weeks ?? {};

  final Map<String, Map<String, String>> weeks;

  String? recipeAt(String weekKey, String slot) => weeks[weekKey]?[slot];

  void assign(String weekKey, String slot, String recipeId) {
    weeks.putIfAbsent(weekKey, () => {})[slot] = recipeId;
  }

  void clear(String weekKey, String slot) {
    final w = weeks[weekKey];
    if (w == null) return;
    w.remove(slot);
    if (w.isEmpty) weeks.remove(weekKey);
  }

  /// Moves (or swaps) between slots, possibly across weeks.
  void move(String fromWeek, String fromSlot, String toWeek, String toSlot) {
    final moving = recipeAt(fromWeek, fromSlot);
    if (moving == null) return;
    final target = recipeAt(toWeek, toSlot);
    clear(fromWeek, fromSlot);
    assign(toWeek, toSlot, moving);
    if (target != null) assign(fromWeek, fromSlot, target);
  }

  Map<String, String> week(String weekKey) => Map.unmodifiable(weeks[weekKey] ?? const {});

  List<String> recipeIdsInWeek(String weekKey) => (weeks[weekKey] ?? const {}).values.toList();

  bool get isEmpty => weeks.isEmpty;

  Map<String, dynamic> toJson() => {
        for (final e in weeks.entries) e.key: Map<String, String>.from(e.value),
      };

  factory MealPlan.fromJson(Map<String, dynamic>? j) => MealPlan({
        if (j != null)
          for (final e in j.entries)
            if (e.value is Map)
              e.key: (e.value as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
      });

  static List<String> slotsOfWeek() => [
        for (var d = 1; d <= 7; d++)
          for (final m in mealsOfDay) slotKey(d, m),
      ];
}
