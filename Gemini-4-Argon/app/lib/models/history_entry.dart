class CookHistoryEntry {
  final String id;
  final String recipeId;
  final String dishId;
  final DateTime cookedAt;
  final int servingsCooked;
  final String? notes;

  const CookHistoryEntry({
    required this.id,
    required this.recipeId,
    required this.dishId,
    required this.cookedAt,
    this.servingsCooked = 2,
    this.notes,
  });

  factory CookHistoryEntry.fromJson(Map<String, dynamic> json) {
    return CookHistoryEntry(
      id: json['id']?.toString() ??
          '${json['recipe_id']}_${json['cooked_at']}',
      recipeId: json['recipe_id']?.toString() ?? '',
      dishId: json['dish_id']?.toString() ?? '',
      cookedAt: DateTime.tryParse(json['cooked_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      servingsCooked: (json['servings_cooked'] as num?)?.toInt() ?? 2,
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipe_id': recipeId,
        'dish_id': dishId,
        'cooked_at': cookedAt.toUtc().toIso8601String(),
        'servings_cooked': servingsCooked,
        if (notes != null) 'notes': notes,
      };
}

/// Persisted state for pausing and resuming Cook Mode across app sessions.
class ActiveCookSession {
  final String recipeId;
  final int currentStepIndex;
  final int scaledServings;
  final int? remainingTimerSeconds;
  final bool isPaused;
  final DateTime updatedAt;
  final Set<String> checkedIngredientIds;

  const ActiveCookSession({
    required this.recipeId,
    required this.currentStepIndex,
    required this.scaledServings,
    this.remainingTimerSeconds,
    this.isPaused = true,
    required this.updatedAt,
    this.checkedIngredientIds = const {},
  });

  factory ActiveCookSession.fromJson(Map<String, dynamic> json) {
    return ActiveCookSession(
      recipeId: json['recipe_id']?.toString() ?? '',
      currentStepIndex: (json['current_step_index'] as num?)?.toInt() ?? 0,
      scaledServings: (json['scaled_servings'] as num?)?.toInt() ?? 2,
      remainingTimerSeconds: (json['remaining_timer_seconds'] as num?)?.toInt(),
      isPaused: json['is_paused'] as bool? ?? true,
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      checkedIngredientIds:
          ((json['checked_ingredient_ids'] as List<dynamic>?) ?? const [])
              .map((e) => e.toString())
              .toSet(),
    );
  }

  Map<String, dynamic> toJson() => {
        'recipe_id': recipeId,
        'current_step_index': currentStepIndex,
        'scaled_servings': scaledServings,
        'remaining_timer_seconds': remainingTimerSeconds,
        'is_paused': isPaused,
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'checked_ingredient_ids': checkedIngredientIds.toList(),
      };

  ActiveCookSession copyWith({
    int? currentStepIndex,
    int? scaledServings,
    int? remainingTimerSeconds,
    bool clearTimer = false,
    bool? isPaused,
    DateTime? updatedAt,
    Set<String>? checkedIngredientIds,
  }) {
    return ActiveCookSession(
      recipeId: recipeId,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      scaledServings: scaledServings ?? this.scaledServings,
      remainingTimerSeconds:
          clearTimer ? null : (remainingTimerSeconds ?? this.remainingTimerSeconds),
      isPaused: isPaused ?? this.isPaused,
      updatedAt: updatedAt ?? DateTime.now(),
      checkedIngredientIds: checkedIngredientIds ?? this.checkedIngredientIds,
    );
  }
}
