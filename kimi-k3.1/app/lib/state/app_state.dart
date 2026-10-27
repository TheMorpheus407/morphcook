import 'package:flutter/foundation.dart';

import '../models/profile.dart';
import '../models/recipe.dart';
import '../models/user_data.dart';
import '../services/local_store.dart';
import '../services/recipe_repository.dart';

class AppState extends ChangeNotifier {
  AppState({
    required this.repository,
    required this.store,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  final RecipeRepository repository;
  final LocalStateStore store;
  final DateTime Function() clock;
  Profile profile = const Profile();
  UserSnapshot snapshot = const UserSnapshot();
  bool ready = false;
  Object? initializationError;
  Future<void> _snapshotWrites = Future.value();
  Future<void> _profileWrites = Future.value();

  Future<void> initialize() async {
    try {
      final results = await Future.wait([
        store.loadProfile(),
        store.loadSnapshot(),
      ]);
      profile = results[0] as Profile? ?? const Profile();
      snapshot = results[1] as UserSnapshot;
      ready = true;
    } catch (error) {
      initializationError = error;
      ready = true;
    }
    notifyListeners();
  }

  bool get needsOnboarding => !profile.onboardingComplete;
  String get language => profile.lang;

  Future<void> updateProfile(Profile value) async {
    profile = value;
    notifyListeners();
    _profileWrites = _profileWrites.then((_) => store.saveProfile(profile));
    await _profileWrites;
  }

  void _updateSnapshot(UserSnapshot value, {bool notify = true}) {
    snapshot = value;
    if (notify) notifyListeners();
    _snapshotWrites = _snapshotWrites.then((_) => store.saveSnapshot(snapshot));
  }

  Future<void> get writesSettled =>
      Future.wait([_snapshotWrites, _profileWrites]);

  bool isSaved(String recipeId) =>
      snapshot.saved.any((item) => item.recipeId == recipeId);

  void toggleSaved(String recipeId) {
    final saved = [...snapshot.saved];
    final index = saved.indexWhere((item) => item.recipeId == recipeId);
    if (index >= 0) {
      saved.removeAt(index);
    } else {
      saved.insert(
        0,
        SavedRecipe(recipeId: recipeId, savedAt: clock().toUtc()),
      );
    }
    _updateSnapshot(snapshot.copyWith(saved: saved));
  }

  Map<String, DateTime> get lastCooked {
    final result = <String, DateTime>{};
    for (final entry in snapshot.history) {
      final existing = result[entry.recipeId];
      if (existing == null || entry.cookedAt.isAfter(existing)) {
        result[entry.recipeId] = entry.cookedAt;
      }
    }
    return result;
  }

  void recordContentRequest(String query) {
    final clean = query.trim();
    if (clean.isEmpty || snapshot.contentRequests.contains(clean)) return;
    final requests = [...snapshot.contentRequests, clean];
    if (requests.length > 100) requests.removeAt(0);
    _updateSnapshot(snapshot.copyWith(contentRequests: requests));
  }

  void assignRecipe(String week, String slot, String recipeId) {
    final plan = _mutablePlan();
    plan.putIfAbsent(week, () => {})[slot] = recipeId;
    _updateSnapshot(snapshot.copyWith(mealPlan: plan));
  }

  void clearSlot(String week, String slot) {
    final plan = _mutablePlan();
    plan[week]?.remove(slot);
    if (plan[week]?.isEmpty == true) plan.remove(week);
    _updateSnapshot(snapshot.copyWith(mealPlan: plan));
  }

  void moveSlot({
    required String sourceWeek,
    required String sourceSlot,
    required String targetWeek,
    required String targetSlot,
  }) {
    if (sourceWeek == targetWeek && sourceSlot == targetSlot) return;
    final recipe = snapshot.mealPlan[sourceWeek]?[sourceSlot];
    if (recipe == null) return;
    final plan = _mutablePlan();
    final displaced = plan[targetWeek]?[targetSlot];
    plan.putIfAbsent(targetWeek, () => {})[targetSlot] = recipe;
    if (displaced == null) {
      plan[sourceWeek]?.remove(sourceSlot);
    } else {
      plan.putIfAbsent(sourceWeek, () => {})[sourceSlot] = displaced;
    }
    if (plan[sourceWeek]?.isEmpty == true) plan.remove(sourceWeek);
    _updateSnapshot(snapshot.copyWith(mealPlan: plan));
  }

  void clearWeek(String week) {
    final plan = _mutablePlan()..remove(week);
    _updateSnapshot(snapshot.copyWith(mealPlan: plan));
  }

  Map<String, Map<String, String>> _mutablePlan() => {
    for (final entry in snapshot.mealPlan.entries) entry.key: {...entry.value},
  };

  Future<void> addRecipeIdsToShopping(List<String> recipeIds) async {
    final unique = recipeIds.toSet().where(
      (id) => !snapshot.shoppingRecipeIds.contains(id),
    );
    if (unique.isEmpty) return;
    final recipes = <Recipe>[];
    for (final id in unique) {
      await repository.ensureRecipe(id);
      final recipe = repository.recipes[id];
      if (recipe != null) recipes.add(recipe);
    }
    final now = clock().toUtc();
    final events = <ShoppingEvent>[];
    for (final recipe in recipes) {
      for (final ingredient in recipe.ingredients) {
        events.add(
          ShoppingEvent(
            id: '${recipe.id}:${ingredient.id}:${now.microsecondsSinceEpoch}',
            ingredientId: ingredient.id,
            recipeId: recipe.id,
            addedAt: now,
            amount: ingredient.amount,
            unit: ingredient.unit,
          ),
        );
      }
    }
    _updateSnapshot(
      snapshot.copyWith(
        shoppingRecipeIds: [
          ...snapshot.shoppingRecipeIds,
          ...recipes.map((recipe) => recipe.id),
        ],
        shoppingEvents: [...snapshot.shoppingEvents, ...events],
      ),
    );
  }

  Future<void> exportWeekToShopping(String week) async {
    final ids = snapshot.mealPlan[week]?.values.toSet().toList() ?? const [];
    await addRecipeIdsToShopping(ids);
  }

  void removeRecipeFromShopping(String recipeId) {
    final ids = [...snapshot.shoppingRecipeIds]..remove(recipeId);
    _updateSnapshot(snapshot.copyWith(shoppingRecipeIds: ids));
  }

  void clearShopping() {
    _updateSnapshot(
      snapshot.copyWith(
        shoppingRecipeIds: const [],
        checkedShoppingItems: const {},
      ),
    );
  }

  void toggleShoppingChecked(String key) {
    final checked = {...snapshot.checkedShoppingItems};
    if (!checked.add(key)) checked.remove(key);
    _updateSnapshot(snapshot.copyWith(checkedShoppingItems: checked));
  }

  void saveCookProgress(CookProgress progress, {bool notify = true}) {
    _updateSnapshot(
      snapshot.copyWith(
        cookProgress: {...snapshot.cookProgress, progress.recipeId: progress},
      ),
      notify: notify,
    );
  }

  void clearCookProgress(String recipeId) {
    final progress = {...snapshot.cookProgress}..remove(recipeId);
    _updateSnapshot(snapshot.copyWith(cookProgress: progress));
  }

  void completeCook(String recipeId, int servings) {
    final now = clock().toUtc();
    final history = [...snapshot.history]
      ..insert(
        0,
        HistoryEntry(
          id: '$recipeId:${now.microsecondsSinceEpoch}',
          recipeId: recipeId,
          cookedAt: now,
          servings: servings,
        ),
      );
    final progress = {...snapshot.cookProgress}..remove(recipeId);
    _updateSnapshot(
      snapshot.copyWith(history: history, cookProgress: progress),
    );
  }

  Future<void> restore(BackupData data, {required bool merge}) async {
    profile = data.profile;
    snapshot = merge ? snapshot.mergedWith(data.snapshot) : data.snapshot;
    notifyListeners();
    _profileWrites = _profileWrites.then((_) => store.saveProfile(profile));
    _snapshotWrites = _snapshotWrites.then((_) => store.saveSnapshot(snapshot));
    await writesSettled;
  }

  Future<void> close() async {
    await writesSettled;
    await store.close();
  }
}
