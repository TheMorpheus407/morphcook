import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/backup_service.dart';
import '../data/corpus_repository.dart';
import '../data/local_store.dart';
import '../domain/collections.dart';
import '../domain/matching.dart';
import '../domain/models.dart';
import '../domain/profile.dart';
import '../domain/ranking.dart';
import '../services/insights_service.dart';
import '../services/search_service.dart';
import '../services/shopping_list_service.dart';

typedef Clock = DateTime Function();

/// The one store the widgets talk to. Deliberately a single ChangeNotifier
/// rather than a graph of them: the whole app fits in a few kilobytes of state
/// and cross-cutting reads (a saved recipe influencing the home feed) are the
/// normal case, not the exception.
class AppState extends ChangeNotifier {
  AppState({
    required this.repository,
    required this.profileStore,
    required this.collections,
    Clock? clock,
    BackupService? backupService,
  }) : _clock = clock ?? DateTime.now,
       _backup = backupService ?? BackupService();

  final CorpusRepository repository;
  final ProfileStore profileStore;
  final CollectionsStore collections;
  final Clock _clock;
  final BackupService _backup;

  late RecipeMatcher matcher;
  late SearchService searchService;
  late ShoppingListService shoppingService;
  late InsightsService insightsService;
  static const Ranker ranker = Ranker();

  Profile _profile = const Profile();
  List<SavedRecipe> _saved = [];
  List<CookHistoryEntry> _history = [];
  MealPlan _plan = MealPlan();
  List<ShoppingEntry> _shopping = [];
  List<ContentRequest> _requests = [];
  CookProgress? _progress;

  bool _ready = false;
  Object? _initError;

  DateTime get now => _clock();
  bool get isReady => _ready;
  Object? get initError => _initError;

  Profile get profile => _profile;
  List<SavedRecipe> get saved => List.unmodifiable(_saved);
  List<CookHistoryEntry> get history => List.unmodifiable(_history);
  MealPlan get plan => _plan;
  List<ShoppingEntry> get shopping => List.unmodifiable(_shopping);
  List<ContentRequest> get contentRequests => List.unmodifiable(_requests);
  CookProgress? get cookProgress => _progress;

  String get lang => _profile.lang;

  Future<void> initialise() async {
    try {
      await repository.initialise();
      matcher = RecipeMatcher(
        ontology: repository.ontology,
        ingredients: repository.ingredients,
      );
      searchService = SearchService(repository: repository, matcher: matcher);
      shoppingService = ShoppingListService(repository.ingredients);
      insightsService = InsightsService(repository.ingredients);

      _profile = profileStore.load();
      _saved = collections.loadSaved();
      _history = collections.loadHistory();
      _plan = collections.loadPlan();
      _shopping = collections.loadShopping();
      _requests = collections.loadRequests();
      _progress = collections.loadProgress();

      _ready = true;
      notifyListeners();

      // Warm the rest of the bundle once the first frame is out.
      unawaited(
        repository.prefetchIdlePartitions().then((_) => notifyListeners()),
      );
    } on Object catch (err) {
      _initError = err;
      notifyListeners();
    }
  }

  // --- matching helpers ---------------------------------------------------

  MatchContext matchContext({bool ignoreCalorieTarget = false}) =>
      matcher.contextFor(_profile, ignoreCalorieTarget: ignoreCalorieTarget);

  /// Most recent cook date per recipe — feeds the staleness bonus.
  Map<String, DateTime> get lastCookedByRecipe {
    final out = <String, DateTime>{};
    for (final entry in _history) {
      final existing = out[entry.recipeId];
      if (existing == null || entry.cookedAt.isAfter(existing)) {
        out[entry.recipeId] = entry.cookedAt;
      }
    }
    return out;
  }

