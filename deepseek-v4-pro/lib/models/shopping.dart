import 'dart:convert';

/// A single shopping list item (pre-aggregation unit).
class ShoppingEntry {
  const ShoppingEntry({
    required this.ingredientId,
    required this.amount,
    required this.unit,
    this.checked = false,
    required this.addedAt,
  });

  final String ingredientId;
  final double amount;
  final String unit;
  final bool checked;
  final DateTime addedAt;

  Map<String, dynamic> toJson() => {
        'ingredient_id': ingredientId,
        'amount': amount,
        'unit': unit,
        'checked': checked,
        'added_at': addedAt.toIso8601String(),
      };

  factory ShoppingEntry.fromJson(Map<String, dynamic> json) => ShoppingEntry(
        ingredientId: json['ingredient_id'] as String,
        amount: (json['amount'] as num).toDouble(),
        unit: json['unit'] as String,
        checked: json['checked'] as bool? ?? false,
        addedAt:
            DateTime.parse(json['added_at'] as String? ?? '1970-01-01T00:00:00Z'),
      );

  String encode() => jsonEncode(toJson());
  static ShoppingEntry decode(String raw) =>
      ShoppingEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

class HistoryEntry {
  const HistoryEntry({required this.recipeId, required this.cookedAt});

  final String recipeId;
  final DateTime cookedAt;

  Map<String, dynamic> toJson() => {
        'recipe_id': recipeId,
        'cooked_at': cookedAt.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        recipeId: json['recipe_id'] as String,
        cookedAt: DateTime.parse(json['cooked_at'] as String),
      );

  String encode() => jsonEncode(toJson());
  static HistoryEntry decode(String raw) =>
      HistoryEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// ISO week helpers for the meal planner.
class IsoWeek {
  IsoWeek._();

  /// "2026-W33" for [date].
  static String of(DateTime date) {
    final thursday = monday(date).add(const Duration(days: 3));
    final week = weekNumber(date);
    return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
  }

  /// Monday of the ISO week containing [date].
  static DateTime monday(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    final iso = d.weekday - 1; // mon=0 … sun=6
    return d.subtract(Duration(days: iso));
  }

  /// Monday of the ISO week identified by [weekId] ("2026-W33").
  static DateTime mondayOf(String weekId) {
    final parts = weekId.split('-W');
    final year = int.parse(parts[0]);
    final week = int.parse(parts[1]);
    // ISO guarantees week 1 always contains January 4th.
    final mon1 = monday(DateTime.utc(year, 1, 4));
    return mon1.add(Duration(days: (week - 1) * 7));
  }

  static String next(String weekId) => of(mondayOf(weekId).add(const Duration(days: 7)));
  static String previous(String weekId) =>
      of(mondayOf(weekId).subtract(const Duration(days: 7)));

  /// ISO 8601 week number (1–53), 1-based day-of-year formula.
  static int weekNumber(DateTime date) {
    final thursday = monday(date).add(const Duration(days: 3));
    final jan1 = DateTime.utc(thursday.year, 1, 1);
    final doy = thursday.difference(jan1).inDays + 1; // 1-based
    return ((doy + 10 - 4) ~/ 7); // Thursday (iso weekday 4)
  }
}

/// Meal plan slot keys: weekday × meal.
const mealPlanSlots = [
  'mon.breakfast', 'mon.lunch', 'mon.dinner',
  'tue.breakfast', 'tue.lunch', 'tue.dinner',
  'wed.breakfast', 'wed.lunch', 'wed.dinner',
  'thu.breakfast', 'thu.lunch', 'thu.dinner',
  'fri.breakfast', 'fri.lunch', 'fri.dinner',
  'sat.breakfast', 'sat.lunch', 'sat.dinner',
  'sun.breakfast', 'sun.lunch', 'sun.dinner',
];

const mealPlanWeekdays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const mealPlanMeals = ['breakfast', 'lunch', 'dinner'];
