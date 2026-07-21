import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/domain/models.dart';
import 'package:morphcook/services/backup_file_facade.dart';
import 'package:morphcook/services/backup_repository.dart';
import 'package:morphcook/services/backup_service.dart';
import 'package:morphcook/services/local_store.dart';
import 'package:morphcook/services/profile_store.dart';

void main() {
  test('collect maps user-owned stores to schema 1', () async {
    final profileStore = MemoryProfileStore(
      profile: UserProfile(name: 'Mira', languageCode: 'de'),
    );
    final localStore = MemoryLocalApplicationStore();
    await localStore.saveRecipe('recipe-a', savedAt: DateTime.utc(2026, 4, 18));
    await localStore.addHistory(
      CookHistoryEntry(
        id: 'history-a',
        recipeId: 'recipe-a',
        cookedAt: DateTime.utc(2026, 4, 18),
      ),
    );
    await localStore.assignMealPlan(
      MealPlanEntry(
        id: 'meal-a',
        date: DateTime(2026, 4, 13),
        slot: MealSlot.dinner,
        recipeId: 'recipe-a',
      ),
    );
    await localStore.logContentRequest(
      'sushi',
      languageCode: 'de',
      searchedAt: DateTime.utc(2026, 4, 18),
    );
    final repository = BackupRepository(
      profileStore: profileStore,
      localStore: localStore,
      backupService: BackupService(),
    );

    final backup = await repository.collect();
    expect(backup.profile['name'], 'Mira');
    expect(backup.saved, <String>['recipe-a']);
    expect(backup.history.single['id'], 'history-a');
    expect(backup.mealPlan['2026-W16']!['mon.dinner'], 'recipe-a');
    expect(backup.contentRequests, <String>['sushi']);
  });

  test(
    'merge restore preserves local records and adds imported data',
    () async {
      final profileStore = MemoryProfileStore(
        profile: UserProfile(name: 'Old', languageCode: 'en'),
      );
      final localStore = MemoryLocalApplicationStore();
      await localStore.saveRecipe('old', savedAt: DateTime.utc(2026, 1, 1));
      final service = BackupService();
      final repository = BackupRepository(
        profileStore: profileStore,
        localStore: localStore,
        backupService: service,
      );
      final imported = BackupData(
        profile: <String, dynamic>{'name': 'New', 'lang': 'de'},
        saved: const <String>['new'],
        mealPlan: const <String, Map<String, String>>{},
        history: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'history-new',
            'recipe_id': 'new',
            'cooked_at': '2026-04-18T12:00:00.000Z',
            'servings': 1,
          },
        ],
        exportedAt: DateTime.utc(2026, 4, 18),
      );

      final result = await repository.restore(
        imported,
        mode: RestoreMode.merge,
      );
      expect(result.savedCount, 2);
      expect(
        (await localStore.loadSavedRecipes()).map((item) => item.recipeId),
        containsAll(<String>['old', 'new']),
      );
      expect((await profileStore.loadProfile())!.name, 'New');
      expect((await localStore.loadHistory()).single.id, 'history-new');
    },
  );

  test('replace restore removes data absent from the import', () async {
    final profileStore = MemoryProfileStore(
      profile: UserProfile(name: 'Old'),
      settings: const AppSettings(quickNextTapEnabled: true),
    );
    final localStore = MemoryLocalApplicationStore();
    await localStore.saveRecipe('old');
    final repository = BackupRepository(
      profileStore: profileStore,
      localStore: localStore,
      backupService: BackupService(),
    );
    final imported = BackupData(
      profile: const <String, dynamic>{},
      saved: const <String>['new'],
      mealPlan: const <String, Map<String, String>>{},
      history: const <Map<String, dynamic>>[],
    );

    await repository.restore(imported, mode: RestoreMode.replace);
    expect((await localStore.loadSavedRecipes()).single.recipeId, 'new');
    expect(await profileStore.loadProfile(), isNull);
    // App settings are installation preferences and are not erased by a
    // profile-less backup.
    expect((await profileStore.loadSettings()).quickNextTapEnabled, isTrue);
  });

  test('file facade shares both siblings and restores a picked file', () async {
    final profileStore = MemoryProfileStore(profile: UserProfile(name: 'Mira'));
    final localStore = MemoryLocalApplicationStore();
    await localStore.saveRecipe('recipe-a');
    final service = BackupService();
    final repository = BackupRepository(
      profileStore: profileStore,
      localStore: localStore,
      backupService: service,
    );
    final gateway = _FakeGateway();
    final facade = BackupFileFacade(repository: repository, gateway: gateway);

    await facade.exportAndShare(password: 'secret');
    expect(gateway.shared, isNotNull);
    expect(gateway.shared!.jsonEncrypted, isTrue);
    expect(
      service.detectEncoding(gateway.shared!.gzipBytes),
      BackupEncoding.gzip,
    );

    gateway.picked = PickedBackupFile(
      name: BackupExportBundle.gzipFileName,
      bytes: gateway.shared!.gzipBytes,
    );
    await localStore.clearUserData();
    final result = await facade.pickAndRestore(mode: RestoreMode.replace);
    expect(result!.savedCount, 1);
    expect((await localStore.loadSavedRecipes()).single.recipeId, 'recipe-a');

    gateway.picked = null;
    expect(await facade.pickAndRestore(mode: RestoreMode.merge), isNull);
  });

  test('rejects unsafe profile ranges before changing local data', () async {
    final profileStore = MemoryProfileStore(
      profile: UserProfile(name: 'Original'),
    );
    final localStore = MemoryLocalApplicationStore();
    await localStore.saveRecipe('kept');
    final repository = BackupRepository(
      profileStore: profileStore,
      localStore: localStore,
      backupService: BackupService(),
    );
    final imported = BackupData(
      profile: <String, dynamic>{
        'name': 'Broken',
        'lang': 'en',
        'calorie_target': 5000,
      },
      saved: const <String>['lost'],
      mealPlan: const <String, Map<String, String>>{},
      history: const <Map<String, dynamic>>[],
    );

    await expectLater(
      repository.restore(imported, mode: RestoreMode.replace),
      throwsA(isA<BackupFormatException>()),
    );
    expect((await profileStore.loadProfile())!.name, 'Original');
    expect((await localStore.loadSavedRecipes()).single.recipeId, 'kept');
  });
}

class _FakeGateway implements BackupFileGateway {
  BackupExportBundle? shared;
  PickedBackupFile? picked;

  @override
  Future<PickedBackupFile?> pickBackup() async => picked;

  @override
  Future<void> shareBackup(
    BackupExportBundle bundle, {
    Rect? sharePositionOrigin,
    String title = 'MorphCook backup',
    String? text,
  }) async => shared = bundle;
}
