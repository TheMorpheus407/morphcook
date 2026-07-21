import 'dart:async';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:morphcook/domain/models.dart';

import 'cook_session_controller.dart';
import 'shopping_service.dart';

class LocalStoreSnapshot {
  LocalStoreSnapshot({
    required Iterable<SavedRecipe> savedRecipes,
    required Iterable<CookHistoryEntry> history,
    required this.mealPlan,
    required Iterable<ShoppingEntry> shoppingEntries,
    required Iterable<ShoppingInsightEvent> shoppingInsightEvents,
    required Iterable<ContentRequest> contentRequests,
    required Map<String, CookSessionSnapshot> cookSessions,
  }) : savedRecipes = List<SavedRecipe>.unmodifiable(savedRecipes),
       history = List<CookHistoryEntry>.unmodifiable(history),
       shoppingEntries = List<ShoppingEntry>.unmodifiable(shoppingEntries),
       shoppingInsightEvents = List<ShoppingInsightEvent>.unmodifiable(
         shoppingInsightEvents,
       ),
       contentRequests = List<ContentRequest>.unmodifiable(contentRequests),
       cookSessions = Map<String, CookSessionSnapshot>.unmodifiable(
         cookSessions,
       );

  factory LocalStoreSnapshot.empty() => LocalStoreSnapshot(
    savedRecipes: const <SavedRecipe>[],
    history: const <CookHistoryEntry>[],
    mealPlan: MealPlan.empty(),
    shoppingEntries: const <ShoppingEntry>[],
    shoppingInsightEvents: const <ShoppingInsightEvent>[],
    contentRequests: const <ContentRequest>[],
    cookSessions: const <String, CookSessionSnapshot>{},
  );

  final List<SavedRecipe> savedRecipes;
  final List<CookHistoryEntry> history;
  final MealPlan mealPlan;
  final List<ShoppingEntry> shoppingEntries;
  final List<ShoppingInsightEvent> shoppingInsightEvents;
  final List<ContentRequest> contentRequests;
  final Map<String, CookSessionSnapshot> cookSessions;
}

abstract interface class LocalApplicationStore
    implements CookSessionPersistence {
  Future<void> initialize();

  Future<List<SavedRecipe>> loadSavedRecipes();
  Future<void> saveRecipe(String recipeId, {DateTime? savedAt});
  Future<void> removeSavedRecipe(String recipeId);

  Future<List<CookHistoryEntry>> loadHistory();
  Future<void> addHistory(CookHistoryEntry entry);
  Future<void> removeHistory(String id);

  Future<MealPlan> loadMealPlan();
  Future<void> assignMealPlan(MealPlanEntry entry);
  Future<void> removeMealPlan(DateTime date, MealSlot slot);
  Future<void> replaceMealPlan(MealPlan mealPlan);

  Future<List<ShoppingEntry>> loadShoppingEntries();
  Future<void> putShoppingEntry(ShoppingEntry entry);
  Future<void> removeShoppingEntry(String id);
  Future<void> replaceShoppingEntries(Iterable<ShoppingEntry> entries);

  Future<List<ShoppingInsightEvent>> loadShoppingInsightEvents();
  Future<void> addShoppingInsightEvent(ShoppingInsightEvent event);

  Future<List<ContentRequest>> loadContentRequests();
  Future<void> logContentRequest(
    String query, {
    required String languageCode,
    DateTime? searchedAt,
  });

  Future<Map<String, CookSessionSnapshot>> loadCookSessions();
  Future<LocalStoreSnapshot> snapshot();
  Future<void> replaceAll(LocalStoreSnapshot snapshot);
  Future<void> clearUserData();
  Future<void> close();
}

/// Hive CE implementation. Values are schema-stable JSON maps, so no generated
/// adapters or migrations are needed when additive fields arrive.
class HiveLocalApplicationStore implements LocalApplicationStore {
  HiveLocalApplicationStore({
    HiveInterface? hive,
    this.initializeHive = true,
    this.subDirectory = 'morphcook',
    this.boxPrefix = 'morphcook_v1',
  }) : _hive = hive ?? Hive;

  final HiveInterface _hive;
  final bool initializeHive;
  final String subDirectory;
  final String boxPrefix;

