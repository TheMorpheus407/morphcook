import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../logic/backup/backup_service.dart';
import '../logic/backup/crypto.dart';
import '../logic/cook/cook_controller.dart';
import '../logic/matching.dart';
import '../logic/ranking.dart';
import '../logic/shopping.dart';
import '../models/collections.dart';
import '../models/dish.dart';
import '../models/localized.dart';
import '../models/personal_recipe.dart';
import '../models/profile.dart';
import '../models/recipe.dart';
import '../models/recipe_image.dart';
import 'corpus.dart';
import 'store.dart';

/// The app's single source of mutable truth — deliberately boring.
class AppState extends ChangeNotifier {
  final PersistenceStore store;
  final CorpusRepository corpus;

  AppState({required this.store, required this.corpus});

  Profile _profile = const Profile();
  bool _onboarded = false;
  List<SavedRecipe> _saved = [];
  List<HistoryEntry> _history = [];
  MealPlanData _mealPlan = {};
  List<ShoppingItem> _shoppingList = [];
  List<ShoppingItem> _shoppingHistory = [];
  List<String> _contentRequests = [];
  List<PersonalRecipe> _personalRecipes = [];
  Map<String, RecipeImage> _recipeImages = {};
  CookProgress? _cookProgress;

  Profile get profile => _profile;
  bool get onboarded => _onboarded;
  List<SavedRecipe> get saved => List.unmodifiable(_saved);
  List<HistoryEntry> get history => List.unmodifiable(_history);
  MealPlanData get mealPlan => _mealPlan;
  List<ShoppingItem> get shoppingList => List.unmodifiable(_shoppingList);
  List<ShoppingItem> get shoppingHistory => List.unmodifiable(_shoppingHistory);
  List<String> get contentRequests => List.unmodifiable(_contentRequests);
  List<PersonalRecipe> get personalRecipes =>
      List.unmodifiable(_personalRecipes);
  List<RecipeImage> get recipeImages =>
      List<RecipeImage>.unmodifiable(_recipeImages.values);
  CookProgress? get cookProgress => _cookProgress;

  String get lang => _profile.lang;

  Matcher get matcher =>
      Matcher(ontology: corpus.ontology, dictionary: corpus.dictionary);
  final Ranker ranker = Ranker();

  Future<void> load() async {
    await store.open();
    _profile = store.loadProfile() ?? const Profile();
    _onboarded = store.onboardingComplete;
    _saved = _readList('saved', SavedRecipe.fromJson);
    _history = _readList('history', HistoryEntry.fromJson);
    _shoppingList = _readList('shopping_list', ShoppingItem.fromJson);
    _shoppingHistory = _readList('shopping_history', ShoppingItem.fromJson);
    _mealPlan = _readMealPlan();
    _contentRequests = _readStrings('content_requests');
    _personalRecipes = _readList('personal_recipes', PersonalRecipe.fromJson);
    _recipeImages = _loadRecipeImages();
    final progressRaw = store.getCollection('cook_progress');
    if (progressRaw != null) {
      try {
        _cookProgress = CookProgress.fromJson(
          json.decode(progressRaw) as Map<String, dynamic>,
        );
      } catch (_) {}
    }
    notifyListeners();
  }

