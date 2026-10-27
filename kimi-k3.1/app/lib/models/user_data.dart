import 'profile.dart';

class SavedRecipe {
  const SavedRecipe({required this.recipeId, required this.savedAt});
  final String recipeId;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
    'recipe_id': recipeId,
    'saved_at': savedAt.toUtc().toIso8601String(),
  };

  factory SavedRecipe.fromJson(Map json) => SavedRecipe(
    recipeId: json['recipe_id'].toString(),
    savedAt:
        DateTime.tryParse(json['saved_at']?.toString() ?? '')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
}

class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.recipeId,
    required this.cookedAt,
    required this.servings,
  });
  final String id;
  final String recipeId;
  final DateTime cookedAt;
  final int servings;

  Map<String, dynamic> toJson() => {
    'id': id,
    'recipe_id': recipeId,
    'cooked_at': cookedAt.toUtc().toIso8601String(),
    'servings': servings,
  };

  factory HistoryEntry.fromJson(Map json) => HistoryEntry(
    id: json['id']?.toString() ?? '${json['recipe_id']}-${json['cooked_at']}',
    recipeId: json['recipe_id'].toString(),
    cookedAt:
        DateTime.tryParse(json['cooked_at']?.toString() ?? '')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    servings: (json['servings'] as num?)?.toInt() ?? 2,
  );
}

class ShoppingEvent {
  const ShoppingEvent({
    required this.id,
    required this.ingredientId,
    required this.recipeId,
    required this.addedAt,
    required this.amount,
    required this.unit,
  });
  final String id;
  final String ingredientId;
  final String recipeId;
  final DateTime addedAt;
  final double? amount;
  final String unit;

  Map<String, dynamic> toJson() => {
    'id': id,
    'ingredient_id': ingredientId,
    'recipe_id': recipeId,
    'added_at': addedAt.toUtc().toIso8601String(),
    'amount': amount,
    'unit': unit,
  };

  factory ShoppingEvent.fromJson(Map json) => ShoppingEvent(
    id:
        json['id']?.toString() ??
        '${json['ingredient_id']}-${json['added_at']}',
    ingredientId: json['ingredient_id'].toString(),
    recipeId: json['recipe_id']?.toString() ?? '',
    addedAt:
        DateTime.tryParse(json['added_at']?.toString() ?? '')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    amount: json['amount'] is num ? (json['amount'] as num).toDouble() : null,
    unit: json['unit']?.toString() ?? 'piece',
  );
}

class CookProgress {
  const CookProgress({
    required this.recipeId,
    required this.stepIndex,
    required this.remainingSeconds,
    required this.servings,
    required this.isRunning,
    required this.updatedAt,
  });
  final String recipeId;
  final int stepIndex;
  final int remainingSeconds;
  final int servings;
  final bool isRunning;
  final DateTime updatedAt;

