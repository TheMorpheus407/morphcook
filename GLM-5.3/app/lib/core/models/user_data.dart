/// One cooked-recipe entry in the cooking history.
class HistoryEntry {
  HistoryEntry({required this.recipeId, required this.at, required this.servings});

  final String recipeId;
  final DateTime at;
  final int servings;

  Map<String, dynamic> toJson() => {
        'recipe_id': recipeId,
        'at': at.toIso8601String(),
        'servings': servings,
      };

  static HistoryEntry fromJson(Map<String, dynamic> json) => HistoryEntry(
        recipeId: json['recipe_id'] as String,
        at: DateTime.parse(json['at'] as String),
        servings: (json['servings'] as num?)?.toInt() ?? 2,
      );
}

/// One saved cookbook entry — the user saves a *specific variant* (SPEC).
class SavedEntry {
  SavedEntry({required this.recipeId, required this.at});

  final String recipeId;
  final DateTime at;

  Map<String, dynamic> toJson() => {'recipe_id': recipeId, 'at': at.toIso8601String()};

  static SavedEntry fromJson(Map<String, dynamic> json) => SavedEntry(
        recipeId: json['recipe_id'] as String,
        at: DateTime.parse(json['at'] as String),
      );
}

/// A logged zero-result search query ("content request") that informs the
/// corpus team about gaps. Stays local; travels inside backups.
class ContentRequest {
  ContentRequest({required this.query, required this.at});

  final String query;
  final DateTime at;

  Map<String, dynamic> toJson() => {'query': query, 'at': at.toIso8601String()};

  static ContentRequest fromJson(Map<String, dynamic> json) => ContentRequest(
        query: json['query'] as String,
        at: DateTime.parse(json['at'] as String),
      );
}

/// Slot ids of the weekly meal plan grid: `mon` … `sun` × `breakfast`,
/// `lunch`, `dinner`.
class MealSlots {
  static const days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  static const meals = ['breakfast', 'lunch', 'dinner'];

  static const daySlots = <String>[
    'mon.breakfast', 'mon.lunch', 'mon.dinner',
    'tue.breakfast', 'tue.lunch', 'tue.dinner',
    'wed.breakfast', 'wed.lunch', 'wed.dinner',
    'thu.breakfast', 'thu.lunch', 'thu.dinner',
    'fri.breakfast', 'fri.lunch', 'fri.dinner',
    'sat.breakfast', 'sat.lunch', 'sat.dinner',
    'sun.breakfast', 'sun.lunch', 'sun.dinner',
  ];

  static String dayOf(String slot) => slot.split('.').first;

  static String mealOf(String slot) => slot.split('.').last;
}

/// The weekly meal plan: ISO week key (`2026-W33`) → slot → recipe id.
class MealPlan {
  MealPlan({Map<String, Map<String, String>>? weeks}) : weeks = weeks ?? {};

  final Map<String, Map<String, String>> weeks;

  String? recipeAt(String weekKey, String slot) => weeks[weekKey]?[slot];

  void assign(String weekKey, String slot, String recipeId) {
    weeks.putIfAbsent(weekKey, () => {})[slot] = recipeId;
  }

  void clear(String weekKey, String slot) {
    weeks[weekKey]?.remove(slot);
  }

  /// Drag & drop: moves (and swaps when the target is occupied).
  void move(String fromWeek, String fromSlot, String toWeek, String toSlot) {
    final moving = recipeAt(fromWeek, fromSlot);
    if (moving == null) return;
    final displaced = recipeAt(toWeek, toSlot);
    clear(fromWeek, fromSlot);
    assign(toWeek, toSlot, moving);
    if (displaced != null) {
      assign(fromWeek, fromSlot, displaced);
    }
  }

  /// All recipes assigned in a week (in day/meal order).
  List<String> recipesOfWeek(String weekKey) => MealSlots.daySlots
      .map((slot) => weeks[weekKey]?[slot])
      .whereType<String>()
      .toList();

  Map<String, dynamic> toJson() => weeks.map((k, v) => MapEntry(k, v));

  static MealPlan fromJson(Map<String, dynamic> json) {
    final weeks = <String, Map<String, String>>{};
    json.forEach((week, slots) {
      if (slots is Map) {
        weeks[week] = slots.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    });
    return MealPlan(weeks: weeks);
  }
}