  Box<dynamic>? _saved;
  Box<dynamic>? _history;
  Box<dynamic>? _mealPlan;
  Box<dynamic>? _shopping;
  Box<dynamic>? _shoppingInsights;
  Box<dynamic>? _requests;
  Box<dynamic>? _cookSessions;
  Future<void>? _initializing;

  @override
  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    if (initializeHive) await _hive.initFlutter(subDirectory);
    _saved = await _hive.openBox<dynamic>('${boxPrefix}_saved');
    _history = await _hive.openBox<dynamic>('${boxPrefix}_history');
    _mealPlan = await _hive.openBox<dynamic>('${boxPrefix}_meal_plan');
    _shopping = await _hive.openBox<dynamic>('${boxPrefix}_shopping');
    _shoppingInsights = await _hive.openBox<dynamic>(
      '${boxPrefix}_shopping_insights',
    );
    _requests = await _hive.openBox<dynamic>('${boxPrefix}_requests');
    _cookSessions = await _hive.openBox<dynamic>('${boxPrefix}_cook_sessions');
  }

  @override
  Future<List<SavedRecipe>> loadSavedRecipes() async {
    await initialize();
    final result = _saved!.values
        .map((value) => SavedRecipe.fromJson(_jsonMap(value)))
        .toList();
    result.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return result;
  }

  @override
  Future<void> saveRecipe(String recipeId, {DateTime? savedAt}) async {
    await initialize();
    if (_saved!.containsKey(recipeId)) return;
    final value = SavedRecipe(
      recipeId: recipeId,
      savedAt: (savedAt ?? DateTime.now()).toUtc(),
    );
    await _saved!.put(recipeId, value.toJson());
  }

  @override
  Future<void> removeSavedRecipe(String recipeId) async {
    await initialize();
    await _saved!.delete(recipeId);
  }

  @override
  Future<List<CookHistoryEntry>> loadHistory() async {
    await initialize();
    final result = _history!.values
        .map((value) => CookHistoryEntry.fromJson(_jsonMap(value)))
        .toList();
    result.sort((a, b) => b.cookedAt.compareTo(a.cookedAt));
    return result;
  }

  @override
  Future<void> addHistory(CookHistoryEntry entry) async {
    await initialize();
    await _history!.put(entry.id, entry.toJson());
  }

  @override
  Future<void> removeHistory(String id) async {
    await initialize();
    await _history!.delete(id);
  }

  @override
  Future<MealPlan> loadMealPlan() async {
    await initialize();
    final weeks = <String, Map<String, String>>{};
    for (final key in _mealPlan!.keys) {
      weeks[key.toString()] = _jsonMap(
        _mealPlan!.get(key),
      ).map((slot, recipe) => MapEntry(slot, recipe.toString()));
    }
    return MealPlan.fromJson(weeks);
  }

  @override
  Future<void> assignMealPlan(MealPlanEntry entry) async {
    await initialize();
    final weekKey = isoWeekKey(entry.date);
    final week = _jsonMap(_mealPlan!.get(weekKey));
    week[entry.slotKey] = entry.recipeId;
    await _mealPlan!.put(weekKey, week);
  }

  @override
  Future<void> removeMealPlan(DateTime date, MealSlot slot) async {
    await initialize();
    final weekKey = isoWeekKey(date);
    final week = _jsonMap(_mealPlan!.get(weekKey));
    week.remove('${weekdayKey(date.weekday)}.${slot.name}');
    if (week.isEmpty) {
      await _mealPlan!.delete(weekKey);
    } else {
      await _mealPlan!.put(weekKey, week);
    }
  }

  @override
  Future<void> replaceMealPlan(MealPlan mealPlan) async {
    await initialize();
    await _mealPlan!.clear();
    await _mealPlan!.putAll(mealPlan.toBackupJson());
  }

  @override
  Future<List<ShoppingEntry>> loadShoppingEntries() async {
    await initialize();
    final result = _shopping!.values
        .map((value) => ShoppingEntry.fromJson(_jsonMap(value)))
        .toList();
    result.sort((a, b) => a.addedAt.compareTo(b.addedAt));
    return result;
  }

  @override
  Future<void> putShoppingEntry(ShoppingEntry entry) async {
    await initialize();
    await _shopping!.put(entry.id, entry.toJson());
  }

  @override
  Future<void> removeShoppingEntry(String id) async {
    await initialize();
    await _shopping!.delete(id);
  }

  @override
  Future<void> replaceShoppingEntries(Iterable<ShoppingEntry> entries) async {
    await initialize();
    await _shopping!.clear();
    await _shopping!.putAll(<String, dynamic>{
      for (final entry in entries) entry.id: entry.toJson(),
    });
  }

  @override
  Future<List<ShoppingInsightEvent>> loadShoppingInsightEvents() async {
    await initialize();
    final result = _shoppingInsights!.values
        .map((value) => ShoppingInsightEvent.fromJson(_jsonMap(value)))
        .toList();
    result.sort((a, b) => a.addedAt.compareTo(b.addedAt));
    return result;
  }

  @override
  Future<void> addShoppingInsightEvent(ShoppingInsightEvent event) async {
    await initialize();
    await _shoppingInsights!.put(event.id, event.toJson());
  }

  @override
  Future<List<ContentRequest>> loadContentRequests() async {
    await initialize();
    final result = _requests!.values
        .map((value) => ContentRequest.fromJson(_jsonMap(value)))
        .toList();
    result.sort((a, b) => b.lastSearchedAt.compareTo(a.lastSearchedAt));
    return result;
  }

  @override
  Future<void> logContentRequest(
    String query, {
    required String languageCode,
    DateTime? searchedAt,
  }) async {
    await initialize();
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final normalized = trimmed.toLowerCase();
    final language = normalizeLanguageCode(languageCode);
    final key = '$language|$normalized';
    final previousValue = _requests!.get(key);
    final previous = previousValue == null
        ? null
        : ContentRequest.fromJson(_jsonMap(previousValue));
    final request = ContentRequest(
      query: trimmed,
      languageCode: language,
      lastSearchedAt: (searchedAt ?? DateTime.now()).toUtc(),
      count: (previous?.count ?? 0) + 1,
    );
    await _requests!.put(key, request.toJson());
  }

  @override
  Future<CookSessionSnapshot?> loadCookSession(String recipeId) async {
    await initialize();
    final value = _cookSessions!.get(recipeId);
    return value == null ? null : CookSessionSnapshot.fromJson(_jsonMap(value));
  }

  @override
  Future<void> saveCookSession(CookSessionSnapshot session) async {
    await initialize();
    await _cookSessions!.put(session.recipeId, session.toJson());
  }

  @override
  Future<void> deleteCookSession(String recipeId) async {
    await initialize();
    await _cookSessions!.delete(recipeId);
  }

  @override
  Future<Map<String, CookSessionSnapshot>> loadCookSessions() async {
    await initialize();
    return <String, CookSessionSnapshot>{
      for (final key in _cookSessions!.keys)
        key.toString(): CookSessionSnapshot.fromJson(
          _jsonMap(_cookSessions!.get(key)),
        ),
    };
  }

  @override
  Future<LocalStoreSnapshot> snapshot() async {
    final values = await Future.wait<Object>(<Future<Object>>[
      loadSavedRecipes(),
      loadHistory(),
      loadMealPlan(),
      loadShoppingEntries(),
      loadShoppingInsightEvents(),
      loadContentRequests(),
      loadCookSessions(),
    ]);
    return LocalStoreSnapshot(
      savedRecipes: values[0] as List<SavedRecipe>,
      history: values[1] as List<CookHistoryEntry>,
      mealPlan: values[2] as MealPlan,
      shoppingEntries: values[3] as List<ShoppingEntry>,
      shoppingInsightEvents: values[4] as List<ShoppingInsightEvent>,
      contentRequests: values[5] as List<ContentRequest>,
      cookSessions: values[6] as Map<String, CookSessionSnapshot>,
    );
  }

  @override
  Future<void> replaceAll(LocalStoreSnapshot value) async {
    await initialize();
    await Future.wait(<Future<void>>[
      _replaceBox(_saved!, <String, dynamic>{
        for (final item in value.savedRecipes) item.recipeId: item.toJson(),
      }),
      _replaceBox(_history!, <String, dynamic>{
        for (final item in value.history) item.id: item.toJson(),
      }),
      _replaceBox(_mealPlan!, value.mealPlan.toBackupJson()),
      _replaceBox(_shopping!, <String, dynamic>{
        for (final item in value.shoppingEntries) item.id: item.toJson(),
      }),
      _replaceBox(_shoppingInsights!, <String, dynamic>{
        for (final item in value.shoppingInsightEvents) item.id: item.toJson(),
      }),
      _replaceBox(_requests!, <String, dynamic>{
        for (final item in value.contentRequests)
          '${normalizeLanguageCode(item.languageCode)}|${item.normalizedQuery}':
              item.toJson(),
      }),
      _replaceBox(_cookSessions!, <String, dynamic>{
        for (final item in value.cookSessions.entries)
          item.key: item.value.toJson(),
      }),
    ]);
  }

  @override
  Future<void> clearUserData() => replaceAll(LocalStoreSnapshot.empty());

  @override
  Future<void> close() async {
    final boxes = <Box<dynamic>?>[
      _saved,
      _history,
      _mealPlan,
      _shopping,
      _shoppingInsights,
      _requests,
      _cookSessions,
    ];
    await Future.wait(
      boxes.whereType<Box<dynamic>>().map((box) => box.close()),
    );
    _saved = null;
    _history = null;
    _mealPlan = null;
    _shopping = null;
    _shoppingInsights = null;
    _requests = null;
    _cookSessions = null;
    _initializing = null;
  }
}

