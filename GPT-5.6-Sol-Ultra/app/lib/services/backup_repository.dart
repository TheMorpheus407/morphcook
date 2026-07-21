import 'package:morphcook/domain/models.dart';

import 'backup_service.dart';
import 'cook_session_controller.dart';
import 'local_store.dart';
import 'profile_store.dart';
import 'shopping_service.dart';

class BackupRestoreResult {
  const BackupRestoreResult({
    required this.savedCount,
    required this.historyCount,
    required this.mealPlanCount,
    required this.shoppingCount,
    required this.contentRequestCount,
  });

  final int savedCount;
  final int historyCount;
  final int mealPlanCount;
  final int shoppingCount;
  final int contentRequestCount;
}

/// Bridges the pure backup codec to SharedPreferences and Hive-owned data.
class BackupRepository {
  const BackupRepository({
    required this.profileStore,
    required this.localStore,
    required this.backupService,
  });

  final ProfileStore profileStore;
  final LocalApplicationStore localStore;
  final BackupService backupService;

  Future<BackupData> collect() async {
    final profile = await profileStore.loadProfile();
    final local = await localStore.snapshot();
    return BackupData(
      profile: profile?.toJson() ?? const <String, dynamic>{},
      saved: local.savedRecipes.map((item) => item.recipeId),
      mealPlan: local.mealPlan.toBackupJson(),
      history: local.history.map((item) => item.toJson()),
      contentRequests: local.contentRequests.map((item) => item.query),
      shoppingEntries: local.shoppingEntries.map((item) => item.toJson()),
      shoppingInsightEvents: local.shoppingInsightEvents.map(
        (item) => item.toJson(),
      ),
      cookSessions: local.cookSessions.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
    );
  }

  Future<BackupExportBundle> export({String? password}) async =>
      backupService.export(await collect(), password: password);

  Future<BackupRestoreResult> restoreBytes(
    List<int> bytes, {
    String? password,
    required RestoreMode mode,
  }) async {
    final imported = await backupService.import(bytes, password: password);
    return restore(imported, mode: mode);
  }

