class HistoryEntry {
  final String recipeId;
  final DateTime cookedAt;
  final int? rating; // 1..5, optional

  const HistoryEntry({
    required this.recipeId,
    required this.cookedAt,
    this.rating,
  });

  Map<String, dynamic> toJson() => {
        'recipe_id': recipeId,
        'cooked_at': cookedAt.toIso8601String(),
        'rating': rating,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        recipeId: json['recipe_id'] as String,
        cookedAt: DateTime.tryParse(json['cooked_at'] as String? ?? '') ??
            DateTime.now(),
        rating: (json['rating'] as num?)?.toInt(),
      );
}
