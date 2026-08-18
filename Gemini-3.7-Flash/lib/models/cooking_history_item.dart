class CookingHistoryItem {
  final String recipeId;
  final String dishId;
  final DateTime cookedAt;
  final int timeSpentMinutes;
  final int servingsCooked;

  const CookingHistoryItem({
    required this.recipeId,
    required this.dishId,
    required this.cookedAt,
    this.timeSpentMinutes = 20,
    this.servingsCooked = 2,
  });

  factory CookingHistoryItem.fromJson(Map<String, dynamic> json) {
    return CookingHistoryItem(
      recipeId: json['recipe_id'] as String? ?? '',
      dishId: json['dish_id'] as String? ?? '',
      cookedAt: json['cooked_at'] != null
          ? DateTime.tryParse(json['cooked_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      timeSpentMinutes: json['time_spent_minutes'] as int? ?? 20,
      servingsCooked: json['servings_cooked'] as int? ?? 2,
    );
  }

  Map<String, dynamic> toJson() => {
    'recipe_id': recipeId,
    'dish_id': dishId,
    'cooked_at': cookedAt.toIso8601String(),
    'time_spent_minutes': timeSpentMinutes,
    'servings_cooked': servingsCooked,
  };
}
