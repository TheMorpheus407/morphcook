import 'package:collection/collection.dart';

import 'json_helpers.dart';
import 'localized_text.dart';

class SavedRecipe {
  const SavedRecipe({required this.recipeId, required this.savedAt});

  factory SavedRecipe.fromJson(Object? json) {
    if (json is String) {
      return SavedRecipe(
        recipeId: json,
        savedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
    }
    final map = jsonMap(json);
    return SavedRecipe(
      recipeId: jsonString(map['recipe_id'] ?? map['id']),
      savedAt: jsonDateTime(map['saved_at']),
    );
  }

  final String recipeId;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
    'recipe_id': recipeId,
    'saved_at': savedAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedRecipe &&
          recipeId == other.recipeId &&
          savedAt == other.savedAt;

  @override
  int get hashCode => Object.hash(recipeId, savedAt);
}

class CookHistoryEntry {
  const CookHistoryEntry({
    required this.id,
    required this.recipeId,
    required this.cookedAt,
    this.servings = 1,
    this.completed = true,
    this.durationSeconds,
  });

  factory CookHistoryEntry.fromJson(Map<String, dynamic> json) =>
      CookHistoryEntry(
        id: jsonString(json['id']),
        recipeId: jsonString(json['recipe_id']),
        cookedAt: jsonDateTime(json['cooked_at'] ?? json['completed_at']),
        servings: jsonInt(json['servings'], 1),
        completed: jsonBool(json['completed'], true),
        durationSeconds: json['duration_seconds'] == null
            ? null
            : jsonInt(json['duration_seconds']),
      );

  final String id;
  final String recipeId;
  final DateTime cookedAt;
  final int servings;
  final bool completed;
  final int? durationSeconds;

  Map<String, dynamic> toJson() => {
    'id': id,
    'recipe_id': recipeId,
    'cooked_at': cookedAt.toUtc().toIso8601String(),
    'servings': servings,
    'completed': completed,
    if (durationSeconds != null) 'duration_seconds': durationSeconds,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CookHistoryEntry &&
          id == other.id &&
          recipeId == other.recipeId &&
          cookedAt == other.cookedAt &&
          servings == other.servings &&
          completed == other.completed &&
          durationSeconds == other.durationSeconds;

  @override
  int get hashCode =>
      Object.hash(id, recipeId, cookedAt, servings, completed, durationSeconds);
}

enum MealSlot {
  breakfast,
  lunch,
  dinner;

  static MealSlot parse(Object? value) => MealSlot.values.firstWhere(
    (slot) => slot.name == value?.toString().toLowerCase(),
    orElse: () => MealSlot.dinner,
  );
}

class MealPlanEntry {
  MealPlanEntry({
    required this.id,
    required DateTime date,
    required this.slot,
    required this.recipeId,
  }) : date = DateTime(date.year, date.month, date.day);

  factory MealPlanEntry.fromJson(Map<String, dynamic> json) => MealPlanEntry(
    id: jsonString(json['id']),
    date: jsonDateTime(json['date']).toLocal(),
    slot: MealSlot.parse(json['slot']),
    recipeId: jsonString(json['recipe_id']),
  );

  final String id;
  final DateTime date;
  final MealSlot slot;
  final String recipeId;

  String get slotKey => '${_weekdayName(date.weekday)}.${slot.name}';

  MealPlanEntry copyWith({
    String? id,
    DateTime? date,
    MealSlot? slot,
    String? recipeId,
  }) => MealPlanEntry(
    id: id ?? this.id,
    date: date ?? this.date,
    slot: slot ?? this.slot,
    recipeId: recipeId ?? this.recipeId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': _dateString(date),
    'slot': slot.name,
    'recipe_id': recipeId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealPlanEntry &&
          id == other.id &&
          date == other.date &&
          slot == other.slot &&
          recipeId == other.recipeId;

  @override
  int get hashCode => Object.hash(id, date, slot, recipeId);
}

class MealPlan {
  MealPlan(Iterable<MealPlanEntry> entries)
    : entries = UnmodifiableListView(
        List.of(entries)..sort((a, b) {
          final byDate = a.date.compareTo(b.date);
          return byDate != 0 ? byDate : a.slot.index.compareTo(b.slot.index);
        }),
      );

  factory MealPlan.empty() => MealPlan(const []);

