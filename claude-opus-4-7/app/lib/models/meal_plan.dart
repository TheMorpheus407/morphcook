import 'package:flutter/foundation.dart';

enum MealSlot { breakfast, lunch, dinner }

String mealSlotKey(MealSlot s) => s.name;
MealSlot mealSlotFromKey(String k) =>
    MealSlot.values.firstWhere((m) => m.name == k, orElse: () => MealSlot.dinner);

/// 24/7 ISO week key, e.g. "2026-W21".
String isoWeekKey(DateTime d) {
  final thursday = d.add(Duration(days: 4 - ((d.weekday + 6) % 7 + 1)));
  final firstThursday =
      DateTime(thursday.year, 1, 1).add(Duration(days: (11 - DateTime(thursday.year, 1, 1).weekday) % 7));
  final weekNum =
      ((thursday.difference(firstThursday).inDays) / 7).floor() + 1;
  return '${thursday.year}-W${weekNum.toString().padLeft(2, '0')}';
}

DateTime startOfIsoWeek(DateTime d) {
  final weekday = d.weekday; // 1..7
  return DateTime(d.year, d.month, d.day).subtract(Duration(days: weekday - 1));
}

@immutable
class MealPlanEntry {
  final String recipeId;
  final int servings;
  const MealPlanEntry({required this.recipeId, this.servings = 2});

  Map<String, dynamic> toJson() => {'recipe_id': recipeId, 'servings': servings};
  factory MealPlanEntry.fromJson(dynamic raw) {
    if (raw is String) return MealPlanEntry(recipeId: raw);
    final m = raw as Map<String, dynamic>;
    return MealPlanEntry(
      recipeId: m['recipe_id'] as String,
      servings: (m['servings'] as num?)?.toInt() ?? 2,
    );
  }
}

/// Stored as `{ "2026-W21": { "mon.dinner": entry } }`.
typedef MealPlanWeek = Map<String, MealPlanEntry>;
typedef MealPlanData = Map<String, MealPlanWeek>;

String mealKey(int weekday1to7, MealSlot slot) {
  const days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  return '${days[weekday1to7 - 1]}.${slot.name}';
}

class HistoryEntry {
  final String recipeId;
  final DateTime cookedAt;
  final int servings;
  const HistoryEntry({
    required this.recipeId,
    required this.cookedAt,
    this.servings = 2,
  });

  Map<String, dynamic> toJson() => {
        'recipe_id': recipeId,
        'cooked_at': cookedAt.toUtc().toIso8601String(),
        'servings': servings,
      };
  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        recipeId: j['recipe_id'] as String,
        cookedAt: DateTime.parse(j['cooked_at'] as String),
        servings: (j['servings'] as num?)?.toInt() ?? 2,
      );
}

class ShoppingItem {
  final String ingredientId;
  final String displayName;
  final double amount;
  final String unit;
  final String? aisle;
  final List<String> sourceRecipeIds;
  final bool checked;

  const ShoppingItem({
    required this.ingredientId,
    required this.displayName,
    required this.amount,
    required this.unit,
    this.aisle,
    this.sourceRecipeIds = const [],
    this.checked = false,
  });

  ShoppingItem copyWith({
    double? amount,
    bool? checked,
    List<String>? sourceRecipeIds,
  }) =>
      ShoppingItem(
        ingredientId: ingredientId,
        displayName: displayName,
        amount: amount ?? this.amount,
        unit: unit,
        aisle: aisle,
        sourceRecipeIds: sourceRecipeIds ?? this.sourceRecipeIds,
        checked: checked ?? this.checked,
      );

  Map<String, dynamic> toJson() => {
        'ingredient_id': ingredientId,
        'display_name': displayName,
        'amount': amount,
        'unit': unit,
        'aisle': aisle,
        'source_recipe_ids': sourceRecipeIds,
        'checked': checked,
      };
  factory ShoppingItem.fromJson(Map<String, dynamic> j) => ShoppingItem(
        ingredientId: j['ingredient_id'] as String,
        displayName: j['display_name'] as String,
        amount: (j['amount'] as num).toDouble(),
        unit: j['unit'] as String,
        aisle: j['aisle'] as String?,
        sourceRecipeIds:
            (j['source_recipe_ids'] as List?)?.cast<String>() ?? const [],
        checked: j['checked'] as bool? ?? false,
      );
}
