import 'localized_text.dart';

class CookingHistoryEntry {
  const CookingHistoryEntry({
    required this.id,
    required this.recipeId,
    required this.cookedAt,
    required this.servings,
  });

  final String id;
  final String recipeId;
  final DateTime cookedAt;
  final int servings;

  Map<String, Object?> toJson() => {
    'id': id,
    'recipe_id': recipeId,
    'cooked_at': cookedAt.toUtc().toIso8601String(),
    'servings': servings,
  };

  factory CookingHistoryEntry.fromJson(Map<String, dynamic> json) =>
      CookingHistoryEntry(
        id: json['id'] as String,
        recipeId: json['recipe_id'] as String,
        cookedAt: DateTime.parse(json['cooked_at'] as String).toLocal(),
        servings: (json['servings'] as num?)?.round() ?? 2,
      );
}

class ShoppingItem {
  const ShoppingItem({
    required this.ingredientId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.aisle,
    this.checked = false,
    this.frequency = 1,
  });

  final String ingredientId;
  final LocalizedText name;
  final double quantity;
  final String unit;
  final String aisle;
  final bool checked;
  final int frequency;

  ShoppingItem copyWith({
    double? quantity,
    String? unit,
    bool? checked,
    int? frequency,
  }) => ShoppingItem(
    ingredientId: ingredientId,
    name: name,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    aisle: aisle,
    checked: checked ?? this.checked,
    frequency: frequency ?? this.frequency,
  );

  Map<String, Object?> toJson() => {
    'ingredient_id': ingredientId,
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'aisle': aisle,
    'checked': checked,
    'frequency': frequency,
  };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
    ingredientId: json['ingredient_id'] as String,
    name: localizedTextFromJson(json['name']),
    quantity: (json['quantity'] as num).toDouble(),
    unit: json['unit'] as String,
    aisle: json['aisle'] as String,
    checked: json['checked'] as bool? ?? false,
    frequency: (json['frequency'] as num?)?.round() ?? 1,
  );
}

class ShoppingAddition {
  const ShoppingAddition({required this.ingredientIds, required this.addedAt});

  final List<String> ingredientIds;
  final DateTime addedAt;

  Map<String, Object?> toJson() => {
    'ingredient_ids': ingredientIds,
    'added_at': addedAt.toUtc().toIso8601String(),
  };

  factory ShoppingAddition.fromJson(Map<String, dynamic> json) =>
      ShoppingAddition(
        ingredientIds: (json['ingredient_ids'] as List)
            .map((item) => '$item')
            .toList(),
        addedAt: DateTime.parse(json['added_at'] as String).toLocal(),
      );
}

class CookProgress {
  const CookProgress({
    required this.recipeId,
    required this.stepIndex,
    required this.servings,
    required this.remainingSeconds,
    required this.paused,
  });

  final String recipeId;
  final int stepIndex;
  final int servings;
  final int remainingSeconds;
  final bool paused;

  Map<String, Object?> toJson() => {
    'recipe_id': recipeId,
    'step_index': stepIndex,
    'servings': servings,
    'remaining_seconds': remainingSeconds,
    'paused': paused,
  };

  factory CookProgress.fromJson(Map<String, dynamic> json) => CookProgress(
    recipeId: json['recipe_id'] as String,
    stepIndex: (json['step_index'] as num).round(),
    servings: (json['servings'] as num).round(),
    remainingSeconds: (json['remaining_seconds'] as num?)?.round() ?? 0,
    paused: json['paused'] as bool? ?? true,
  );
}