/// Deterministic no-I/O implementation for previews and unit tests.
class MemoryLocalApplicationStore implements LocalApplicationStore {
  LocalStoreSnapshot _data;

  MemoryLocalApplicationStore({LocalStoreSnapshot? initial})
    : _data = initial ?? LocalStoreSnapshot.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<List<SavedRecipe>> loadSavedRecipes() async =>
      List<SavedRecipe>.of(_data.savedRecipes)
        ..sort((a, b) => b.savedAt.compareTo(a.savedAt));

  @override
  Future<void> saveRecipe(String recipeId, {DateTime? savedAt}) async {
    if (_data.savedRecipes.any((item) => item.recipeId == recipeId)) return;
    _set(
      savedRecipes: <SavedRecipe>[
        ..._data.savedRecipes,
        SavedRecipe(
          recipeId: recipeId,
          savedAt: (savedAt ?? DateTime.now()).toUtc(),
        ),
      ],
    );
  }

  @override
  Future<void> removeSavedRecipe(String recipeId) async => _set(
    savedRecipes: _data.savedRecipes
        .where((item) => item.recipeId != recipeId)
        .toList(),
  );

  @override
  Future<List<CookHistoryEntry>> loadHistory() async =>
      List<CookHistoryEntry>.of(_data.history)
        ..sort((a, b) => b.cookedAt.compareTo(a.cookedAt));

