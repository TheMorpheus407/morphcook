import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dish.dart';
import '../models/faq.dart';
import '../models/history_entry.dart';
import '../models/ingredient_dictionary.dart';
import '../models/ingredient_guide.dart';
import '../models/localized_text.dart';
import '../models/ontology.dart';
import '../models/profile.dart';
import '../models/recipe.dart';
import '../models/shopping_item.dart';
import '../services/backup_service.dart';
import '../services/corpus_repository.dart';
import '../services/matching_engine.dart';
import '../services/one_handed_cook_mode_controller.dart';
import '../services/shopping_aggregator.dart';

class MorphCookAppState extends ChangeNotifier {
  static const _kProfileKey = 'morphcook.profile';
  static const _kSavedKey = 'morphcook.saved';
  static const _kMealPlanKey = 'morphcook.meal_plan';
  static const _kHistoryKey = 'morphcook.history';
  static const _kShoppingKey = 'morphcook.shopping';
  static const _kShoppingLogsKey = 'morphcook.shopping_logs';
  static const _kContentRequestsKey = 'morphcook.content_requests';
  static const _kActiveCookSessionKey = 'morphcook.active_cook_session';

  final CorpusRepository corpus;
  final OneHandedCookModeController cookModeController;

  SharedPreferences? _prefs;
  bool _initialized = false;

  UserProfile _profile = const UserProfile();
  List<String> _savedRecipeIds = [];
  Map<String, Map<String, String>> _mealPlan = {};
  List<CookHistoryEntry> _history = [];
  List<ShoppingItem> _shoppingItems = [];
  List<ShoppingLogEntry> _shoppingLogs = [];
  List<String> _contentRequests = [];
  ActiveCookSession? _activeCookSession;
  DateTime Function() _clock;

  MorphCookAppState({
    CorpusRepository? corpus,
    OneHandedCookModeController? cookModeController,
    DateTime Function()? clock,
  })  : corpus = corpus ?? CorpusRepository(),
        cookModeController =
            cookModeController ?? OneHandedCookModeController(),
        _clock = clock ?? DateTime.now;

  bool get isInitialized => _initialized;
  UserProfile get profile => _profile;
  String get lang => _profile.lang;
  Ontology get ontology => corpus.ontology;
  IngredientDictionary get ingredients => corpus.ingredients;
  IngredientGuide get ingredientGuide => corpus.ingredientGuide;
  FaqCatalog get faqs => corpus.faqs;

  List<String> get savedRecipeIds => List<String>.unmodifiable(_savedRecipeIds);
  Map<String, Map<String, String>> get mealPlan => _mealPlan;
  List<CookHistoryEntry> get history =>
      List<CookHistoryEntry>.unmodifiable(_history);
  List<ShoppingItem> get shoppingItems =>
      List<ShoppingItem>.unmodifiable(_shoppingItems);
  List<ShoppingLogEntry> get shoppingLogs =>
      List<ShoppingLogEntry>.unmodifiable(_shoppingLogs);
  List<String> get contentRequests =>
      List<String>.unmodifiable(_contentRequests);
  ActiveCookSession? get activeCookSession => _activeCookSession;

  DateTime get now => _clock();
  set clock(DateTime Function() fn) {
    _clock = fn;
    notifyListeners();
  }

  /// Initializes the bundled corpus and restores user state from SharedPreferences.
  Future<void> initialize({SharedPreferences? prefs}) async {
    _prefs = prefs ?? await SharedPreferences.getInstance();
    await corpus.initialize();
    _loadFromPrefs();
    _syncCookModeController();
    _initialized = true;
    notifyListeners();
  }