  List<T> _readList<T>(String key, T Function(Map<String, dynamic>) parse) {
    final raw = store.getCollection(key);
    if (raw == null) return [];
    try {
      return (json.decode(raw) as List)
          .map((e) => parse(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<String> _readStrings(String key) {
    final raw = store.getCollection(key);
    if (raw == null) return [];
    try {
      return List<String>.from(json.decode(raw) as List);
    } catch (_) {
      return [];
    }
  }

  MealPlanData _readMealPlan() {
    final raw = store.getCollection('meal_plan');
    if (raw == null) return {};
    try {
      return (json.decode(raw) as Map<String, dynamic>).map(
        (week, slots) => MapEntry(
          week,
          (slots as Map<String, dynamic>).map(
            (slot, id) => MapEntry(slot, id as String),
          ),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeJson(String key, Object value) =>
      store.putCollection(key, json.encode(value));

  // ---- profile ----

  Future<void> updateProfile(Profile profile) async {
    _profile = profile;
    await store.saveProfile(profile);
    notifyListeners();
  }

  Future<void> completeOnboarding(Profile profile) async {
    // Persist the actual choices before hiding onboarding. If either write
    // fails, the next launch can safely show setup again instead of entering
    // the app with a profile that was never saved.
    await store.saveProfile(profile);
    await store.setOnboardingComplete(true);
    _profile = profile;
    _onboarded = true;
    notifyListeners();
  }

  // ---- cookbook ----

  bool isSaved(String recipeId) => _saved.any((s) => s.recipeId == recipeId);

  Future<void> toggleSaved(String recipeId) async {
    if (isSaved(recipeId)) {
      _saved.removeWhere((s) => s.recipeId == recipeId);
    } else {
      _saved.add(SavedRecipe(recipeId: recipeId, savedAt: DateTime.now()));
    }
    await _writeJson('saved', _saved.map((s) => s.toJson()).toList());
    notifyListeners();
  }

  // ---- personal recipes ----

  PersonalRecipe? personalRecipeById(String recipeId) {
    for (final recipe in _personalRecipes) {
      if (recipe.id == recipeId) return recipe;
    }
    return null;
  }

  PersonalRecipe? _personalRecipeByDishId(String dishId) {
    for (final recipe in _personalRecipes) {
      if (recipe.dishId == dishId) return recipe;
    }
    return null;
  }

  bool isPersonalRecipe(String recipeId) =>
      personalRecipeById(recipeId) != null;

  /// Creates or updates a device-only recipe. New recipes are saved into the
  /// cookbook automatically, while edited recipes keep their existing id and
  /// references in plans/history.
  Future<void> savePersonalRecipe(PersonalRecipe recipe) async {
    final index = _personalRecipes.indexWhere((r) => r.id == recipe.id);
    if (index < 0) {
      if (_personalRecipes.length >= maxPersonalRecipes) {
        throw const PersonalRecipeLimitException(
          PersonalRecipeLimitReason.count,
        );
      }
    }
    final candidateRecipes = List<PersonalRecipe>.of(_personalRecipes);
    if (index < 0) {
      candidateRecipes.add(recipe);
    } else {
      candidateRecipes[index] = recipe;
    }
    if (!personalRecipesFitBackup(candidateRecipes)) {
      throw const PersonalRecipeLimitException(
        PersonalRecipeLimitReason.backupSize,
      );
    }

    final nextSaved = List<SavedRecipe>.of(_saved);
    final autoSave = index < 0 && !isSaved(recipe.id);
    if (autoSave) {
      nextSaved.add(SavedRecipe(recipeId: recipe.id, savedAt: DateTime.now()));
    }
    final invalidateCookProgress =
        index >= 0 && _cookProgress?.recipeId == recipe.id;
    final nextCollections = <String, String>{
      'personal_recipes': json.encode(
        candidateRecipes.map((r) => r.toJson()).toList(),
      ),
      if (autoSave)
        'saved': json.encode(nextSaved.map((s) => s.toJson()).toList()),
      if (invalidateCookProgress) 'cook_progress': 'null',
    };
    final previousCollections = <String, String>{
      'personal_recipes': json.encode(
        _personalRecipes.map((r) => r.toJson()).toList(),
      ),
      if (autoSave)
        'saved': json.encode(_saved.map((s) => s.toJson()).toList()),
      if (invalidateCookProgress)
        'cook_progress': _cookProgress == null
            ? 'null'
            : json.encode(_cookProgress!.toJson()),
    };
    try {
      await store.putCollections(nextCollections);
    } catch (_) {
      try {
        await store.putCollections(previousCollections);
      } catch (_) {}
      rethrow;
    }

    _personalRecipes = candidateRecipes;
    _saved = nextSaved;
    if (invalidateCookProgress) _cookProgress = null;
    notifyListeners();
  }

  /// Deletes the owned recipe and every reference that cannot be rendered
  /// without it. Shopping-list lines remain useful and retain their names.
  Future<void> deletePersonalRecipe(String recipeId) async {
    if (!isPersonalRecipe(recipeId)) return;
    final nextPersonalRecipes = List<PersonalRecipe>.of(_personalRecipes)
      ..removeWhere((r) => r.id == recipeId);
    final nextSaved = List<SavedRecipe>.of(_saved)
      ..removeWhere((s) => s.recipeId == recipeId);
    final nextHistory = List<HistoryEntry>.of(_history)
      ..removeWhere((h) => h.recipeId == recipeId);
    final nextMealPlan = <String, Map<String, String>>{
      for (final entry in _mealPlan.entries)
        entry.key: Map<String, String>.of(entry.value),
    };
    for (final week in nextMealPlan.values) {
      week.removeWhere((_, id) => id == recipeId);
    }
    nextMealPlan.removeWhere((_, slots) => slots.isEmpty);
    final nextCookProgress = _cookProgress?.recipeId == recipeId
        ? null
        : _cookProgress;
    final nextRecipeImages = Map<String, RecipeImage>.of(_recipeImages);
    final removedImage = nextRecipeImages.remove(recipeId);
    final nextCollections = <String, String>{
      'personal_recipes': json.encode(
        nextPersonalRecipes.map((r) => r.toJson()).toList(),
      ),
      'saved': json.encode(nextSaved.map((s) => s.toJson()).toList()),
      'history': json.encode(nextHistory.map((h) => h.toJson()).toList()),
      'meal_plan': json.encode(nextMealPlan),
      'cook_progress': nextCookProgress == null
          ? 'null'
          : json.encode(nextCookProgress.toJson()),
      'recipe_image_metadata': json.encode(
        nextRecipeImages.values
            .map((image) => image.metadata.toJson())
            .toList(),
      ),
    };
    final previousCollections = <String, String>{
      'personal_recipes': json.encode(
        _personalRecipes.map((r) => r.toJson()).toList(),
      ),
      'saved': json.encode(_saved.map((s) => s.toJson()).toList()),
      'history': json.encode(_history.map((h) => h.toJson()).toList()),
      'meal_plan': json.encode(_mealPlan),
      'cook_progress': _cookProgress == null
          ? 'null'
          : json.encode(_cookProgress!.toJson()),
      'recipe_image_metadata': json.encode(
        _recipeImages.values.map((image) => image.metadata.toJson()).toList(),
      ),
    };
    try {
      await store.putCollections(nextCollections);
      if (removedImage != null) {
        await store.removeRecipeImageBytes(recipeId);
      }
    } catch (_) {
      if (removedImage != null) {
        try {
          await store.putRecipeImageBytes(recipeId, removedImage.bytes);
        } catch (_) {}
      }
      try {
        await store.putCollections(previousCollections);
      } catch (_) {}
      rethrow;
    }

    _personalRecipes = nextPersonalRecipes;
    _saved = nextSaved;
    _history = nextHistory;
    _mealPlan = nextMealPlan;
    _cookProgress = nextCookProgress;
    _recipeImages = nextRecipeImages;
    notifyListeners();
  }

  // ---- local recipe images ----

  Map<String, RecipeImage> _loadRecipeImages() {
    final metadata = _readList(
      'recipe_image_metadata',
      RecipeImageMetadata.fromJson,
    );
    final storedBytes = store.loadRecipeImageBytes();
    final loaded = <String, RecipeImage>{};
    for (final item in metadata) {
      final bytes = storedBytes[item.recipeId];
      if (bytes == null) continue;
      try {
        // Detect the actual stored format again. If the process stopped
        // between replacing image bytes and metadata, the valid bytes remain
        // recoverable instead of disappearing because of a stale MIME field.
        loaded[item.recipeId] = RecipeImage(
          recipeId: item.recipeId,
          bytes: bytes,
          updatedAt: item.updatedAt,
        );
      } on RecipeImageException {
        // Ignore a corrupt local entry; the striped fallback remains usable.
      }
    }
    return loaded;
  }

  RecipeImage? recipeImageFor(String recipeId) => _recipeImages[recipeId];

  Future<RecipeImage> setRecipeImage(
    String recipeId,
    List<int> bytes, {
    DateTime? updatedAt,
  }) async {
    if (await recipeById(recipeId) == null) {
      throw ArgumentError.value(recipeId, 'recipeId', 'unknown recipe');
    }
    final image = RecipeImage(
      recipeId: recipeId,
      bytes: bytes,
      updatedAt: updatedAt ?? DateTime.now(),
    );
    final previousBytes = _recipeImages[recipeId]?.bytes.length ?? 0;
    final totalBytes =
        _recipeImages.values.fold<int>(
          0,
          (total, stored) => total + stored.bytes.length,
        ) -
        previousBytes +
        image.bytes.length;
    if ((_recipeImages.length >= maxBackupRecipeImages &&
            !_recipeImages.containsKey(recipeId)) ||
        totalBytes > maxBackupImageBytes) {
      throw const RecipeImageException(RecipeImageFailure.storageLimit);
    }
    final previousImage = _recipeImages[recipeId];
    final nextRecipeImages = Map<String, RecipeImage>.of(_recipeImages)
      ..[recipeId] = image;
    final nextMetadata = json.encode(
      nextRecipeImages.values
          .map((stored) => stored.metadata.toJson())
          .toList(),
    );
    final previousMetadata = json.encode(
      _recipeImages.values.map((stored) => stored.metadata.toJson()).toList(),
    );
    try {
      await store.putRecipeImageBytes(recipeId, image.bytes);
      await store.putCollections({'recipe_image_metadata': nextMetadata});
    } catch (_) {
      if (previousImage == null) {
        try {
          await store.removeRecipeImageBytes(recipeId);
        } catch (_) {}
      } else {
        try {
          await store.putRecipeImageBytes(recipeId, previousImage.bytes);
        } catch (_) {}
      }
      try {
        await store.putCollections({'recipe_image_metadata': previousMetadata});
      } catch (_) {}
      rethrow;
    }

    _recipeImages = nextRecipeImages;
    notifyListeners();
    return image;
  }

  Future<void> removeRecipeImage(String recipeId) async {
    final previousImage = _recipeImages[recipeId];
    if (previousImage == null) return;
    final nextRecipeImages = Map<String, RecipeImage>.of(_recipeImages)
      ..remove(recipeId);
    final nextMetadata = json.encode(
      nextRecipeImages.values
          .map((stored) => stored.metadata.toJson())
          .toList(),
    );
    final previousMetadata = json.encode(
      _recipeImages.values.map((stored) => stored.metadata.toJson()).toList(),
    );
    try {
      await store.putCollections({'recipe_image_metadata': nextMetadata});
      await store.removeRecipeImageBytes(recipeId);
    } catch (_) {
      try {
        await store.putRecipeImageBytes(recipeId, previousImage.bytes);
      } catch (_) {}
      try {
        await store.putCollections({'recipe_image_metadata': previousMetadata});
      } catch (_) {}
      rethrow;
    }

    _recipeImages = nextRecipeImages;
    notifyListeners();
  }

  // ---- history ----

  Future<void> logCooked(String recipeId) async {
    _history.add(HistoryEntry(recipeId: recipeId, cookedAt: DateTime.now()));
    await _writeJson('history', _history.map((h) => h.toJson()).toList());
    notifyListeners();
  }

  // ---- meal plan ----

  Future<void> assignMeal(String weekKey, String slot, String recipeId) async {
    _mealPlan.putIfAbsent(weekKey, () => {})[slot] = recipeId;
    await _writeJson('meal_plan', _mealPlan);
    notifyListeners();
  }

  Future<void> clearMeal(String weekKey, String slot) async {
    _mealPlan[weekKey]?.remove(slot);
    if (_mealPlan[weekKey]?.isEmpty ?? false) _mealPlan.remove(weekKey);
    await _writeJson('meal_plan', _mealPlan);
    notifyListeners();
  }

  Future<void> moveMeal(String weekKey, String fromSlot, String toSlot) async {
    final week = _mealPlan[weekKey];
    if (week == null || !week.containsKey(fromSlot)) return;
    final moving = week.remove(fromSlot)!;
    final displaced = week[toSlot];
    week[toSlot] = moving;
    if (displaced != null) week[fromSlot] = displaced;
    await _writeJson('meal_plan', _mealPlan);
    notifyListeners();
  }

  // ---- shopping ----

  Future<void> addToShoppingList(Iterable<(Recipe, double)> recipes) async {
    final aggregated = aggregate(recipes, corpus.dictionary);
    final now = DateTime.now();
    _shoppingList = mergeIntoList(_shoppingList, aggregated, now);
    // History keeps one record per added line for insights.
    _shoppingHistory = [
      ..._shoppingHistory,
      ...aggregated.map(
        (a) => ShoppingItem(
          ingredientId: a.ingredientId,
          customName: a.customName,
          qty: a.quantity.amount,
          unit: a.quantity.unit,
          aisle: a.aisle,
          addedAt: now,
        ),
      ),
    ];
    await _writeJson(
      'shopping_list',
      _shoppingList.map((s) => s.toJson()).toList(),
    );
    await _writeJson(
      'shopping_history',
      _shoppingHistory.map((s) => s.toJson()).toList(),
    );
    notifyListeners();
  }

  Future<void> toggleShoppingItem(int index) async {
    if (index < 0 || index >= _shoppingList.length) return;
    _shoppingList[index] = _shoppingList[index].copyWith(
      checked: !_shoppingList[index].checked,
    );
    await _writeJson(
      'shopping_list',
      _shoppingList.map((s) => s.toJson()).toList(),
    );
    notifyListeners();
  }

  Future<void> clearCheckedShoppingItems() async {
    _shoppingList.removeWhere((s) => s.checked);
    await _writeJson(
      'shopping_list',
      _shoppingList.map((s) => s.toJson()).toList(),
    );
    notifyListeners();
  }

  Future<void> clearShoppingList() async {
    _shoppingList = [];
    await _writeJson('shopping_list', const []);
    notifyListeners();
  }

  // ---- content requests (zero-result searches) ----

  Future<void> logContentRequest(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty || _contentRequests.contains(q)) return;
    _contentRequests.add(q);
    await _writeJson('content_requests', _contentRequests);
  }

  // ---- cook progress ----

  Future<void> persistCookProgress(CookProgress? progress) async {
    _cookProgress = progress;
    if (progress == null) {
      await store.putCollection('cook_progress', 'null');
    } else {
      await _writeJson('cook_progress', progress.toJson());
    }
  }

  // ---- backup ----

  BackupData buildBackup() => BackupData(
    profile: _profile,
    saved: _saved,
    mealPlan: _mealPlan,
    history: _history,
    shoppingHistory: _shoppingHistory,
    contentRequests: _contentRequests,
    personalRecipes: _personalRecipes,
    recipeImages: _recipeImages.values.toList(),
  );

  /// Applies an imported backup. [merge] keeps existing data and unions the
  /// incoming; otherwise the import replaces local state. Never touches the
  /// bundled corpus.
  Future<void> applyBackup(BackupData incoming, {required bool merge}) async {
    final data = merge
        ? BackupService.merge(buildBackup(), incoming)
        : incoming;
    if (data.personalRecipes.length > maxPersonalRecipes) {
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }
    if (!personalRecipesFitBackup(data.personalRecipes)) {
      throw const DecryptionException(DecryptionFailure.tooLarge);
    }
    final personalIds = data.personalRecipes.map((r) => r.id).toSet();
    if (personalIds.length != data.personalRecipes.length) {
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }
    for (final image in data.recipeImages) {
      if (!personalIds.contains(image.recipeId) &&
          await corpus.recipeById(image.recipeId) == null) {
        throw const DecryptionException(DecryptionFailure.invalidFormat);
      }
    }

    final nextSaved = List<SavedRecipe>.of(data.saved);
    final nextMealPlan = <String, Map<String, String>>{
      for (final entry in data.mealPlan.entries)
        entry.key: Map<String, String>.of(entry.value),
    };
    final nextHistory = List<HistoryEntry>.of(data.history);
    final nextShoppingList = merge
        ? List<ShoppingItem>.of(_shoppingList)
        : <ShoppingItem>[];
    final nextShoppingHistory = List<ShoppingItem>.of(data.shoppingHistory);
    final nextContentRequests = List<String>.of(data.contentRequests);
    final nextPersonalRecipes = List<PersonalRecipe>.of(data.personalRecipes);
    final nextRecipeImages = <String, RecipeImage>{
      for (final image in data.recipeImages) image.recipeId: image,
    };
    var nextCookProgress = merge ? _cookProgress : null;
    if (nextCookProgress != null &&
        incoming.personalRecipes.any(
          (recipe) => recipe.id == nextCookProgress!.recipeId,
        )) {
      nextCookProgress = null;
    }

    final nextCollections = <String, String>{
      'saved': json.encode(nextSaved.map((s) => s.toJson()).toList()),
      'meal_plan': json.encode(nextMealPlan),
      'history': json.encode(nextHistory.map((h) => h.toJson()).toList()),
      'shopping_list': json.encode(
        nextShoppingList.map((s) => s.toJson()).toList(),
      ),
      'shopping_history': json.encode(
        nextShoppingHistory.map((s) => s.toJson()).toList(),
      ),
      'content_requests': json.encode(nextContentRequests),
      'personal_recipes': json.encode(
        nextPersonalRecipes.map((r) => r.toJson()).toList(),
      ),
      'recipe_image_metadata': json.encode(
        nextRecipeImages.values
            .map((image) => image.metadata.toJson())
            .toList(),
      ),
      'cook_progress': nextCookProgress == null
          ? 'null'
          : json.encode(nextCookProgress.toJson()),
    };
    final oldCollections = <String, String>{
      'saved': json.encode(_saved.map((s) => s.toJson()).toList()),
      'meal_plan': json.encode(_mealPlan),
      'history': json.encode(_history.map((h) => h.toJson()).toList()),
      'shopping_list': json.encode(
        _shoppingList.map((s) => s.toJson()).toList(),
      ),
      'shopping_history': json.encode(
        _shoppingHistory.map((s) => s.toJson()).toList(),
      ),
      'content_requests': json.encode(_contentRequests),
      'personal_recipes': json.encode(
        _personalRecipes.map((r) => r.toJson()).toList(),
      ),
      'recipe_image_metadata': json.encode(
        _recipeImages.values.map((image) => image.metadata.toJson()).toList(),
      ),
      'cook_progress': _cookProgress == null
          ? 'null'
          : json.encode(_cookProgress!.toJson()),
    };
    final oldImageIds = _recipeImages.keys.toSet();
    final nextImageIds = nextRecipeImages.keys.toSet();
    try {
      await store.putRecipeImageBytesBatch({
        for (final image in nextRecipeImages.values)
          image.recipeId: image.bytes,
      });
      await store.putCollections(nextCollections);
      await store.saveProfile(data.profile);
      await store.setOnboardingComplete(true);
      await store.removeRecipeImageBytesBatch(
        oldImageIds.difference(nextImageIds),
      );
    } catch (_) {
      // Best-effort rollback keeps a recoverable old state if persistence
      // fails (for example because device storage is full).
      try {
        await store.putRecipeImageBytesBatch({
          for (final image in _recipeImages.values) image.recipeId: image.bytes,
        });
        await store.removeRecipeImageBytesBatch(
          nextImageIds.difference(oldImageIds),
        );
        await store.putCollections(oldCollections);
        await store.saveProfile(_profile);
        await store.setOnboardingComplete(_onboarded);
      } catch (_) {}
      rethrow;
    }

    _profile = data.profile;
    _saved = nextSaved;
    _mealPlan = nextMealPlan;
    _history = nextHistory;
    _shoppingList = nextShoppingList;
    _shoppingHistory = nextShoppingHistory;
    _contentRequests = nextContentRequests;
    _personalRecipes = nextPersonalRecipes;
    _recipeImages = nextRecipeImages;
    _cookProgress = nextCookProgress;
    _onboarded = true;
    notifyListeners();
  }

  /// Full reset (troubleshooting: "reset profile").
  Future<void> resetEverything() async {
    await store.clearAll();
    _profile = const Profile();
    _onboarded = false;
    _saved = [];
    _history = [];
    _mealPlan = {};
    _shoppingList = [];
    _shoppingHistory = [];
    _contentRequests = [];
    _personalRecipes = [];
    _recipeImages = {};
    _cookProgress = null;
    notifyListeners();
  }

  // ---- matching convenience ----

  /// Unified lookup across device-owned recipes and the bundled corpus.
  Future<Recipe?> recipeById(String id) async =>
      personalRecipeById(id)?.asRecipe() ?? await corpus.recipeById(id);

  /// Synchronous counterpart for already-loaded recipe references.
  Recipe? loadedRecipeById(String id) =>
      personalRecipeById(id)?.asRecipe() ?? corpus.loadedRecipeById(id);

  /// Unified dish lookup. Personal recipes expose a synthetic single-variant
  /// dish so existing detail navigation can keep using a dish id.
  Dish? dishById(String id) {
    final personal = _personalRecipeByDishId(id);
    if (personal != null) {
      final text = LocalizedText({'en': personal.title, 'de': personal.title});
      final description = personal.description.isEmpty
          ? LocalizedText.empty
          : LocalizedText({
              'en': personal.description,
              'de': personal.description,
            });
      return Dish(
        id: personal.dishId,
        name: text,
        hero: description,
        caption: description,
        stripe: '#497C78',
        recipeIds: [personal.id],
        partitionId: 'personal',
        secondaryPartitions: const [],
        cuisineTags: const [],
        frequencyTier: 'personal',
      );
    }
    return corpus.dishById(id);
  }

  Future<List<Recipe>> variantsOf(Dish dish) async {
    final personal = _personalRecipeByDishId(dish.id);
    if (personal != null) return [personal.asRecipe()];
    return corpus.variantsOf(dish);
  }

  /// Visible variants of a dish for the current profile. Personal recipes
  /// are always visible because the editor does not infer dietary claims.
  Future<List<Recipe>> visibleVariants(
    String dishId, {
    bool ignoreCalories = false,
  }) async {
    final dish = dishById(dishId);
    if (dish == null) return [];
    final personal = _personalRecipeByDishId(dishId);
    if (personal != null) return [personal.asRecipe()];
    final variants = await variantsOf(dish);
    return variants
        .where(
          (r) => matcher.isVisible(r, _profile, ignoreCalories: ignoreCalories),
        )
        .toList();
  }

  /// Best visible variant for the dish, profile-default and time-aware.
  Future<Recipe?> bestVariant(String dishId) async {
    final personal = _personalRecipeByDishId(dishId);
    if (personal != null) return personal.asRecipe();
    final visible = await visibleVariants(dishId);
    return ranker.pickBest(visible, _profile, _history);
  }
}
