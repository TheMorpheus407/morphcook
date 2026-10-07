/// One aggregated line on the market list. Amounts from several recipes are
/// merged by the unit-aware aggregator before they ever reach this model.
class ShoppingItem {
  final String ingredientId;
  final double amount;
  final String unit;
  final bool checked;
  final List<String> sourceRecipeIds;
  final DateTime addedAt;

  const ShoppingItem({
    required this.ingredientId,
    required this.amount,
    required this.unit,
    this.checked = false,
    this.sourceRecipeIds = const [],
    required this.addedAt,
  });

  ShoppingItem copyWith({
    double? amount,
    String? unit,
    bool? checked,
    List<String>? sourceRecipeIds,
    DateTime? addedAt,
  }) =>
      ShoppingItem(
        ingredientId: ingredientId,
        amount: amount ?? this.amount,
        unit: unit ?? this.unit,
        checked: checked ?? this.checked,
        sourceRecipeIds: sourceRecipeIds ?? this.sourceRecipeIds,
        addedAt: addedAt ?? this.addedAt,
      );

  Map<String, dynamic> toJson() => {
        'ingredient_id': ingredientId,
        'amount': amount,
        'unit': unit,
        'checked': checked,
        'source_recipe_ids': sourceRecipeIds,
        'added_at': addedAt.toIso8601String(),
      };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
        ingredientId: json['ingredient_id'] as String,
        amount: (json['amount'] as num).toDouble(),
        unit: json['unit'] as String,
        checked: json['checked'] as bool? ?? false,
        sourceRecipeIds: (json['source_recipe_ids'] as List? ?? const []).cast<String>(),
        addedAt: DateTime.parse(json['added_at'] as String),
      );
}

/// One entry in the shopping log — the raw material for Shopping Insights
/// (variety score, top ingredients, seasonal breakdown by month).
class ShoppingLogEntry {
  final String ingredientId;
  final double amount;
  final String unit;
  final String? recipeId;
  final DateTime addedAt;

  const ShoppingLogEntry({
    required this.ingredientId,
    required this.amount,
    required this.unit,
    this.recipeId,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
        'ingredient_id': ingredientId,
        'amount': amount,
        'unit': unit,
        if (recipeId != null) 'recipe_id': recipeId,
        'added_at': addedAt.toIso8601String(),
      };

  factory ShoppingLogEntry.fromJson(Map<String, dynamic> json) => ShoppingLogEntry(
        ingredientId: json['ingredient_id'] as String,
        amount: (json['amount'] as num).toDouble(),
        unit: json['unit'] as String,
        recipeId: json['recipe_id'] as String?,
        addedAt: DateTime.parse(json['added_at'] as String),
      );
}

/// One cooked-recipe record in the history.
class HistoryEntry {
  final String recipeId;
  final DateTime cookedAt;

  const HistoryEntry({required this.recipeId, required this.cookedAt});

  Map<String, dynamic> toJson() => {
        'recipe_id': recipeId,
        'cooked_at': cookedAt.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        recipeId: json['recipe_id'] as String,
        cookedAt: DateTime.parse(json['cooked_at'] as String),
      );
}