  /// Fast synchronous initialization for widget/unit tests with an already-initialized corpus.
  void initializeForTesting({
    UserProfile? initialProfile,
    List<String>? savedRecipeIds,
    Map<String, Map<String, String>>? mealPlan,
    List<CookHistoryEntry>? history,
    List<ShoppingItem>? shoppingItems,
    List<ShoppingLogEntry>? shoppingLogs,
    List<String>? contentRequests,
    ActiveCookSession? activeCookSession,
    SharedPreferences? prefs,
  }) {
    _prefs = prefs;
    if (initialProfile != null) _profile = initialProfile;
    if (savedRecipeIds != null) _savedRecipeIds = List.from(savedRecipeIds);
    if (mealPlan != null) {
      _mealPlan = {
        for (final e in mealPlan.entries) e.key: Map<String, String>.from(e.value),
      };
    }
    if (history != null) _history = List.from(history);
    if (shoppingItems != null) _shoppingItems = List.from(shoppingItems);
    if (shoppingLogs != null) _shoppingLogs = List.from(shoppingLogs);
    if (contentRequests != null) _contentRequests = List.from(contentRequests);
    _activeCookSession = activeCookSession;
    _syncCookModeController();
    _initialized = true;
    notifyListeners();
  }

  void _loadFromPrefs() {
    final prefs = _prefs;
    if (prefs == null) return;

    final profileRaw = prefs.getString(_kProfileKey);
    if (profileRaw != null) {
      try {
        _profile = UserProfile.fromJson(
          jsonDecode(profileRaw) as Map<String, dynamic>,
        );
      } catch (_) {}
    }

    final savedRaw = prefs.getStringList(_kSavedKey);
    if (savedRaw != null) {
      _savedRecipeIds = List<String>.from(savedRaw);
    }

    final mealPlanRaw = prefs.getString(_kMealPlanKey);
    if (mealPlanRaw != null) {
      try {
        final decoded = jsonDecode(mealPlanRaw) as Map<String, dynamic>;
        _mealPlan = decoded.map((week, slots) {
          final slotMap = (slots as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, v.toString()),
          );
          return MapEntry(week, slotMap);
        });
      } catch (_) {}
    }