  /// The variant of [dishId] this profile should see, or null when every
  /// sibling clashes. Requires the dish's partition to be resident.
  Recipe? preferredVariant(String dishId, {bool ignoreCalorieTarget = false}) {
    final variants = repository.variantsOf(dishId);
    if (variants.isEmpty) return null;
    final ctx = matchContext(ignoreCalorieTarget: ignoreCalorieTarget);
    final visible = matcher.filter(variants, ctx);
    if (visible.isEmpty) return null;
    return ranker.best(
      visible,
      _profile,
      now: now,
      lastCookedByRecipe: lastCookedByRecipe,
    );
  }

  // --- profile ------------------------------------------------------------

  Future<void> updateProfile(Profile next) async {
    if (next == _profile) return;
    _profile = next;
    await profileStore.save(next);
    notifyListeners();
  }

  Future<void> completeOnboarding(Profile next) =>
      updateProfile(next.copyWith(onboardingComplete: true));

  // --- saved --------------------------------------------------------------

  bool isSaved(String recipeId) => _saved.any((e) => e.recipeId == recipeId);

  Future<void> toggleSaved(String recipeId) async {
    final index = _saved.indexWhere((e) => e.recipeId == recipeId);
    if (index >= 0) {
      _saved.removeAt(index);
    } else {
      _saved.insert(0, SavedRecipe(recipeId: recipeId, savedAt: now));
    }
    await collections.saveSaved(_saved);
    notifyListeners();
  }

  List<SavedRecipe> savedSorted({bool byName = false, String lang = 'en'}) {
    final copy = List.of(_saved);
    if (byName) {
      copy.sort((a, b) {
        final ta = repository.recipe(a.recipeId)?.title(lang) ?? a.recipeId;
        final tb = repository.recipe(b.recipeId)?.title(lang) ?? b.recipeId;
        return ta.compareTo(tb);
      });
    } else {
      copy.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    }
    return copy;
  }

  // --- history ------------------------------------------------------------

  Future<void> logCooked(
    String recipeId, {
    required int servings,
    bool completed = true,
  }) async {
    _history.insert(
      0,
      CookHistoryEntry(
        recipeId: recipeId,
        cookedAt: now,
        servings: servings,
        completed: completed,
      ),
    );
    await collections.saveHistory(_history);
    notifyListeners();
  }

  // --- meal plan ----------------------------------------------------------

  Future<void> assignSlot(IsoWeek week, PlanSlot slot, String recipeId) async {
    _plan.assign(week, slot, recipeId);
    await collections.savePlan(_plan);
    notifyListeners();
  }

  Future<void> clearSlot(IsoWeek week, PlanSlot slot) async {
    _plan.clear(week, slot);
    await collections.savePlan(_plan);
    notifyListeners();
  }

  Future<void> moveSlot(
    IsoWeek from,
    PlanSlot fromSlot,
    IsoWeek to,
    PlanSlot toSlot,
  ) async {
    _plan.move(from, fromSlot, to, toSlot);
    await collections.savePlan(_plan);
    notifyListeners();
  }

  // --- shopping -----------------------------------------------------------

  Future<int> addRecipesToShoppingList(Iterable<String> recipeIds) async {
    final recipes = <Recipe>[];
    for (final id in recipeIds) {
      await repository.ensureRecipeLoaded(id);
      final r = repository.recipe(id);
      if (r != null) recipes.add(r);
    }
    if (recipes.isEmpty) return 0;
    final incoming = shoppingService.entriesForRecipes(recipes, now: now);
    final before = _shopping.length;
    _shopping = shoppingService.merge(_shopping, incoming);
    await collections.saveShopping(_shopping);
    notifyListeners();
    return _shopping.length == before && incoming.isNotEmpty
        ? 0
        : recipes.length;
  }

  Future<void> addManualShoppingItem(
    String ingredientId,
    double? qty,
    String unit,
  ) async {
    _shopping = shoppingService.merge(_shopping, [
      ShoppingEntry(
        ingredientId: ingredientId,
        qty: qty,
        unit: unit,
        addedAt: now,
        sourceRecipeIds: const [],
        manual: true,
      ),
    ]);
    await collections.saveShopping(_shopping);
    notifyListeners();
  }

