/// A cooked-recipe history entry.
class HistoryEntry {
  final String recipeId;
  final DateTime cookedAt;

  const HistoryEntry({required this.recipeId, required this.cookedAt});

  Map<String, dynamic> toJson() => {
    'recipe_id': recipeId,
    'cooked_at': cookedAt.toUtc().toIso8601String(),
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    recipeId: json['recipe_id'] as String,
    cookedAt: DateTime.parse(json['cooked_at'] as String),
  );
}

/// A saved recipe in the cookbook — the user saves a specific variant.
class SavedRecipe {
  final String recipeId;
  final DateTime savedAt;

  const SavedRecipe({required this.recipeId, required this.savedAt});

  Map<String, dynamic> toJson() => {
    'recipe_id': recipeId,
    'saved_at': savedAt.toUtc().toIso8601String(),
  };

  factory SavedRecipe.fromJson(Map<String, dynamic> json) => SavedRecipe(
    recipeId: json['recipe_id'] as String,
    savedAt: DateTime.parse(json['saved_at'] as String),
  );
}

const mealSlots = ['breakfast', 'lunch', 'dinner'];
const weekDays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/// ISO week key like `2026-W16`.
String isoWeekKey(DateTime date) {
  // ISO 8601: week 1 contains the first Thursday of the year. Computed in
  // UTC so DST transitions cannot shave hours off day differences.
  final day = DateTime.utc(date.year, date.month, date.day);
  final thursday = day.add(Duration(days: 4 - day.weekday));
  final firstDay = DateTime.utc(thursday.year, 1, 1);
  final week = 1 + (thursday.difference(firstDay).inDays ~/ 7);
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

/// Monday of the week containing [date].
DateTime weekStart(DateTime date) => DateTime(
  date.year,
  date.month,
  date.day,
).subtract(Duration(days: date.weekday - 1));

/// Meal plan: week key -> "mon.dinner" -> recipe id.
typedef MealPlanData = Map<String, Map<String, String>>;

/// One item on the shopping list (manually checked off by the user).
class ShoppingItem {
  final String ingredientId;

  /// Authored ingredient name when no bundled dictionary entry exists.
  final String? customName;
  final double qty;
  final String unit;
  final String aisle;
  final bool checked;
  final DateTime addedAt;

  const ShoppingItem({
    required this.ingredientId,
    this.customName,
    required this.qty,
    required this.unit,
    required this.aisle,
    this.checked = false,
    required this.addedAt,
  });

  ShoppingItem copyWith({
    String? customName,
    double? qty,
    String? unit,
    bool? checked,
  }) => ShoppingItem(
    ingredientId: ingredientId,
    customName: customName ?? this.customName,
    qty: qty ?? this.qty,
    unit: unit ?? this.unit,
    aisle: aisle,
    checked: checked ?? this.checked,
    addedAt: addedAt,
  );

  Map<String, dynamic> toJson() => {
    'ingredient_id': ingredientId,
    if (customName != null) 'custom_name': customName,
    'qty': qty,
    'unit': unit,
    'aisle': aisle,
    'checked': checked,
    'added_at': addedAt.toUtc().toIso8601String(),
  };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
    ingredientId: json['ingredient_id'] as String,
    customName: json['custom_name'] as String?,
    qty: (json['qty'] as num).toDouble(),
    unit: json['unit'] as String,
    aisle: json['aisle'] as String,
    checked: json['checked'] as bool? ?? false,
    addedAt: DateTime.parse(json['added_at'] as String),
  );
}