  Future<BackupRestoreResult> restore(
    BackupData imported, {
    required RestoreMode mode,
  }) async {
    final currentBackup = await collect();
    final currentLocal = await localStore.snapshot();
    final currentProfile = await profileStore.loadProfile();
    final resolved = backupService.merge(currentBackup, imported, mode: mode);

    // Parse and validate every record before the first persistent write.
    late final UserProfile? profile;
    late final List<CookHistoryEntry> history;
    late final MealPlan mealPlan;
    late final List<ShoppingEntry> shopping;
    late final List<ShoppingInsightEvent> shoppingInsightEvents;
    late final Map<String, CookSessionSnapshot> sessions;
    try {
      profile = resolved.profile.isEmpty
          ? null
          : UserProfile.fromJson(resolved.profile);
      if (profile != null) _validateProfile(profile);
      history = resolved.history
          .map(CookHistoryEntry.fromJson)
          .toList(growable: false);
      mealPlan = MealPlan.fromJson(resolved.mealPlan);
      shopping = resolved.shoppingEntries
          .map(ShoppingEntry.fromJson)
          .toList(growable: false);
      shoppingInsightEvents = resolved.shoppingInsightEvents
          .map(ShoppingInsightEvent.fromJson)
          .toList(growable: false);
      sessions = resolved.cookSessions.map((key, value) {
        _validateCookSessionJson(key, value);
        final session = CookSessionSnapshot.fromJson(value);
        if (session.recipeId != key) _invalidBackup();
        return MapEntry(key, session);
      });
    } on BackupFormatException {
      rethrow;
    } on Object {
      _invalidBackup();
    }
    final currentSavedById = <String, SavedRecipe>{
      for (final saved in currentLocal.savedRecipes) saved.recipeId: saved,
    };
    final saved = resolved.saved
        .map(
          (id) =>
              currentSavedById[id] ??
              SavedRecipe(recipeId: id, savedAt: imported.exportedAt),
        )
        .toList(growable: false);
    final currentRequests = <String, ContentRequest>{
      for (final request in currentLocal.contentRequests)
        '${normalizeLanguageCode(request.languageCode)}|${request.normalizedQuery}':
            request,
    };
    final defaultLanguage = profile?.languageCode ?? 'en';
    final requests = resolved.contentRequests
        .map((query) {
          final key = '$defaultLanguage|${query.trim().toLowerCase()}';
          return (mode == RestoreMode.merge ? currentRequests[key] : null) ??
              ContentRequest(
                query: query,
                languageCode: defaultLanguage,
                lastSearchedAt: imported.exportedAt,
              );
        })
        .toList(growable: false);

    final replacement = LocalStoreSnapshot(
      savedRecipes: saved,
      history: history,
      mealPlan: mealPlan,
      shoppingEntries: shopping,
      shoppingInsightEvents: shoppingInsightEvents,
      contentRequests: requests,
      cookSessions: sessions,
    );
    try {
      await localStore.replaceAll(replacement);
      if (profile != null) {
        await profileStore.saveProfile(profile);
      } else if (mode == RestoreMode.replace) {
        await profileStore.deleteProfile();
      }
    } catch (error, stackTrace) {
      // Best-effort rollback keeps a failed restore from becoming data loss.
      try {
        await localStore.replaceAll(currentLocal);
        if (currentProfile == null) {
          await profileStore.deleteProfile();
        } else {
          await profileStore.saveProfile(currentProfile);
        }
      } on Object {
        // Preserve the original failure; the staged box writes still avoid
        // destructive clear-before-put behavior.
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    return BackupRestoreResult(
      savedCount: saved.length,
      historyCount: history.length,
      mealPlanCount: mealPlan.entries.length,
      shoppingCount: shopping.length,
      contentRequestCount: requests.length,
    );
  }
}

Never _invalidBackup() => throw const BackupFormatException(
  'This file is not a valid MorphCook backup.',
);

void _validateProfile(UserProfile profile) {
  if (!const {'en', 'de'}.contains(profile.languageCode) ||
      !const {15, 30, 45, 60, 90}.contains(profile.maxTimeMinutes) ||
      profile.calorieTarget < 300 ||
      profile.calorieTarget > 1000 ||
      profile.calorieTolerance < 50 ||
      profile.calorieTolerance > 300 ||
      !const {'easy', 'medium', 'hard'}.contains(profile.preferredEffort) ||
      profile.name.length > 120) {
    _invalidBackup();
  }
}

void _validateCookSessionJson(String key, Map<String, dynamic> json) {
  final recipeId = json['recipe_id'];
  final baseServings = json['base_servings'];
  final servings = json['servings'];
  final totalSteps = json['total_steps'];
  final currentStep = json['current_step_index'];
  if (key.isEmpty ||
      recipeId is! String ||
      recipeId.isEmpty ||
      baseServings is! num ||
      !baseServings.isFinite ||
      baseServings <= 0 ||
      servings is! num ||
      !servings.isFinite ||
      servings <= 0 ||
      totalSteps is! int ||
      totalSteps <= 0 ||
      totalSteps > 500 ||
      currentStep is! int ||
      currentStep < 0 ||
      currentStep >= totalSteps) {
    _invalidBackup();
  }
  final completed = json['completed_step_indices'];
  if (completed is! List ||
      completed.any(
        (value) => value is! int || value < 0 || value >= totalSteps,
      )) {
    _invalidBackup();
  }
  final timers = json['timers'];
  if (timers is! Map) _invalidBackup();
  for (final entry in timers.entries) {
    final index = int.tryParse(entry.key.toString());
    if (index == null ||
        index < 0 ||
        index >= totalSteps ||
        entry.value is! Map) {
      _invalidBackup();
    }
    final timer = entry.value as Map;
    final total = timer['total_seconds'];
    final remaining = timer['remaining_seconds'];
    final status = timer['status'];
    if (total is! int ||
        remaining is! int ||
        total < 0 ||
        remaining < 0 ||
        remaining > total ||
        status is! String ||
        !CookTimerStatus.values.map((value) => value.name).contains(status)) {
      _invalidBackup();
    }
  }
}
