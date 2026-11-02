/// One completed cook, recorded in the history.
class CookingEntry {
  const CookingEntry({
    required this.recipeId,
    required this.cookedAt,
    this.servings = 1,
    this.durationSeconds,
  });

  final String recipeId;
  final DateTime cookedAt;
  final int servings;
  final int? durationSeconds;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'recipe_id': recipeId,
        'cooked_at': cookedAt.toIso8601String(),
        'servings': servings,
        if (durationSeconds != null) 'duration_seconds': durationSeconds,
      };

  factory CookingEntry.fromJson(Map<String, dynamic> json) {
    return CookingEntry(
      recipeId: '${json['recipe_id']}',
      cookedAt:
          DateTime.tryParse('${json['cooked_at']}') ?? DateTime.now(),
      servings: (json['servings'] as num?)?.toInt() ?? 1,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
    );
  }

  /// Days since this cook — drives the staleness bonus in ranking.
  int daysSince(DateTime now) {
    final diff = now.difference(cookedAt);
    return diff.inDays;
  }
}

/// One zero-result search, logged locally so the corpus team can see what
/// people are looking for and cannot find.
class ContentRequest {
  const ContentRequest({
    required this.query,
    required this.requestedAt,
    this.count = 1,
  });

  final String query;
  final DateTime requestedAt;
  final int count;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'query': query,
        'requested_at': requestedAt.toIso8601String(),
        'count': count,
      };

  factory ContentRequest.fromJson(Map<String, dynamic> json) {
    return ContentRequest(
      query: '${json['query']}',
      requestedAt:
          DateTime.tryParse('${json['requested_at']}') ?? DateTime.now(),
      count: (json['count'] as num?)?.toInt() ?? 1,
    );
  }
}
