/// One finished cook: which recipe, when, for how many.
class HistoryEntry {
  const HistoryEntry({required this.recipeId, required this.cookedAt, required this.servings});

  final String recipeId;
  final DateTime cookedAt;
  final double servings;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'recipe_id': recipeId,
    'cooked_at': cookedAt.toUtc().toIso8601String(),
    'servings': servings,
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    recipeId: json['recipe_id'] as String,
    cookedAt: DateTime.parse(json['cooked_at'] as String).toLocal(),
    servings: (json['servings'] as num?)?.toDouble() ?? 2,
  );

  @override
  bool operator ==(Object other) =>
      other is HistoryEntry &&
      other.recipeId == recipeId &&
      other.cookedAt.millisecondsSinceEpoch == cookedAt.millisecondsSinceEpoch;

  @override
  int get hashCode => Object.hash(recipeId, cookedAt.millisecondsSinceEpoch);
}