  @override
  Future<void> addHistory(CookHistoryEntry entry) async => _set(
    history: <CookHistoryEntry>[
      ..._data.history.where((item) => item.id != entry.id),
      entry,
    ],
  );

  @override
  Future<void> removeHistory(String id) async =>
      _set(history: _data.history.where((item) => item.id != id).toList());

  @override
  Future<MealPlan> loadMealPlan() async => _data.mealPlan;

  @override
  Future<void> assignMealPlan(MealPlanEntry entry) async =>
      _set(mealPlan: _data.mealPlan.assign(entry));

  @override
  Future<void> removeMealPlan(DateTime date, MealSlot slot) async =>
      _set(mealPlan: _data.mealPlan.remove(date, slot));

  @override
  Future<void> replaceMealPlan(MealPlan mealPlan) async =>
      _set(mealPlan: mealPlan);

  @override
  Future<List<ShoppingEntry>> loadShoppingEntries() async =>
      List<ShoppingEntry>.of(_data.shoppingEntries);

  @override
  Future<void> putShoppingEntry(ShoppingEntry entry) async => _set(
    shoppingEntries: <ShoppingEntry>[
      ..._data.shoppingEntries.where((item) => item.id != entry.id),
      entry,
    ],
  );

  @override
  Future<void> removeShoppingEntry(String id) async => _set(
    shoppingEntries: _data.shoppingEntries
        .where((item) => item.id != id)
        .toList(),
  );

  @override
  Future<void> replaceShoppingEntries(Iterable<ShoppingEntry> entries) async =>
      _set(shoppingEntries: entries.toList());

  @override
  Future<List<ShoppingInsightEvent>> loadShoppingInsightEvents() async =>
      List<ShoppingInsightEvent>.of(_data.shoppingInsightEvents);

  @override
  Future<void> addShoppingInsightEvent(ShoppingInsightEvent event) async =>
      _set(
        shoppingInsightEvents: <ShoppingInsightEvent>[
          ..._data.shoppingInsightEvents.where((item) => item.id != event.id),
          event,
        ],
      );

