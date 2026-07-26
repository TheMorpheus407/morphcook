import 'package:flutter/foundation.dart';

/// A saved recipe. The user saves a *variant*, never a dish.
@immutable
class SavedRecipe {
  const SavedRecipe({
    required this.recipeId,
    required this.savedAt,
    this.note = '',
  });

  factory SavedRecipe.fromJson(Map<String, dynamic> j) => SavedRecipe(
    recipeId: j['recipe_id'] as String,
    savedAt: DateTime.parse(j['saved_at'] as String),
    note: j['note'] as String? ?? '',
  );

  final String recipeId;
  final DateTime savedAt;
  final String note;

  Map<String, dynamic> toJson() => {
    'recipe_id': recipeId,
    'saved_at': savedAt.toUtc().toIso8601String(),
    if (note.isNotEmpty) 'note': note,
  };
}

@immutable
class CookHistoryEntry {
  const CookHistoryEntry({
    required this.recipeId,
    required this.cookedAt,
    required this.servings,
    required this.completed,
  });

  factory CookHistoryEntry.fromJson(Map<String, dynamic> j) => CookHistoryEntry(
    recipeId: j['recipe_id'] as String,
    cookedAt: DateTime.parse(j['cooked_at'] as String),
    servings: (j['servings'] as num?)?.toInt() ?? 2,
    completed: j['completed'] as bool? ?? true,
  );

  final String recipeId;
  final DateTime cookedAt;
  final int servings;
  final bool completed;

  Map<String, dynamic> toJson() => {
    'recipe_id': recipeId,
    'cooked_at': cookedAt.toUtc().toIso8601String(),
    'servings': servings,
    'completed': completed,
  };
}

/// `2026-W16` — ISO week key, matching the backup format in SPEC.md.
class IsoWeek {
  const IsoWeek(this.year, this.week);

  factory IsoWeek.of(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    // ISO-8601: week 1 is the week containing the first Thursday.
    final thursday = d.add(
      Duration(days: 4 - (d.weekday == 7 ? 7 : d.weekday)),
    );
    final firstJan = DateTime.utc(thursday.year, 1, 1);
    final week = ((thursday.difference(firstJan).inDays) / 7).floor() + 1;
    return IsoWeek(thursday.year, week);
  }

  factory IsoWeek.parse(String key) {
    final parts = key.split('-W');
    if (parts.length != 2) throw FormatException('bad week key: $key');
    return IsoWeek(int.parse(parts[0]), int.parse(parts[1]));
  }

  final int year;
  final int week;

  String get key => '$year-W${week.toString().padLeft(2, '0')}';

  /// Monday of this ISO week, in local time.
  DateTime get monday {
    final jan4 = DateTime(year, 1, 4);
    final mondayOfWeek1 = jan4.subtract(Duration(days: jan4.weekday - 1));
    return mondayOfWeek1.add(Duration(days: (week - 1) * 7));
  }

  IsoWeek shift(int weeks) => IsoWeek.of(monday.add(Duration(days: weeks * 7)));

  @override
  bool operator ==(Object other) =>
      other is IsoWeek && other.year == year && other.week == week;

  @override
  int get hashCode => Object.hash(year, week);

  @override
  String toString() => key;
}

const List<String> kPlanDays = [
  'mon',
  'tue',
  'wed',
  'thu',
  'fri',
  'sat',
  'sun',
];
const List<String> kPlanMeals = ['breakfast', 'lunch', 'dinner'];

/// `mon.dinner`
@immutable
class PlanSlot {
  const PlanSlot(this.day, this.meal);

  factory PlanSlot.parse(String key) {
    final parts = key.split('.');
    return PlanSlot(parts[0], parts.length > 1 ? parts[1] : 'dinner');
  }

  final String day;
  final String meal;

  String get key => '$day.$meal';

  int get dayIndex => kPlanDays.indexOf(day);

  @override
  bool operator ==(Object other) =>
      other is PlanSlot && other.day == day && other.meal == meal;

  @override
  int get hashCode => Object.hash(day, meal);

  @override
  String toString() => key;
}

/// Weekly grid. `{ "2026-W16": { "mon.dinner": "recipe-id" } }`
class MealPlan {
  MealPlan([Map<String, Map<String, String>>? weeks])
    : _weeks = weeks ?? <String, Map<String, String>>{};