  factory MealPlan.fromJson(Object? json) {
    if (json is List) {
      return MealPlan(
        json.map((value) => MealPlanEntry.fromJson(jsonMap(value))),
      );
    }
    final map = jsonMap(json);
    if (map['entries'] is List) return MealPlan.fromJson(map['entries']);

    final entries = <MealPlanEntry>[];
    for (final weekEntry in map.entries) {
      final monday = _mondayFromIsoWeek(weekEntry.key);
      if (monday == null) continue;
      for (final slotEntry in jsonMap(weekEntry.value).entries) {
        final bits = slotEntry.key.split('.');
        if (bits.length != 2) continue;
        final weekday = _parseWeekday(bits[0]);
        final slot = MealSlot.parse(bits[1]);
        final date = monday.add(Duration(days: weekday - 1));
        entries.add(
          MealPlanEntry(
            id: '${_dateString(date)}.${slot.name}',
            date: date,
            slot: slot,
            recipeId: jsonString(slotEntry.value),
          ),
        );
      }
    }
    return MealPlan(entries);
  }

  final List<MealPlanEntry> entries;

  MealPlanEntry? at(DateTime date, MealSlot slot) => entries.firstWhereOrNull(
    (entry) => _sameDay(entry.date, date) && entry.slot == slot,
  );

  List<MealPlanEntry> weekOf(DateTime day) {
    final monday = DateTime(
      day.year,
      day.month,
      day.day,
    ).subtract(Duration(days: day.weekday - 1));
    final end = monday.add(const Duration(days: 7));
    return entries
        .where(
          (entry) => !entry.date.isBefore(monday) && entry.date.isBefore(end),
        )
        .toList();
  }

  MealPlan assign(MealPlanEntry next) => MealPlan([
    ...entries.where(
      (entry) => !(_sameDay(entry.date, next.date) && entry.slot == next.slot),
    ),
    next,
  ]);

  MealPlan remove(DateTime date, MealSlot slot) => MealPlan(
    entries.where(
      (entry) => !(_sameDay(entry.date, date) && entry.slot == slot),
    ),
  );

  MealPlan move({
    required DateTime fromDate,
    required MealSlot fromSlot,
    required DateTime toDate,
    required MealSlot toSlot,
  }) {
    final source = at(fromDate, fromSlot);
    if (source == null) return this;
    final withoutBoth = entries.where(
      (entry) =>
          !(_sameDay(entry.date, fromDate) && entry.slot == fromSlot) &&
          !(_sameDay(entry.date, toDate) && entry.slot == toSlot),
    );
    return MealPlan([
      ...withoutBoth,
      source.copyWith(date: toDate, slot: toSlot),
    ]);
  }

  List<Map<String, dynamic>> toJson() =>
      entries.map((entry) => entry.toJson()).toList();

  /// Shape used by `morphcook-backup.json` in the product specification.
  Map<String, Map<String, String>> toBackupJson() {
    final result = <String, Map<String, String>>{};
    for (final entry in entries) {
      final week = _isoWeek(entry.date);
      result.putIfAbsent(week, () => {})[entry.slotKey] = entry.recipeId;
    }
    return result;
  }
}

class ContentRequest {
  const ContentRequest({
    required this.query,
    required this.languageCode,
    required this.lastSearchedAt,
    this.count = 1,
  });

  factory ContentRequest.fromJson(Object? json) {
    if (json is String) {
      return ContentRequest(
        query: json,
        languageCode: 'en',
        lastSearchedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
    }
    final map = jsonMap(json);
    return ContentRequest(
      query: jsonString(map['query']),
      languageCode: jsonString(map['language_code'] ?? map['lang'], 'en'),
      lastSearchedAt: jsonDateTime(map['last_searched_at']),
      count: jsonInt(map['count'], 1),
    );
  }

  final String query;
  final String languageCode;
  final DateTime lastSearchedAt;
  final int count;

  String get normalizedQuery => query.trim().toLowerCase();

  Map<String, dynamic> toJson() => {
    'query': query,
    'language_code': normalizeLanguageCode(languageCode),
    'last_searched_at': lastSearchedAt.toUtc().toIso8601String(),
    'count': count,
  };
}

class CookSessionProgress {
  CookSessionProgress({
    required this.recipeId,
    required this.startedAt,
    this.currentStepIndex = 0,
    this.servings = 1,
    Set<String> completedStepIds = const {},
    Map<String, int> remainingTimerSeconds = const {},
    this.pausedAt,
    this.completedAt,
  }) : completedStepIds = UnmodifiableSetView(Set.of(completedStepIds)),
       remainingTimerSeconds = UnmodifiableMapView(
         Map.of(remainingTimerSeconds),
       );

