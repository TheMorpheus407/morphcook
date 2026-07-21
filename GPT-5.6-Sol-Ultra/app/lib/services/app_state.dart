import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:morphcook/domain/models.dart';
import 'package:uuid/uuid.dart';

import 'cook_session_controller.dart';
import 'local_store.dart';
import 'profile_store.dart';
import 'shopping_service.dart';

typedef AppStateIdGenerator = String Function();

class CookModeControllers {
  const CookModeControllers({required this.session, required this.oneHanded});

  final CookSessionController session;
  final OneHandedCookModeController oneHanded;

  void dispose() {
    oneHanded.dispose();
    session.dispose();
  }
}

/// The deliberately small application orchestrator exposed to Provider.
///
/// Corpus/search repositories stay outside this class. AppState owns only
/// mutable, offline user data and coordinates its persistence.
class AppState extends ChangeNotifier {
  AppState({
    required this.profileStore,
    required this.localStore,
    ShoppingListService shoppingListService = const ShoppingListService(),
    AppStateIdGenerator? idGenerator,
  }) : _shoppingListService = shoppingListService,
       _idGenerator = idGenerator ?? const Uuid().v4;

  final ProfileStore profileStore;
  final LocalApplicationStore localStore;
  final ShoppingListService _shoppingListService;
  final AppStateIdGenerator _idGenerator;

  UserProfile? _profile;
  AppSettings _settings = const AppSettings();
  List<SavedRecipe> _savedRecipes = <SavedRecipe>[];
  List<CookHistoryEntry> _history = <CookHistoryEntry>[];
  MealPlan _mealPlan = MealPlan.empty();
  List<ShoppingEntry> _shoppingEntries = <ShoppingEntry>[];
  List<ShoppingInsightEvent> _shoppingInsightEvents = <ShoppingInsightEvent>[];
  List<ContentRequest> _contentRequests = <ContentRequest>[];
  bool _isInitializing = false;
  bool _isInitialized = false;
  bool _isMutating = false;
  Object? _lastError;
  Future<void>? _initialization;
  Future<void> _mutationQueue = Future<void>.value();

  UserProfile? get profile => _profile;
  AppSettings get settings => _settings;
  bool get isInitializing => _isInitializing;
  bool get isInitialized => _isInitialized;
  bool get isMutating => _isMutating;
  Object? get lastError => _lastError;
  bool get needsOnboarding => !_settings.onboardingComplete || _profile == null;
  UnmodifiableListView<SavedRecipe> get savedRecipes =>
      UnmodifiableListView<SavedRecipe>(_savedRecipes);
  Set<String> get savedRecipeIds =>
      Set<String>.unmodifiable(_savedRecipes.map((item) => item.recipeId));
  UnmodifiableListView<CookHistoryEntry> get cookingHistory =>
      UnmodifiableListView<CookHistoryEntry>(_history);
  MealPlan get mealPlan => _mealPlan;
  UnmodifiableListView<ShoppingEntry> get shoppingEntries =>
      UnmodifiableListView<ShoppingEntry>(_shoppingEntries);
  ShoppingInsights get shoppingInsights =>
      _shoppingListService.insightsFromEvents(_shoppingInsightEvents);
  SplayTreeMap<String, List<ShoppingEntry>> get shoppingEntriesByAisle =>
      _shoppingListService.groupByAisle(_shoppingEntries);
  UnmodifiableListView<ContentRequest> get contentRequests =>
      UnmodifiableListView<ContentRequest>(_contentRequests);

  bool isSaved(String recipeId) =>
      _savedRecipes.any((item) => item.recipeId == recipeId);

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    _isInitializing = true;
    _lastError = null;
    notifyListeners();
    try {
      await localStore.initialize();
      final values = await Future.wait<Object?>(<Future<Object?>>[
        profileStore.loadProfile(),
        profileStore.loadSettings(),
        localStore.snapshot(),
      ]);
      _profile = values[0] as UserProfile?;
      _settings = values[1]! as AppSettings;
      final local = await _migrateInsightEvents(
        values[2]! as LocalStoreSnapshot,
      );
      _applyLocalSnapshot(local);
      _isInitialized = true;
    } catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> reload() async {
    await initialize();
    final values = await Future.wait<Object?>(<Future<Object?>>[
      profileStore.loadProfile(),
      profileStore.loadSettings(),
      localStore.snapshot(),
    ]);
    _profile = values[0] as UserProfile?;
    _settings = values[1]! as AppSettings;
    final local = await _migrateInsightEvents(values[2]! as LocalStoreSnapshot);
    _applyLocalSnapshot(local);
    notifyListeners();
  }

  Future<void> updateProfile(UserProfile profile) => _mutate(() async {
    await profileStore.saveProfile(profile);
    _profile = profile;
  });

  Future<void> completeOnboarding(UserProfile profile) => _mutate(() async {
    final settings = _settings.copyWith(onboardingComplete: true);
    await profileStore.saveProfile(profile);
    await profileStore.saveSettings(settings);
    _profile = profile;
    _settings = settings;
  });

