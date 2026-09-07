/// One completed cook. The cookbook's memory.
class HistoryEntry {
  const HistoryEntry({required this.recipeId, required this.dishId, required this.cookedAt, required this.servings});
  final String recipeId;
  final String dishId;
  final DateTime cookedAt;
  final int servings;

  Map<String, dynamic> toJson() => {
        'recipe_id': recipeId,
        'dish_id': dishId,
        'cooked_at': cookedAt.toUtc().toIso8601String(),
        'servings': servings,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        recipeId: j['recipe_id'] as String,
        dishId: (j['dish_id'] as String?) ?? '',
        cookedAt: DateTime.tryParse((j['cooked_at'] as String?) ?? '')?.toLocal() ?? DateTime.now(),
        servings: ((j['servings'] as num?) ?? 2).toInt(),
      );
}