  CookProgress copyWith({
    int? stepIndex,
    int? remainingSeconds,
    int? servings,
    bool? isRunning,
    DateTime? updatedAt,
  }) => CookProgress(
    recipeId: recipeId,
    stepIndex: stepIndex ?? this.stepIndex,
    remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    servings: servings ?? this.servings,
    isRunning: isRunning ?? this.isRunning,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'recipe_id': recipeId,
    'step_index': stepIndex,
    'remaining_seconds': remainingSeconds,
    'servings': servings,
    'is_running': isRunning,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory CookProgress.fromJson(Map json) => CookProgress(
    recipeId: json['recipe_id'].toString(),
    stepIndex: (json['step_index'] as num?)?.toInt() ?? 0,
    remainingSeconds: (json['remaining_seconds'] as num?)?.toInt() ?? 0,
    servings: (json['servings'] as num?)?.toInt() ?? 2,
    isRunning: json['is_running'] == true,
    updatedAt:
        DateTime.tryParse(json['updated_at']?.toString() ?? '')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
}

class UserSnapshot {
  const UserSnapshot({
    this.saved = const [],
    this.history = const [],
    this.mealPlan = const {},
    this.shoppingRecipeIds = const [],
    this.checkedShoppingItems = const {},
    this.shoppingEvents = const [],
    this.contentRequests = const [],
    this.cookProgress = const {},
  });

  final List<SavedRecipe> saved;
  final List<HistoryEntry> history;
  final Map<String, Map<String, String>> mealPlan;
  final List<String> shoppingRecipeIds;
  final Set<String> checkedShoppingItems;
  final List<ShoppingEvent> shoppingEvents;
  final List<String> contentRequests;
  final Map<String, CookProgress> cookProgress;

  UserSnapshot copyWith({
    List<SavedRecipe>? saved,
    List<HistoryEntry>? history,
    Map<String, Map<String, String>>? mealPlan,
    List<String>? shoppingRecipeIds,
    Set<String>? checkedShoppingItems,
    List<ShoppingEvent>? shoppingEvents,
    List<String>? contentRequests,
    Map<String, CookProgress>? cookProgress,
  }) => UserSnapshot(
    saved: saved ?? this.saved,
    history: history ?? this.history,
    mealPlan: mealPlan ?? this.mealPlan,
    shoppingRecipeIds: shoppingRecipeIds ?? this.shoppingRecipeIds,
    checkedShoppingItems: checkedShoppingItems ?? this.checkedShoppingItems,
    shoppingEvents: shoppingEvents ?? this.shoppingEvents,
    contentRequests: contentRequests ?? this.contentRequests,
    cookProgress: cookProgress ?? this.cookProgress,
  );

  Map<String, dynamic> toJson() => {
    'saved': saved.map((item) => item.recipeId).toList(),
    'saved_metadata': {
      for (final item in saved)
        item.recipeId: item.savedAt.toUtc().toIso8601String(),
    },
    'meal_plan': mealPlan.map(
      (week, slots) => MapEntry(week, Map<String, String>.from(slots)),
    ),
    'history': history.map((item) => item.toJson()).toList(),
    'content_requests': contentRequests,
    'shopping': {
      'recipe_ids': shoppingRecipeIds,
      'checked_items': checkedShoppingItems.toList()..sort(),
      'events': shoppingEvents.map((item) => item.toJson()).toList(),
    },
    'cook_progress': cookProgress.map(
      (id, progress) => MapEntry(id, progress.toJson()),
    ),
  };

  factory UserSnapshot.fromJson(Object? value) {
    final json = value is Map ? value : const {};
    final metadata = json['saved_metadata'] is Map
        ? json['saved_metadata'] as Map
        : const {};
    final saved = <SavedRecipe>[];
    for (final item in json['saved'] as List? ?? const []) {
      if (item is Map) {
        saved.add(SavedRecipe.fromJson(item));
      } else {
        final id = item.toString();
        saved.add(
          SavedRecipe(
            recipeId: id,
            savedAt:
                DateTime.tryParse(metadata[id]?.toString() ?? '')?.toUtc() ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          ),
        );
      }
    }
    final plan = <String, Map<String, String>>{};
    if (json['meal_plan'] is Map) {
      for (final week in (json['meal_plan'] as Map).entries) {
        if (week.value is Map) {
          plan[week.key.toString()] = (week.value as Map).map(
            (slot, recipe) => MapEntry(slot.toString(), recipe.toString()),
          );
        }
      }
    }
    final shopping = json['shopping'] is Map
        ? json['shopping'] as Map
        : const {};
    final progress = <String, CookProgress>{};
    if (json['cook_progress'] is Map) {
      for (final item in (json['cook_progress'] as Map).entries) {
        if (item.value is Map) {
          final entry = CookProgress.fromJson(item.value as Map);
          progress[entry.recipeId] = entry;
        }
      }
    }
    List<String> readStrings(Object? source) => source is List
        ? source.map((item) => item.toString()).toList()
        : const [];
    return UserSnapshot(
      saved: saved,
      history: (json['history'] as List? ?? const [])
          .whereType<Map>()
          .map(HistoryEntry.fromJson)
          .toList(),
      mealPlan: plan,
      shoppingRecipeIds: readStrings(shopping['recipe_ids']),
      checkedShoppingItems: readStrings(shopping['checked_items']).toSet(),
      shoppingEvents: (shopping['events'] as List? ?? const [])
          .whereType<Map>()
          .map(ShoppingEvent.fromJson)
          .toList(),
      contentRequests: readStrings(json['content_requests']),
      cookProgress: progress,
    );
  }

  UserSnapshot mergedWith(UserSnapshot incoming) {
    final saved = <String, SavedRecipe>{
      for (final item in this.saved) item.recipeId: item,
    };
    for (final item in incoming.saved) {
      saved[item.recipeId] = item;
    }
    final history = <String, HistoryEntry>{
      for (final item in this.history) item.id: item,
    };
    for (final item in incoming.history) {
      history[item.id] = item;
    }
    final events = <String, ShoppingEvent>{
      for (final item in shoppingEvents) item.id: item,
    };
    for (final item in incoming.shoppingEvents) {
      events[item.id] = item;
    }
    final plan = <String, Map<String, String>>{
      for (final entry in mealPlan.entries) entry.key: {...entry.value},
    };
    for (final week in incoming.mealPlan.entries) {
      plan.update(
        week.key,
        (slots) => {...slots, ...week.value},
        ifAbsent: () => {...week.value},
      );
    }
    return UserSnapshot(
      saved: saved.values.toList()
        ..sort((a, b) => b.savedAt.compareTo(a.savedAt)),
      history: history.values.toList()
        ..sort((a, b) => b.cookedAt.compareTo(a.cookedAt)),
      mealPlan: plan,
      shoppingRecipeIds: {
        ...shoppingRecipeIds,
        ...incoming.shoppingRecipeIds,
      }.toList(),
      checkedShoppingItems: {
        ...checkedShoppingItems,
        ...incoming.checkedShoppingItems,
      },
      shoppingEvents: events.values.toList()
        ..sort((a, b) => a.addedAt.compareTo(b.addedAt)),
      contentRequests: {
        ...contentRequests,
        ...incoming.contentRequests,
      }.toList(),
      cookProgress: {...cookProgress, ...incoming.cookProgress},
    );
  }
}

class BackupData {
  const BackupData({required this.profile, required this.snapshot});
  final Profile profile;
  final UserSnapshot snapshot;
}

String weekKey(DateTime date) {
  final thursday = DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).add(Duration(days: DateTime.thursday - date.weekday));
  final january4 = DateTime.utc(thursday.year, 1, 4);
  final firstThursday = january4.add(
    Duration(days: DateTime.thursday - january4.weekday),
  );
  final week = 1 + (thursday.difference(firstThursday).inDays ~/ 7);
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

DateTime mondayForWeek(DateTime date) {
  final local = DateTime(date.year, date.month, date.day);
  return local.subtract(Duration(days: local.weekday - 1));
}