  Future<void> setShoppingChecked(String ingredientId, bool checked) async {
    _shopping = [
      for (final e in _shopping)
        e.ingredientId == ingredientId ? e.copyWith(checked: checked) : e,
    ];
    await collections.saveShopping(_shopping);
    notifyListeners();
  }

  Future<void> removeShoppingItem(String ingredientId) async {
    _shopping.removeWhere((e) => e.ingredientId == ingredientId);
    await collections.saveShopping(_shopping);
    notifyListeners();
  }

  Future<void> clearCheckedShopping() async {
    _shopping.removeWhere((e) => e.checked);
    await collections.saveShopping(_shopping);
    notifyListeners();
  }

  Future<void> clearShopping() async {
    _shopping = [];
    await collections.saveShopping(_shopping);
    notifyListeners();
  }

  ShoppingInsights get insights => insightsService.analyse(_shopping);

  // --- content requests ---------------------------------------------------

  Future<void> recordEmptySearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final key = trimmed.toLowerCase();
    final index = _requests.indexWhere((r) => r.query.toLowerCase() == key);
    if (index >= 0) {
      _requests[index] = _requests[index].bump();
    } else {
      _requests.add(
        ContentRequest(query: trimmed, firstAskedAt: now, count: 1),
      );
    }
    await collections.saveRequests(_requests);
    notifyListeners();
  }

  Future<void> clearContentRequests() async {
    _requests = [];
    await collections.saveRequests(_requests);
    notifyListeners();
  }

  // --- cook progress ------------------------------------------------------

  Future<void> saveCookProgress(CookProgress? progress) async {
    _progress = progress;
    await collections.saveProgress(progress);
    notifyListeners();
  }

  // --- backup -------------------------------------------------------------

  BackupDocument buildBackupDocument() => BackupDocument(
    schemaVersion: BackupDocument.currentSchemaVersion,
    exportedAt: now,
    profile: _profile,
    saved: _saved,
    mealPlan: _plan,
    history: _history,
    contentRequests: _requests,
    shopping: _shopping,
  );

  ExportBundle exportBackup({String? password}) =>
      _backup.export(buildBackupDocument(), password: password);

  BackupDocument readBackup(List<int> bytes) => _backup.import(bytes);

  BackupDocument readEncryptedBackup(List<int> bytes, String password) =>
      _backup.importEncrypted(bytes, password);

  Future<MergeOutcome> applyImportedBackup(
    BackupDocument document,
    ImportMode mode, {
    bool adoptProfile = true,
  }) async {
    final outcome = applyBackup(
      document: document,
      mode: mode,
      currentProfile: _profile,
      currentSaved: _saved,
      currentHistory: _history,
      currentPlan: _plan,
      currentShopping: _shopping,
      currentRequests: _requests,
    );
    if (adoptProfile || mode == ImportMode.replace) {
      _profile = outcome.profile.copyWith(onboardingComplete: true);
      await profileStore.save(_profile);
    }
    _saved = outcome.saved;
    _history = outcome.history;
    _plan = outcome.plan;
    _shopping = outcome.shopping;
    _requests = outcome.requests;
    await Future.wait([
      collections.saveSaved(_saved),
      collections.saveHistory(_history),
      collections.savePlan(_plan),
      collections.saveShopping(_shopping),
      collections.saveRequests(_requests),
    ]);
    notifyListeners();
    return outcome;
  }

  Future<void> resetEverything() async {
    _profile = const Profile();
    _saved = [];
    _history = [];
    _plan = MealPlan();
    _shopping = [];
    _requests = [];
    _progress = null;
    await profileStore.reset();
    await collections.clearAll();
    notifyListeners();
  }
}