  @override
  Future<List<ContentRequest>> loadContentRequests() async =>
      List<ContentRequest>.of(_data.contentRequests);

  @override
  Future<void> logContentRequest(
    String query, {
    required String languageCode,
    DateTime? searchedAt,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final normalized = trimmed.toLowerCase();
    final language = normalizeLanguageCode(languageCode);
    final existing = _data.contentRequests.where(
      (item) =>
          item.normalizedQuery == normalized &&
          normalizeLanguageCode(item.languageCode) == language,
    );
    final previous = existing.isEmpty ? null : existing.first;
    _set(
      contentRequests: <ContentRequest>[
        ..._data.contentRequests.where((item) => item != previous),
        ContentRequest(
          query: trimmed,
          languageCode: language,
          lastSearchedAt: (searchedAt ?? DateTime.now()).toUtc(),
          count: (previous?.count ?? 0) + 1,
        ),
      ],
    );
  }

  @override
  Future<CookSessionSnapshot?> loadCookSession(String recipeId) async =>
      _data.cookSessions[recipeId];

  @override
  Future<void> saveCookSession(CookSessionSnapshot session) async => _set(
    cookSessions: <String, CookSessionSnapshot>{
      ..._data.cookSessions,
      session.recipeId: session,
    },
  );

  @override
  Future<void> deleteCookSession(String recipeId) async {
    final sessions = Map<String, CookSessionSnapshot>.from(_data.cookSessions)
      ..remove(recipeId);
    _set(cookSessions: sessions);
  }

  @override
  Future<Map<String, CookSessionSnapshot>> loadCookSessions() async =>
      Map<String, CookSessionSnapshot>.of(_data.cookSessions);

  @override
  Future<LocalStoreSnapshot> snapshot() async => _data;

  @override
  Future<void> replaceAll(LocalStoreSnapshot snapshot) async =>
      _data = snapshot;

  @override
  Future<void> clearUserData() async => _data = LocalStoreSnapshot.empty();

  @override
  Future<void> close() async {}

  void _set({
    List<SavedRecipe>? savedRecipes,
    List<CookHistoryEntry>? history,
    MealPlan? mealPlan,
    List<ShoppingEntry>? shoppingEntries,
    List<ShoppingInsightEvent>? shoppingInsightEvents,
    List<ContentRequest>? contentRequests,
    Map<String, CookSessionSnapshot>? cookSessions,
  }) {
    _data = LocalStoreSnapshot(
      savedRecipes: savedRecipes ?? _data.savedRecipes,
      history: history ?? _data.history,
      mealPlan: mealPlan ?? _data.mealPlan,
      shoppingEntries: shoppingEntries ?? _data.shoppingEntries,
      shoppingInsightEvents:
          shoppingInsightEvents ?? _data.shoppingInsightEvents,
      contentRequests: contentRequests ?? _data.contentRequests,
      cookSessions: cookSessions ?? _data.cookSessions,
    );
  }
}

Future<void> _replaceBox(Box<dynamic> box, Map<dynamic, dynamic> values) async {
  // Stage new values before deleting stale keys. A failed write therefore
  // leaves the previous snapshot readable instead of clearing user data.
  await box.putAll(values);
  final staleKeys = box.keys.where((key) => !values.containsKey(key)).toList();
  if (staleKeys.isNotEmpty) await box.deleteAll(staleKeys);
}

Map<String, dynamic> _jsonMap(Object? value) {
  if (value == null) return <String, dynamic>{};
  return (value as Map).map(
    (key, item) => MapEntry(key.toString(), _jsonValue(item)),
  );
}

Object? _jsonValue(Object? value) {
  if (value is Map) return _jsonMap(value);
  if (value is List) return value.map(_jsonValue).toList();
  return value;
}

String isoWeekKey(DateTime value) {
  // Calendar arithmetic must stay in UTC: local DST transitions can turn an
  // exact number of weeks into N weeks minus one hour and undercount it.
  final date = DateTime.utc(value.year, value.month, value.day);
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final yearStart = DateTime.utc(thursday.year, 1, 1);
  final week = 1 + (thursday.difference(yearStart).inDays ~/ 7);
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

String weekdayKey(int weekday) => const <String>[
  'mon',
  'tue',
  'wed',
  'thu',
  'fri',
  'sat',
  'sun',
][weekday - 1];