  factory MealPlan.fromJson(Map<String, dynamic> j) {
    final weeks = <String, Map<String, String>>{};
    j.forEach((weekKey, slots) {
      if (slots is Map) {
        weeks[weekKey] = slots.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        );
      }
    });
    return MealPlan(weeks);
  }

  final Map<String, Map<String, String>> _weeks;

  Iterable<String> get weekKeys => _weeks.keys;

  Map<String, String> week(IsoWeek w) =>
      Map.unmodifiable(_weeks[w.key] ?? const {});

  String? recipeAt(IsoWeek w, PlanSlot slot) => _weeks[w.key]?[slot.key];

  bool get isEmpty => _weeks.values.every((w) => w.isEmpty);

  int get filledSlotCount =>
      _weeks.values.fold(0, (sum, week) => sum + week.length);

  void assign(IsoWeek w, PlanSlot slot, String recipeId) {
    (_weeks[w.key] ??= <String, String>{})[slot.key] = recipeId;
  }

  void clear(IsoWeek w, PlanSlot slot) {
    final week = _weeks[w.key];
    if (week == null) return;
    week.remove(slot.key);
    if (week.isEmpty) _weeks.remove(w.key);
  }

  void move(IsoWeek from, PlanSlot fromSlot, IsoWeek to, PlanSlot toSlot) {
    final recipeId = recipeAt(from, fromSlot);
    if (recipeId == null) return;
    final displaced = recipeAt(to, toSlot);
    clear(from, fromSlot);
    assign(to, toSlot, recipeId);
    if (displaced != null) assign(from, fromSlot, displaced);
  }

  void mergeFrom(MealPlan other) {
    other._weeks.forEach((weekKey, slots) {
      final target = _weeks[weekKey] ??= <String, String>{};
      for (final entry in slots.entries) {
        target.putIfAbsent(entry.key, () => entry.value);
      }
    });
  }

  Map<String, dynamic> toJson() =>
      _weeks.map((k, v) => MapEntry(k, Map<String, String>.from(v)));
}

/// One line on the shopping list. `addedAt` powers the seasonal breakdown in
/// Shopping Insights.
@immutable
class ShoppingEntry {
  const ShoppingEntry({
    required this.ingredientId,
    required this.qty,
    required this.unit,
    required this.addedAt,
    required this.sourceRecipeIds,
    this.checked = false,
    this.manual = false,
  });

  factory ShoppingEntry.fromJson(Map<String, dynamic> j) => ShoppingEntry(
    ingredientId: j['ingredient_id'] as String,
    qty: (j['qty'] as num?)?.toDouble(),
    unit: j['unit'] as String? ?? '',
    addedAt: DateTime.parse(j['added_at'] as String),
    sourceRecipeIds: (j['source_recipe_ids'] as List? ?? const [])
        .cast<String>()
        .toList(),
    checked: j['checked'] as bool? ?? false,
    manual: j['manual'] as bool? ?? false,
  );

  final String ingredientId;
  final double? qty;
  final String unit;
  final DateTime addedAt;
  final List<String> sourceRecipeIds;
  final bool checked;
  final bool manual;

  ShoppingEntry copyWith({bool? checked, double? qty, String? unit}) =>
      ShoppingEntry(
        ingredientId: ingredientId,
        qty: qty ?? this.qty,
        unit: unit ?? this.unit,
        addedAt: addedAt,
        sourceRecipeIds: sourceRecipeIds,
        checked: checked ?? this.checked,
        manual: manual,
      );

  Map<String, dynamic> toJson() => {
    'ingredient_id': ingredientId,
    'qty': qty,
    'unit': unit,
    'added_at': addedAt.toUtc().toIso8601String(),
    'source_recipe_ids': sourceRecipeIds,
    'checked': checked,
    'manual': manual,
  };
}

/// A search that found nothing. Stored locally; leaves the device only if the
/// user chooses to share a backup file.
@immutable
class ContentRequest {
  const ContentRequest({
    required this.query,
    required this.firstAskedAt,
    required this.count,
  });

  factory ContentRequest.fromJson(Object? j) {
    if (j is String) {
      return ContentRequest(query: j, firstAskedAt: DateTime.now(), count: 1);
    }
    final m = (j as Map).cast<String, dynamic>();
    return ContentRequest(
      query: m['query'] as String,
      firstAskedAt: DateTime.parse(m['first_asked_at'] as String),
      count: (m['count'] as num?)?.toInt() ?? 1,
    );
  }

  final String query;
  final DateTime firstAskedAt;
  final int count;

  ContentRequest bump() => ContentRequest(
    query: query,
    firstAskedAt: firstAskedAt,
    count: count + 1,
  );

  Map<String, dynamic> toJson() => {
    'query': query,
    'first_asked_at': firstAskedAt.toUtc().toIso8601String(),
    'count': count,
  };
}

/// Where the user stopped in cook mode. Restored on reopen.
@immutable
class CookProgress {
  const CookProgress({
    required this.recipeId,
    required this.stepIndex,
    required this.servings,
    required this.updatedAt,
    this.remainingTimerSeconds,
  });

  factory CookProgress.fromJson(Map<String, dynamic> j) => CookProgress(
    recipeId: j['recipe_id'] as String,
    stepIndex: (j['step_index'] as num?)?.toInt() ?? 0,
    servings: (j['servings'] as num?)?.toInt() ?? 2,
    updatedAt: DateTime.parse(j['updated_at'] as String),
    remainingTimerSeconds: (j['remaining_timer_seconds'] as num?)?.toInt(),
  );

  final String recipeId;
  final int stepIndex;
  final int servings;
  final DateTime updatedAt;
  final int? remainingTimerSeconds;

  Map<String, dynamic> toJson() => {
    'recipe_id': recipeId,
    'step_index': stepIndex,
    'servings': servings,
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'remaining_timer_seconds': remainingTimerSeconds,
  };
}