  factory CookSessionProgress.fromJson(Map<String, dynamic> json) =>
      CookSessionProgress(
        recipeId: jsonString(json['recipe_id']),
        startedAt: jsonDateTime(json['started_at']),
        currentStepIndex: jsonInt(json['current_step_index']),
        servings: jsonInt(json['servings'], 1),
        completedStepIds: jsonStringSet(json['completed_step_ids']),
        remainingTimerSeconds: {
          for (final entry in jsonMap(json['remaining_timer_seconds']).entries)
            entry.key: jsonInt(entry.value),
        },
        pausedAt: jsonDateTimeOrNull(json['paused_at']),
        completedAt: jsonDateTimeOrNull(json['completed_at']),
      );

  final String recipeId;
  final DateTime startedAt;
  final int currentStepIndex;
  final int servings;
  final Set<String> completedStepIds;
  final Map<String, int> remainingTimerSeconds;
  final DateTime? pausedAt;
  final DateTime? completedAt;

  bool get isComplete => completedAt != null;
  bool get isPaused => pausedAt != null && completedAt == null;

  Map<String, dynamic> toJson() => {
    'recipe_id': recipeId,
    'started_at': startedAt.toUtc().toIso8601String(),
    'current_step_index': currentStepIndex,
    'servings': servings,
    'completed_step_ids': completedStepIds.toList()..sort(),
    'remaining_timer_seconds': remainingTimerSeconds,
    if (pausedAt != null) 'paused_at': pausedAt!.toUtc().toIso8601String(),
    if (completedAt != null)
      'completed_at': completedAt!.toUtc().toIso8601String(),
  };
}

class ShoppingListItem {
  ShoppingListItem({
    required this.id,
    required this.ingredientId,
    required this.quantity,
    required this.unit,
    required this.aisle,
    Set<String> recipeIds = const {},
    this.checked = false,
    required this.addedAt,
  }) : recipeIds = UnmodifiableSetView(Set.of(recipeIds));

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) =>
      ShoppingListItem(
        id: jsonString(json['id']),
        ingredientId: jsonString(json['ingredient_id']),
        quantity: jsonDouble(json['quantity']),
        unit: jsonString(json['unit']),
        aisle: jsonString(json['aisle'], 'other'),
        recipeIds: jsonStringSet(json['recipe_ids']),
        checked: jsonBool(json['checked']),
        addedAt: jsonDateTime(json['added_at']),
      );

  final String id;
  final String ingredientId;
  final double quantity;
  final String unit;
  final String aisle;
  final Set<String> recipeIds;
  final bool checked;
  final DateTime addedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'ingredient_id': ingredientId,
    'quantity': quantity,
    'unit': unit,
    'aisle': aisle,
    'recipe_ids': recipeIds.toList()..sort(),
    'checked': checked,
    'added_at': addedAt.toUtc().toIso8601String(),
  };
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _dateString(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _weekdayName(int weekday) =>
    const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'][weekday - 1];

int _parseWeekday(String value) {
  final index = const [
    'mon',
    'tue',
    'wed',
    'thu',
    'fri',
    'sat',
    'sun',
  ].indexOf(value.toLowerCase());
  return index < 0 ? DateTime.monday : index + 1;
}

String _isoWeek(DateTime value) {
  // UTC calendar arithmetic avoids losing a day when local DST starts.
  final date = DateTime.utc(value.year, value.month, value.day);
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final yearStart = DateTime.utc(thursday.year, 1, 1);
  final week = 1 + (thursday.difference(yearStart).inDays ~/ 7);
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

DateTime? _mondayFromIsoWeek(String value) {
  final match = RegExp(r'^(\d{4})-W(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final week = int.parse(match.group(2)!);
  final januaryFourth = DateTime.utc(year, 1, 4);
  final weekOneMonday = januaryFourth.subtract(
    Duration(days: januaryFourth.weekday - DateTime.monday),
  );
  final result = weekOneMonday.add(Duration(days: (week - 1) * 7));
  return DateTime(result.year, result.month, result.day);
}