    final historyRaw = prefs.getString(_kHistoryKey);
    if (historyRaw != null) {
      try {
        final list = jsonDecode(historyRaw) as List<dynamic>;
        _history = list
            .map((e) => CookHistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    final shoppingRaw = prefs.getString(_kShoppingKey);
    if (shoppingRaw != null) {
      try {
        final list = jsonDecode(shoppingRaw) as List<dynamic>;
        _shoppingItems = list
            .map((e) => ShoppingItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    final shoppingLogsRaw = prefs.getString(_kShoppingLogsKey);
    if (shoppingLogsRaw != null) {
      try {
        final list = jsonDecode(shoppingLogsRaw) as List<dynamic>;
        _shoppingLogs = list
            .map((e) => ShoppingLogEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    final requestsRaw = prefs.getStringList(_kContentRequestsKey);
    if (requestsRaw != null) {
      _contentRequests = List<String>.from(requestsRaw);
    }

    final sessionRaw = prefs.getString(_kActiveCookSessionKey);
    if (sessionRaw != null) {
      try {
        _activeCookSession = ActiveCookSession.fromJson(
          jsonDecode(sessionRaw) as Map<String, dynamic>,
        );
      } catch (_) {}
    }
  }

  Future<void> _persist() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(_kProfileKey, jsonEncode(_profile.toJson()));
    await prefs.setStringList(_kSavedKey, _savedRecipeIds);
    await prefs.setString(_kMealPlanKey, jsonEncode(_mealPlan));
    await prefs.setString(
      _kHistoryKey,
      jsonEncode(_history.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _kShoppingKey,
      jsonEncode(_shoppingItems.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _kShoppingLogsKey,
      jsonEncode(_shoppingLogs.map((e) => e.toJson()).toList()),
    );
    await prefs.setStringList(_kContentRequestsKey, _contentRequests);
    if (_activeCookSession != null) {
      await prefs.setString(
        _kActiveCookSessionKey,
        jsonEncode(_activeCookSession!.toJson()),
      );
    } else {
      await prefs.remove(_kActiveCookSessionKey);
    }
  }

  void _syncCookModeController() {
    cookModeController.quickNextTapEnabled = _profile.quickNextTapEnabled;
    cookModeController.visualAlertEnabled = _profile.visualAlertEnabled;
    cookModeController.reduceMotion = _profile.reduceMotion;
  }

  Future<void> updateProfile(UserProfile updated) async {
    _profile = updated;
    _syncCookModeController();
    notifyListeners();
    await _persist();
  }

  Future<void> setLanguage(String newLang) async {
    await updateProfile(_profile.copyWith(lang: newLang));
  }

  Future<void> completeOnboarding(UserProfile updated) async {
    await updateProfile(updated.copyWith(onboardingCompleted: true));
  }

  Map<String, DateTime> get lastCookedByRecipeId {
    final map = <String, DateTime>{};
    for (final entry in _history) {
      final existing = map[entry.recipeId];
      if (existing == null || entry.cookedAt.isAfter(existing)) {
        map[entry.recipeId] = entry.cookedAt;
      }
    }
    return map;
  }

  /// Returns all dishes with their best-matching visible variant for the user's
  /// current profile, sorted by contextual score (including Time-Aware and
  /// Staleness-Aware bonuses).
  List<({Dish dish, Recipe variant, double score})> getRankedDishes({
    String? partitionFilter,
  }) {
    final lastCooked = lastCookedByRecipeId;
    final currentTime = now;
    final results = <({Dish dish, Recipe variant, double score})>[];

    for (final dish in corpus.dishes) {
      if (partitionFilter != null && partitionFilter.isNotEmpty) {
        final matchesPartition = dish.partitionId == partitionFilter ||
            dish.secondaryPartitions.contains(partitionFilter) ||
            dish.cuisineTags.contains(partitionFilter);
        if (!matchesPartition) continue;
      }

      final variants = corpus.loadedVariantsForDish(dish.id);
      if (variants.isEmpty) continue;

      var best = MatchingEngine.selectBestVariant(
        variants,
        _profile,
        ontology: ontology,
        dictionary: ingredients,
        ignoreCalorieFilter: !_profile.calorieFilterEnabled,
        now: currentTime,
        lastCookedByRecipeId: lastCooked,
        dish: dish,
      );

      // If strict calorie/time filter excluded every variant, try ignoring calorie filter
      // only if no variant matched, or skip if hard-filtered.
      best ??= MatchingEngine.selectBestVariant(
        variants,
        _profile.copyWith(maxTimeMinutes: 120),
        ontology: ontology,
        dictionary: ingredients,
        ignoreCalorieFilter: true,
        now: currentTime,
        lastCookedByRecipeId: lastCooked,
        dish: dish,
      );

      if (best != null) {
        final score = MatchingEngine.scoreRecipe(
          best,
          _profile,
          now: currentTime,
          lastCookedAt: lastCooked[best.id],
          dish: dish,
        );
        results.add((dish: dish, variant: best, score: score));
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  /// Loads a lazy partition (e.g., `extended`, `cuisine-italian`, `cuisine-asian`,
  /// `cuisine-middle-eastern`) and notifies listeners.
  Future<void> ensurePartitionLoaded(String partitionId) async {
    await corpus.loadPartition(partitionId);
    notifyListeners();
  }

  // ==================== COOKBOOK (SAVED VARIANTS) ====================

  bool isRecipeSaved(String recipeId) => _savedRecipeIds.contains(recipeId);

  Future<void> toggleSaveRecipe(String recipeId) async {
    if (_savedRecipeIds.contains(recipeId)) {
      _savedRecipeIds.remove(recipeId);
    } else {
      _savedRecipeIds.insert(0, recipeId);
    }
    notifyListeners();
    await _persist();
  }

  List<Recipe> get savedRecipes {
    final list = <Recipe>[];
    for (final id in _savedRecipeIds) {
      final r = corpus.recipeById(id);
      if (r != null) list.add(r);
    }
    return list;
  }

  // ==================== COOKING HISTORY & COOK MODE SESSION ====================

  Future<void> recordCookedRecipe(
    Recipe recipe, {
    int? servingsCooked,
    String? notes,
    DateTime? cookedAt,
  }) async {
    final timestamp = cookedAt ?? now;
    final entry = CookHistoryEntry(
      id: '${recipe.id}_${timestamp.millisecondsSinceEpoch}',
      recipeId: recipe.id,
      dishId: recipe.dishId,
      cookedAt: timestamp,
      servingsCooked: servingsCooked ?? recipe.servings,
      notes: notes,
    );
    _history.insert(0, entry);
    if (_activeCookSession?.recipeId == recipe.id) {
      _activeCookSession = null;
    }
    notifyListeners();
    await _persist();
  }

  Future<void> saveCookSession(ActiveCookSession? session) async {
    _activeCookSession = session;
    notifyListeners();
    await _persist();
  }

  // ==================== SMART SHOPPING LIST & INSIGHTS ====================

  Future<void> addRecipeToShoppingList(
    Recipe recipe, {
    int? targetServings,
  }) async {
    final scale = (targetServings ?? recipe.servings) / recipe.servings;
    _shoppingItems = ShoppingAggregator.mergeIngredients(
      existing: _shoppingItems,
      incoming: recipe.ingredients,
      sourceRecipeId: recipe.id,
      scaleFactor: scale,
    );
    final timestamp = now;
    for (final ing in recipe.ingredients) {
      _shoppingLogs.add(
        ShoppingLogEntry(
          ingredientId: ing.id,
          name: ing.name,
          addedAt: timestamp,
          aisle: ing.aisle,
        ),
      );
    }
    notifyListeners();
    await _persist();
  }

  Future<void> addCustomShoppingItem({
    required String name,
    required double amount,
    required String unit,
    String aisle = 'pantry',
  }) async {
    final cleanId = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
    final localized = LocalizedText({'en': name.trim(), 'de': name.trim()});
    final ing = RecipeIngredient(
      id: cleanId,
      name: localized,
      amount: amount,
      unit: unit,
      aisle: aisle,
    );
    _shoppingItems = ShoppingAggregator.mergeIngredients(
      existing: _shoppingItems,
      incoming: [ing],
    );
    _shoppingLogs.add(
      ShoppingLogEntry(
        ingredientId: cleanId,
        name: localized,
        addedAt: now,
        aisle: aisle,
      ),
    );
    notifyListeners();
    await _persist();
  }

  Future<void> toggleShoppingItemChecked(String itemId) async {
    final idx = _shoppingItems.indexWhere((i) => i.id == itemId);
    if (idx < 0) return;
    _shoppingItems[idx] =
        _shoppingItems[idx].copyWith(checked: !_shoppingItems[idx].checked);
    notifyListeners();
    await _persist();
  }

  Future<void> clearCheckedShoppingItems() async {
    _shoppingItems.removeWhere((i) => i.checked);
    notifyListeners();
    await _persist();
  }

  Future<void> clearAllShoppingItems() async {
    _shoppingItems.clear();
    notifyListeners();
    await _persist();
  }

  ShoppingInsightsData get shoppingInsights =>
      ShoppingAggregator.computeInsights(_shoppingLogs, _shoppingItems);

  // ==================== MEAL PLANNING ====================

  static String isoWeekKey(DateTime date) {
    // ISO 8601 week calculation
    final thursday =
        date.add(Duration(days: DateTime.thursday - date.weekday));
    final firstJan = DateTime(thursday.year, 1, 1);
    final weekNumber =
        ((thursday.difference(firstJan).inDays) / 7).floor() + 1;
    return '${thursday.year}-W${weekNumber.toString().padLeft(2, '0')}';
  }

  Map<String, String> slotsForWeek(String weekKey) {
    return Map<String, String>.unmodifiable(_mealPlan[weekKey] ?? const {});
  }

  Future<void> assignMealSlot({
    required String weekKey,
    required String slotKey, // e.g. 'mon.dinner'
    required String? recipeId,
  }) async {
    final weekMap = Map<String, String>.from(_mealPlan[weekKey] ?? {});
    if (recipeId == null || recipeId.isEmpty) {
      weekMap.remove(slotKey);
    } else {
      weekMap[slotKey] = recipeId;
    }
    _mealPlan[weekKey] = weekMap;
    notifyListeners();
    await _persist();
  }

  Future<void> moveOrSwapMealSlot({
    required String weekKey,
    required String fromSlotKey,
    required String toSlotKey,
  }) async {
    if (fromSlotKey == toSlotKey) return;
    final weekMap = Map<String, String>.from(_mealPlan[weekKey] ?? {});
    final fromRecipe = weekMap[fromSlotKey];
    if (fromRecipe == null) return;
    final toRecipe = weekMap[toSlotKey];
    weekMap[toSlotKey] = fromRecipe;
    if (toRecipe != null) {
      weekMap[fromSlotKey] = toRecipe;
    } else {
      weekMap.remove(fromSlotKey);
    }
    _mealPlan[weekKey] = weekMap;
    notifyListeners();
    await _persist();
  }

  /// Exports all assigned recipes in [weekKey] into the Smart Shopping List
  /// with unit-aware aggregation.
  Future<int> exportWeekMealPlanToShoppingList(String weekKey) async {
    await corpus.ensureAllPartitionsLoaded();
    final weekMap = _mealPlan[weekKey] ?? const {};
    int addedCount = 0;
    for (final recipeId in weekMap.values) {
      final recipe = corpus.recipeById(recipeId);
      if (recipe != null) {
        await addRecipeToShoppingList(recipe);
        addedCount++;
      }
    }
    return addedCount;
  }

  // ==================== ZERO-RESULT CONTENT REQUESTS ====================

  Future<void> logContentRequest(String query) async {
    final cleaned = query.trim().toLowerCase();
    if (cleaned.length < 2) return;
    if (!_contentRequests.contains(cleaned)) {
      _contentRequests.add(cleaned);
      notifyListeners();
      await _persist();
    }
  }

  // ==================== BACKUP & RESTORE ====================

  BackupPayload buildBackupPayload() {
    return BackupPayload(
      schemaVersion: 1,
      exportedAt: now.toUtc(),
      profile: _profile,
      saved: List<String>.from(_savedRecipeIds),
      mealPlan: {
        for (final entry in _mealPlan.entries)
          entry.key: Map<String, String>.from(entry.value),
      },
      history: List<CookHistoryEntry>.from(_history),
      contentRequests: List<String>.from(_contentRequests),
    );
  }

  Future<BackupExportResult> exportBackup({
    String? password,
    Directory? targetDirectory,
  }) {
    return BackupService.exportBackup(
      buildBackupPayload(),
      password: password,
      targetDirectory: targetDirectory,
    );
  }

  Future<void> restoreFromBackupBytes(
    Uint8List bytes, {
    String? password,
    RestoreMode mode = RestoreMode.replace,
  }) async {
    final BackupPayload payload;
    if (password != null &&
        password.isNotEmpty &&
        BackupService.isEncryptedBytes(bytes)) {
      payload = BackupService.importEncryptedBackup(bytes, password);
    } else {
      payload = BackupService.importBackup(bytes);
    }
    await applyBackupPayload(payload, mode: mode);
  }

  Future<void> applyBackupPayload(
    BackupPayload payload, {
    RestoreMode mode = RestoreMode.replace,
  }) async {
    if (mode == RestoreMode.replace) {
      _profile = payload.profile.copyWith(onboardingCompleted: true);
      _savedRecipeIds = List<String>.from(payload.saved);
      _mealPlan = {
        for (final entry in payload.mealPlan.entries)
          entry.key: Map<String, String>.from(entry.value),
      };
      _history = List<CookHistoryEntry>.from(payload.history);
      _contentRequests = List<String>.from(payload.contentRequests);
    } else {
      // Merge mode
      final mergedAvoidFlags = <String>{
        ..._profile.avoidFlags,
        ...payload.profile.avoidFlags,
      };
      final mergedAvoidIngs = <String>{
        ..._profile.avoidIngredients,
        ...payload.profile.avoidIngredients,
      };
      _profile = payload.profile.copyWith(
        avoidFlags: mergedAvoidFlags,
        avoidIngredients: mergedAvoidIngs,
        onboardingCompleted: true,
      );
      for (final id in payload.saved) {
        if (!_savedRecipeIds.contains(id)) {
          _savedRecipeIds.add(id);
        }
      }
      for (final entry in payload.mealPlan.entries) {
        final existingWeek =
            Map<String, String>.from(_mealPlan[entry.key] ?? {});
        existingWeek.addAll(entry.value);
        _mealPlan[entry.key] = existingWeek;
      }
      final existingHistoryIds = _history.map((h) => h.id).toSet();
      for (final h in payload.history) {
        if (!existingHistoryIds.contains(h.id)) {
          _history.add(h);
        }
      }
      for (final req in payload.contentRequests) {
        if (!_contentRequests.contains(req)) {
          _contentRequests.add(req);
        }
      }
    }
    _syncCookModeController();
    notifyListeners();
    await _persist();
  }
}