  Future<void> setQuickNextTapEnabled(bool enabled) => _mutate(() async {
    final settings = _settings.copyWith(quickNextTapEnabled: enabled);
    await profileStore.saveSettings(settings);
    _settings = settings;
  });

  Future<void> dismissHint(String hintId) => _mutate(() async {
    final settings = _settings.copyWith(
      dismissedHints: <String>{..._settings.dismissedHints, hintId},
    );
    await profileStore.saveSettings(settings);
    _settings = settings;
  });

  Future<bool> toggleSaved(String recipeId) async {
    var nowSaved = false;
    await _mutate(() async {
      nowSaved = !isSaved(recipeId);
      if (nowSaved) {
        final value = SavedRecipe(
          recipeId: recipeId,
          savedAt: DateTime.now().toUtc(),
        );
        await localStore.saveRecipe(recipeId, savedAt: value.savedAt);
        _savedRecipes = <SavedRecipe>[value, ..._savedRecipes];
      } else {
        await localStore.removeSavedRecipe(recipeId);
        _savedRecipes = _savedRecipes
            .where((item) => item.recipeId != recipeId)
            .toList();
      }
    });
    return nowSaved;
  }

  Future<CookHistoryEntry> recordCooked(
    String recipeId, {
    String? entryId,
    int servings = 1,
    bool completed = true,
    Duration? duration,
    DateTime? cookedAt,
  }) async {
    final entry = CookHistoryEntry(
      id: entryId ?? _idGenerator(),
      recipeId: recipeId,
      cookedAt: (cookedAt ?? DateTime.now()).toUtc(),
      servings: servings,
      completed: completed,
      durationSeconds: duration?.inSeconds,
    );
    await _mutate(() async {
      await localStore.addHistory(entry);
      _history = <CookHistoryEntry>[
        entry,
        ..._history.where((item) => item.id != entry.id),
      ];
    });
    return entry;
  }

  Future<void> removeHistory(String id) => _mutate(() async {
    await localStore.removeHistory(id);
    _history = _history.where((item) => item.id != id).toList();
  });

  Future<void> assignMealPlanSlot({
    required DateTime date,
    required MealSlot slot,
    required String recipeId,
  }) => _mutate(() async {
    final entry = MealPlanEntry(
      id: _idGenerator(),
      date: date,
      slot: slot,
      recipeId: recipeId,
    );
    await localStore.assignMealPlan(entry);
    _mealPlan = _mealPlan.assign(entry);
  });

  Future<void> removeMealPlanSlot(DateTime date, MealSlot slot) =>
      _mutate(() async {
        await localStore.removeMealPlan(date, slot);
        _mealPlan = _mealPlan.remove(date, slot);
      });

  Future<void> moveMealPlanSlot({
    required DateTime fromDate,
    required MealSlot fromSlot,
    required DateTime toDate,
    required MealSlot toSlot,
  }) => _mutate(() async {
    final moved = _mealPlan.move(
      fromDate: fromDate,
      fromSlot: fromSlot,
      toDate: toDate,
      toSlot: toSlot,
    );
    await localStore.replaceMealPlan(moved);
    _mealPlan = moved;
  });

  Future<void> addShoppingIngredients(
    Iterable<ShoppingIngredientInput> inputs,
  ) => _mutate(() async {
    final additions = _shoppingListService.aggregate(inputs);
    await _recordShoppingEvents(additions);
    await _mergeShoppingAdditions(additions);
  });

  Future<void> addRecipesToShoppingList(
    Iterable<Recipe> recipes, {
    required IngredientDictionary ingredientDictionary,
    Map<String, double> servingsByRecipeId = const <String, double>{},
  }) => _mutate(() async {
    final additions = _shoppingListService.aggregateRecipes(
      recipes,
      ingredientDictionary: ingredientDictionary,
      languageCode: _profile?.languageCode ?? 'en',
      servingsByRecipeId: servingsByRecipeId,
    );
    await _recordShoppingEvents(additions);
    await _mergeShoppingAdditions(additions);
  });

  Future<void> upsertShoppingEntry(ShoppingEntry entry) => _mutate(() async {
    if (!_shoppingEntries.any((item) => item.id == entry.id)) {
      await _recordShoppingEvents(<ShoppingEntry>[entry]);
    }
    await localStore.putShoppingEntry(entry);
    _shoppingEntries = <ShoppingEntry>[
      ..._shoppingEntries.where((item) => item.id != entry.id),
      entry,
    ];
  });

  Future<void> setShoppingChecked(String id, bool checked) => _mutate(() async {
    final index = _shoppingEntries.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final updated = _shoppingEntries[index].copyWith(isChecked: checked);
    await localStore.putShoppingEntry(updated);
    _shoppingEntries = List<ShoppingEntry>.of(_shoppingEntries)
      ..[index] = updated;
  });

  Future<void> removeShoppingEntry(String id) => _mutate(() async {
    await localStore.removeShoppingEntry(id);
    _shoppingEntries = _shoppingEntries.where((item) => item.id != id).toList();
  });

  Future<void> clearCheckedShoppingEntries() => _mutate(() async {
    final remaining = _shoppingEntries
        .where((item) => !item.isChecked)
        .toList();
    await localStore.replaceShoppingEntries(remaining);
    _shoppingEntries = remaining;
  });

  Future<void> logContentRequest(String query) => _mutate(() async {
    final language = _profile?.languageCode ?? 'en';
    await localStore.logContentRequest(query, languageCode: language);
    _contentRequests = await localStore.loadContentRequests();
  });

  Future<CookModeControllers> createCookModeControllers(
    Recipe recipe, {
    CookHaptics haptics = const FlutterCookHaptics(),
    bool systemReduceMotion = false,
  }) async {
    if (recipe.steps.isEmpty) {
      throw ArgumentError.value(recipe.id, 'recipe', 'Recipe has no steps.');
    }
    final session = await CookSessionController.restore(
      recipeId: recipe.id,
      baseServings: recipe.servings.toDouble(),
      totalSteps: recipe.steps.length,
      persistence: localStore,
      visualAlertEnabled: _profile?.visualAlertEnabled ?? true,
      reduceMotion: _profile?.reduceMotion ?? systemReduceMotion,
    );
    return CookModeControllers(
      session: session,
      oneHanded: OneHandedCookModeController(
        session: session,
        haptics: haptics,
        quickNextTapEnabled: _settings.quickNextTapEnabled,
      ),
    );
  }

  Future<void> resetAllUserData() => _mutate(() async {
    await localStore.clearUserData();
    await profileStore.clear();
    _profile = null;
    _settings = const AppSettings();
    _applyLocalSnapshot(LocalStoreSnapshot.empty());
  });

  Future<void> shutdown() => localStore.close();

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  void _applyLocalSnapshot(LocalStoreSnapshot value) {
    _savedRecipes = List<SavedRecipe>.of(value.savedRecipes)
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    _history = List<CookHistoryEntry>.of(value.history)
      ..sort((a, b) => b.cookedAt.compareTo(a.cookedAt));
    _mealPlan = value.mealPlan;
    _shoppingEntries = List<ShoppingEntry>.of(value.shoppingEntries);
    _shoppingInsightEvents = List<ShoppingInsightEvent>.of(
      value.shoppingInsightEvents,
    );
    _contentRequests = List<ContentRequest>.of(value.contentRequests);
  }

  Future<LocalStoreSnapshot> _migrateInsightEvents(
    LocalStoreSnapshot snapshot,
  ) async {
    if (snapshot.shoppingInsightEvents.isNotEmpty ||
        snapshot.shoppingEntries.isEmpty) {
      return snapshot;
    }
    final migrated = <ShoppingInsightEvent>[
      for (final entry in snapshot.shoppingEntries)
        ShoppingInsightEvent(
          id: 'legacy:${entry.id}:${entry.addedAt.microsecondsSinceEpoch}',
          ingredientId: entry.ingredientId,
          name: entry.name,
          count: entry.additionCount,
          addedAt: entry.addedAt,
        ),
    ];
    for (final event in migrated) {
      await localStore.addShoppingInsightEvent(event);
    }
    return LocalStoreSnapshot(
      savedRecipes: snapshot.savedRecipes,
      history: snapshot.history,
      mealPlan: snapshot.mealPlan,
      shoppingEntries: snapshot.shoppingEntries,
      shoppingInsightEvents: migrated,
      contentRequests: snapshot.contentRequests,
      cookSessions: snapshot.cookSessions,
    );
  }

  Future<void> _recordShoppingEvents(Iterable<ShoppingEntry> entries) async {
    for (final entry in entries) {
      final event = ShoppingInsightEvent(
        id: 'event:${entry.id}:${entry.addedAt.microsecondsSinceEpoch}:${_idGenerator()}',
        ingredientId: entry.ingredientId,
        name: entry.name,
        count: entry.additionCount,
        addedAt: entry.addedAt,
      );
      await localStore.addShoppingInsightEvent(event);
      _shoppingInsightEvents = <ShoppingInsightEvent>[
        ..._shoppingInsightEvents,
        event,
      ];
    }
  }

  Future<void> _mutate(Future<void> Function() operation) {
    final queued = _mutationQueue.then((_) => _runMutation(operation));
    // Keep the internal queue usable after surfacing an operation error to its
    // original caller.
    _mutationQueue = queued.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return queued;
  }

  Future<void> _runMutation(Future<void> Function() operation) async {
    await initialize();
    _isMutating = true;
    _lastError = null;
    notifyListeners();
    try {
      await operation();
    } catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<void> _mergeShoppingAdditions(
    Iterable<ShoppingEntry> additions,
  ) async {
    final combined = _shoppingListService.deduplicate(<ShoppingEntry>[
      ..._shoppingEntries,
      ...additions,
    ]);
    await localStore.replaceShoppingEntries(combined);
    _shoppingEntries = combined;
  }
}
