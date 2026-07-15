import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/app_state.dart';
import 'package:morphcook/data/store.dart';
import 'package:morphcook/logic/backup/backup_service.dart';
import 'package:morphcook/logic/backup/crypto.dart';
import 'package:morphcook/logic/cook/cook_controller.dart';
import 'package:morphcook/models/collections.dart';
import 'package:morphcook/models/personal_recipe.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/recipe_image.dart';

import 'helpers.dart';

Future<AppState> buildState({PersistenceStore? store}) async {
  final corpus = await loadRealCorpus();
  final state = AppState(store: store ?? MemoryStore(), corpus: corpus);
  await state.load();
  return state;
}

class FailingBulkStore extends MemoryStore {
  bool failNextBulkWrite = false;

  @override
  Future<void> putCollections(Map<String, String> collections) async {
    if (failNextBulkWrite) {
      failNextBulkWrite = false;
      throw const FileSystemException('simulated full storage');
    }
    await super.putCollections(collections);
  }
}

class FailingProfileStore extends MemoryStore {
  @override
  Future<void> saveProfile(Profile profile) async {
    throw const FileSystemException('simulated profile write failure');
  }
}

class FailingMutationStore extends MemoryStore {
  bool failNextBulkWriteAfterPersisting = false;
  bool failNextImageWriteAfterPersisting = false;
  bool failNextImageRemovalAfterPersisting = false;

  @override
  Future<void> putCollections(Map<String, String> collections) async {
    await super.putCollections(collections);
    if (failNextBulkWriteAfterPersisting) {
      failNextBulkWriteAfterPersisting = false;
      throw const FileSystemException('simulated collection write failure');
    }
  }

  @override
  Future<void> putRecipeImageBytes(String recipeId, Uint8List bytes) async {
    await super.putRecipeImageBytes(recipeId, bytes);
    if (failNextImageWriteAfterPersisting) {
      failNextImageWriteAfterPersisting = false;
      throw const FileSystemException('simulated image write failure');
    }
  }

  @override
  Future<void> removeRecipeImageBytes(String recipeId) async {
    await super.removeRecipeImageBytes(recipeId);
    if (failNextImageRemovalAfterPersisting) {
      failNextImageRemovalAfterPersisting = false;
      throw const FileSystemException('simulated image removal failure');
    }
  }
}

PersonalRecipe personalRecipe({
  String id = 'personal-0123456789abcdef0123456789abcdef',
  String title = 'My soup',
  List<PersonalRecipeStep>? steps,
}) => PersonalRecipe(
  id: id,
  title: title,
  description: 'A family note',
  timeMinutes: 25,
  servings: 3,
  ingredients: [
    PersonalRecipeIngredient(name: 'Secret spice', qty: 2, unit: 'tsp'),
  ],
  steps: steps ?? [PersonalRecipeStep(text: 'Stir it in.')],
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 1),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('onboarding persists the profile', () async {
    final state = await buildState();
    expect(state.onboarded, isFalse);
    await state.completeOnboarding(
      const Profile(name: 'cedric', lang: 'de', avoidFlags: {'vegan'}),
    );
    expect(state.onboarded, isTrue);
    expect(state.profile.lang, 'de');

    // A fresh AppState over the same store sees the data.
    final reloaded = AppState(store: state.store, corpus: state.corpus);
    await reloaded.load();
    expect(reloaded.onboarded, isTrue);
    expect(reloaded.profile.name, 'cedric');
  });

  test('onboarding stays pending when the profile cannot be saved', () async {
    final store = FailingProfileStore();
    final state = await buildState(store: store);

    await expectLater(
      state.completeOnboarding(const Profile(lang: 'de')),
      throwsA(isA<FileSystemException>()),
    );

    expect(state.onboarded, isFalse);
    expect(store.onboardingComplete, isFalse);
    expect(state.profile.lang, 'en');
  });

  test('cookbook saves specific variants and toggles', () async {
    final state = await buildState();
    await state.toggleSaved('doener-vegan');
    expect(state.isSaved('doener-vegan'), isTrue);
    expect(state.isSaved('doener-classic'), isFalse);
    await state.toggleSaved('doener-vegan');
    expect(state.isSaved('doener-vegan'), isFalse);
  });

  test(
    'personal recipes persist, auto-save and resolve like corpus recipes',
    () async {
      final state = await buildState();
      final recipe = personalRecipe();
      await state.savePersonalRecipe(recipe);

      expect(state.personalRecipes, hasLength(1));
      expect(state.isSaved(recipe.id), isTrue);
      expect((await state.recipeById(recipe.id))?.title.of('en'), 'My soup');
      expect(state.dishById(recipe.dishId)?.recipeIds, [recipe.id]);
      expect(await state.visibleVariants(recipe.dishId), hasLength(1));

      final reloaded = AppState(store: state.store, corpus: state.corpus);
      await reloaded.load();
      expect(reloaded.personalRecipeById(recipe.id)?.title, 'My soup');
      expect(reloaded.isSaved(recipe.id), isTrue);
    },
  );

  test(
    'failed personal recipe creation rolls back recipe and saved id',
    () async {
      final store = FailingMutationStore();
      final state = await buildState(store: store);
      store.failNextBulkWriteAfterPersisting = true;

      await expectLater(
        state.savePersonalRecipe(personalRecipe()),
        throwsA(isA<FileSystemException>()),
      );

      expect(state.personalRecipes, isEmpty);
      expect(state.saved, isEmpty);
      final reloaded = AppState(store: store, corpus: state.corpus);
      await reloaded.load();
      expect(reloaded.personalRecipes, isEmpty);
      expect(reloaded.saved, isEmpty);
    },
  );

  test(
    'personal recipe edits keep references and free-text shopping names',
    () async {
      final state = await buildState();
      final recipe = personalRecipe();
      await state.savePersonalRecipe(recipe);
      await state.assignMeal('2026-W29', 'mon.dinner', recipe.id);
      await state.savePersonalRecipe(
        recipe.copyWith(
          title: 'Better soup',
          updatedAt: DateTime.utc(2026, 7, 2),
        ),
      );

      expect(state.mealPlan['2026-W29']?['mon.dinner'], recipe.id);
      expect(
        (await state.recipeById(recipe.id))?.title.of('en'),
        'Better soup',
      );
      await state.addToShoppingList([
        ((await state.recipeById(recipe.id))!, 1),
      ]);
      expect(state.shoppingList.single.customName, 'Secret spice');
      expect(state.shoppingHistory.single.customName, 'Secret spice');

      final reloaded = AppState(store: state.store, corpus: state.corpus);
      await reloaded.load();
      expect(reloaded.shoppingList.single.customName, 'Secret spice');
    },
  );

  test('editing a personal recipe invalidates stale cook progress', () async {
    final state = await buildState();
    final recipe = personalRecipe(
      steps: [
        PersonalRecipeStep(text: 'First.'),
        PersonalRecipeStep(text: 'Second.', timerMinutes: 2),
      ],
    );
    await state.savePersonalRecipe(recipe);
    await state.persistCookProgress(
      CookProgress(recipeId: recipe.id, stepIndex: 1, servings: 3),
    );

    await state.savePersonalRecipe(
      recipe.copyWith(
        steps: [PersonalRecipeStep(text: 'Only step now.')],
        updatedAt: DateTime.utc(2026, 7, 2),
      ),
    );

    expect(state.cookProgress, isNull);
    final reloaded = AppState(store: state.store, corpus: state.corpus);
    await reloaded.load();
    expect(reloaded.cookProgress, isNull);
  });

  test(
    'recipe images persist byte-for-byte and can be replaced or removed',
    () async {
      final state = await buildState();
      final first = testPngBytes();
      await state.setRecipeImage(
        'doener-vegan',
        first,
        updatedAt: DateTime.utc(2026, 7, 15),
      );
      expect(state.recipeImageFor('doener-vegan')?.bytes, orderedEquals(first));

      final reloaded = AppState(store: state.store, corpus: state.corpus);
      await reloaded.load();
      expect(
        reloaded.recipeImageFor('doener-vegan')?.bytes,
        orderedEquals(first),
      );

      final replacement = [...first, 0];
      await reloaded.setRecipeImage('doener-vegan', replacement);
      expect(
        reloaded.recipeImageFor('doener-vegan')?.bytes,
        orderedEquals(replacement),
      );
      await reloaded.removeRecipeImage('doener-vegan');
      expect(reloaded.recipeImageFor('doener-vegan'), isNull);

      final finalReload = AppState(store: state.store, corpus: state.corpus);
      await finalReload.load();
      expect(finalReload.recipeImageFor('doener-vegan'), isNull);
    },
  );

  test('failed image writes and removals restore bytes and metadata', () async {
    final store = FailingMutationStore();
    final state = await buildState(store: store);
    final original = testPngBytes();
    await state.setRecipeImage('doener-vegan', original);

    final replacement = [...original, 0];
    store.failNextBulkWriteAfterPersisting = true;
    await expectLater(
      state.setRecipeImage('doener-vegan', replacement),
      throwsA(isA<FileSystemException>()),
    );
    expect(
      state.recipeImageFor('doener-vegan')?.bytes,
      orderedEquals(original),
    );
    var reloaded = AppState(store: store, corpus: state.corpus);
    await reloaded.load();
    expect(
      reloaded.recipeImageFor('doener-vegan')?.bytes,
      orderedEquals(original),
    );

    store.failNextImageRemovalAfterPersisting = true;
    await expectLater(
      state.removeRecipeImage('doener-vegan'),
      throwsA(isA<FileSystemException>()),
    );
    expect(state.recipeImageFor('doener-vegan'), isNotNull);
    reloaded = AppState(store: store, corpus: state.corpus);
    await reloaded.load();
    expect(
      reloaded.recipeImageFor('doener-vegan')?.bytes,
      orderedEquals(original),
    );
  });

  test('failed initial image byte write removes the partial record', () async {
    final store = FailingMutationStore();
    final state = await buildState(store: store);
    store.failNextImageWriteAfterPersisting = true;

    await expectLater(
      state.setRecipeImage('doener-vegan', testPngBytes()),
      throwsA(isA<FileSystemException>()),
    );

    expect(state.recipeImageFor('doener-vegan'), isNull);
    expect(store.loadRecipeImageBytes(), isEmpty);
    final reloaded = AppState(store: store, corpus: state.corpus);
    await reloaded.load();
    expect(reloaded.recipeImageFor('doener-vegan'), isNull);
  });

  test('deleting a personal recipe removes dangling references', () async {
    final state = await buildState();
    final recipe = personalRecipe();
    await state.savePersonalRecipe(recipe);
    await state.assignMeal('2026-W29', 'tue.lunch', recipe.id);
    await state.logCooked(recipe.id);
    await state.setRecipeImage(recipe.id, testPngBytes());

    await state.deletePersonalRecipe(recipe.id);

    expect(state.personalRecipes, isEmpty);
    expect(state.isSaved(recipe.id), isFalse);
    expect(state.mealPlan, isEmpty);
    expect(state.history, isEmpty);
    expect(state.recipeImageFor(recipe.id), isNull);
    expect(await state.recipeById(recipe.id), isNull);
  });

  test('failed personal recipe deletion restores all references', () async {
    final store = FailingMutationStore();
    final state = await buildState(store: store);
    final recipe = personalRecipe();
    await state.savePersonalRecipe(recipe);
    await state.assignMeal('2026-W29', 'tue.lunch', recipe.id);
    await state.logCooked(recipe.id);
    await state.setRecipeImage(recipe.id, testPngBytes());
    store.failNextImageRemovalAfterPersisting = true;

    await expectLater(
      state.deletePersonalRecipe(recipe.id),
      throwsA(isA<FileSystemException>()),
    );

    expect(state.personalRecipeById(recipe.id), isNotNull);
    expect(state.isSaved(recipe.id), isTrue);
    expect(state.mealPlan['2026-W29']?['tue.lunch'], recipe.id);
    expect(state.history.single.recipeId, recipe.id);
    expect(state.recipeImageFor(recipe.id), isNotNull);
    final reloaded = AppState(store: store, corpus: state.corpus);
    await reloaded.load();
    expect(reloaded.personalRecipeById(recipe.id), isNotNull);
    expect(reloaded.isSaved(recipe.id), isTrue);
    expect(reloaded.mealPlan['2026-W29']?['tue.lunch'], recipe.id);
    expect(reloaded.history.single.recipeId, recipe.id);
    expect(reloaded.recipeImageFor(recipe.id), isNotNull);
  });

  test('meal plan assign / move / clear', () async {
    final state = await buildState();
    await state.assignMeal('2026-W24', 'mon.dinner', 'curry-chickpea');
    await state.assignMeal('2026-W24', 'tue.dinner', 'ramen-vegan');
    // Move mon.dinner onto tue.dinner: occupants swap.
    await state.moveMeal('2026-W24', 'mon.dinner', 'tue.dinner');
    expect(state.mealPlan['2026-W24']?['tue.dinner'], 'curry-chickpea');
    expect(state.mealPlan['2026-W24']?['mon.dinner'], 'ramen-vegan');
    await state.clearMeal('2026-W24', 'tue.dinner');
    expect(state.mealPlan['2026-W24']?.containsKey('tue.dinner'), isFalse);
  });

  test('shopping list aggregates and records history for insights', () async {
    final state = await buildState();
    final doener = state.corpus.loadedRecipeById('doener-vegan')!;
    await state.addToShoppingList([(doener, 1.0)]);
    expect(state.shoppingList, isNotEmpty);
    expect(state.shoppingHistory, isNotEmpty);
    final before = state.shoppingList.length;
    // Adding the same recipe again merges rather than duplicating lines.
    await state.addToShoppingList([(doener, 1.0)]);
    expect(state.shoppingList.length, before);
  });

  test('zero-result searches are logged once as content requests', () async {
    final state = await buildState();
    await state.logContentRequest('Sushi');
    await state.logContentRequest('sushi  ');
    expect(state.contentRequests, ['sushi']);
  });

  test('visibleVariants respects the profile, bestVariant picks one', () async {
    final state = await buildState();
    await state.updateProfile(const Profile(avoidFlags: {'vegan'}));
    final variants = await state.visibleVariants('doener');
    expect(variants.map((r) => r.id), contains('doener-vegan'));
    expect(variants.map((r) => r.id), isNot(contains('doener-classic')));
    final best = await state.bestVariant('doener');
    expect(best?.id, 'doener-vegan');
  });

  test('backup roundtrip through AppState (replace)', () async {
    final state = await buildState();
    await state.completeOnboarding(const Profile(name: 'a', lang: 'en'));
    await state.toggleSaved('falafel-baked');
    await state.assignMeal('2026-W20', 'wed.lunch', 'falafel-baked');
    await state.logContentRequest('pho');
    await state.savePersonalRecipe(personalRecipe());
    await state.setRecipeImage('falafel-baked', testPngBytes());

    final export = BackupService.export(state.buildBackup());
    final imported = BackupService.import(export.gzipFile!);

    final fresh = AppState(store: MemoryStore(), corpus: state.corpus);
    await fresh.load();
    await fresh.applyBackup(imported, merge: false);
    expect(fresh.profile.name, 'a');
    expect(fresh.isSaved('falafel-baked'), isTrue);
    expect(fresh.mealPlan['2026-W20']?['wed.lunch'], 'falafel-baked');
    expect(fresh.contentRequests, ['pho']);
    expect(fresh.personalRecipes.single.title, 'My soup');
    expect(
      fresh.recipeImageFor('falafel-baked')?.bytes,
      orderedEquals(testPngBytes()),
    );
  });

  test('backup merge keeps local data', () async {
    final state = await buildState();
    await state.toggleSaved('ramen-vegan');
    final incoming = BackupData(
      profile: const Profile(name: 'b'),
      saved: [
        SavedRecipe(
          recipeId: 'croissants-classic',
          savedAt: DateTime.utc(2026, 5, 1),
        ),
      ],
      mealPlan: const {},
      history: const [],
    );
    await state.applyBackup(incoming, merge: true);
    expect(state.isSaved('ramen-vegan'), isTrue);
    expect(state.isSaved('croissants-classic'), isTrue);
    expect(state.profile.name, 'b');
  });

  test('backup replace removes recipe images absent from the import', () async {
    final state = await buildState();
    await state.setRecipeImage('doener-vegan', testPngBytes());
    await state.applyBackup(
      const BackupData(
        profile: Profile(name: 'replacement'),
        saved: [],
        mealPlan: {},
        history: [],
      ),
      merge: false,
    );
    expect(state.recipeImageFor('doener-vegan'), isNull);

    final reloaded = AppState(store: state.store, corpus: state.corpus);
    await reloaded.load();
    expect(reloaded.recipeImageFor('doener-vegan'), isNull);
  });

  test('backup replace clears active shopping and cook progress', () async {
    final state = await buildState();
    final recipe = state.corpus.loadedRecipeById('doener-vegan')!;
    await state.addToShoppingList([(recipe, 1)]);
    await state.persistCookProgress(
      const CookProgress(recipeId: 'doener-vegan', stepIndex: 0, servings: 2),
    );

    await state.applyBackup(
      const BackupData(
        profile: Profile(name: 'replacement'),
        saved: [],
        mealPlan: {},
        history: [],
      ),
      merge: false,
    );

    expect(state.shoppingList, isEmpty);
    expect(state.cookProgress, isNull);
    final reloaded = AppState(store: state.store, corpus: state.corpus);
    await reloaded.load();
    expect(reloaded.shoppingList, isEmpty);
    expect(reloaded.cookProgress, isNull);
  });

  test('backup apply rejects an image for an unknown recipe', () async {
    final state = await buildState();
    final incoming = BackupData(
      profile: const Profile(),
      saved: const [],
      mealPlan: const {},
      history: const [],
      recipeImages: [
        RecipeImage(
          recipeId: 'not-a-real-recipe',
          bytes: testPngBytes(),
          updatedAt: DateTime.utc(2026, 7, 15),
        ),
      ],
    );

    await expectLater(
      state.applyBackup(incoming, merge: false),
      throwsA(
        isA<DecryptionException>().having(
          (error) => error.reason,
          'reason',
          DecryptionFailure.invalidFormat,
        ),
      ),
    );
    expect(state.recipeImages, isEmpty);
  });

  test(
    'failed backup persistence rolls back old state and image bytes',
    () async {
      final store = FailingBulkStore();
      final state = await buildState(store: store);
      await state.completeOnboarding(const Profile(name: 'before'));
      await state.toggleSaved('doener-vegan');
      await state.setRecipeImage('doener-vegan', testPngBytes());
      store.failNextBulkWrite = true;

      await expectLater(
        state.applyBackup(
          BackupData(
            profile: const Profile(name: 'after'),
            saved: const [],
            mealPlan: const {},
            history: const [],
            recipeImages: [
              RecipeImage(
                recipeId: 'falafel-baked',
                bytes: testPngBytes(),
                updatedAt: DateTime.utc(2026, 7, 15),
              ),
            ],
          ),
          merge: false,
        ),
        throwsA(isA<FileSystemException>()),
      );

      expect(state.profile.name, 'before');
      expect(state.isSaved('doener-vegan'), isTrue);
      expect(state.recipeImageFor('doener-vegan'), isNotNull);
      expect(state.recipeImageFor('falafel-baked'), isNull);
      final reloaded = AppState(store: store, corpus: state.corpus);
      await reloaded.load();
      expect(reloaded.profile.name, 'before');
      expect(reloaded.isSaved('doener-vegan'), isTrue);
      expect(reloaded.recipeImageFor('doener-vegan'), isNotNull);
      expect(reloaded.recipeImageFor('falafel-baked'), isNull);
    },
  );

  test('personal recipe creation enforces the backup-safe limit', () async {
    final state = await buildState();
    final recipes = [
      for (var i = 0; i < maxPersonalRecipes; i++)
        personalRecipe(
          id: 'personal-${i.toRadixString(16).padLeft(32, '0')}',
          title: 'Recipe $i',
        ),
    ];
    await state.applyBackup(
      BackupData(
        profile: const Profile(),
        saved: const [],
        mealPlan: const {},
        history: const [],
        personalRecipes: recipes,
      ),
      merge: false,
    );

    await expectLater(
      state.savePersonalRecipe(
        personalRecipe(
          id: 'personal-ffffffffffffffffffffffffffffffff',
          title: 'One too many',
        ),
      ),
      throwsA(isA<PersonalRecipeLimitException>()),
    );
  });

  test('personal recipe saving enforces the cumulative text budget', () async {
    final state = await buildState();
    final longStep = List<String>.filled(maxPersonalStepLength, 'x').join();
    PersonalRecipe largeRecipe(int index) => personalRecipe(
      id: 'personal-${index.toRadixString(16).padLeft(32, '0')}',
      title: 'Large recipe $index',
      steps: [
        for (var i = 0; i < maxPersonalRecipeSteps; i++)
          PersonalRecipeStep(text: longStep),
      ],
    );

    final accepted = <PersonalRecipe>[];
    PersonalRecipe? overflow;
    for (var i = 0; i < maxPersonalRecipes; i++) {
      final candidate = largeRecipe(i);
      if (personalRecipesFitBackup([...accepted, candidate])) {
        accepted.add(candidate);
      } else {
        overflow = candidate;
        break;
      }
    }
    expect(accepted, isNotEmpty);
    expect(overflow, isNotNull);
    await state.applyBackup(
      BackupData(
        profile: const Profile(),
        saved: const [],
        mealPlan: const {},
        history: const [],
        personalRecipes: accepted,
      ),
      merge: false,
    );

    await expectLater(
      state.savePersonalRecipe(overflow!),
      throwsA(
        isA<PersonalRecipeLimitException>().having(
          (error) => error.reason,
          'reason',
          PersonalRecipeLimitReason.backupSize,
        ),
      ),
    );
  });

  test('resetEverything wipes user state but not the corpus', () async {
    final state = await buildState();
    await state.completeOnboarding(const Profile(name: 'x'));
    await state.toggleSaved('doener-vegan');
    await state.setRecipeImage('doener-vegan', testPngBytes());
    await state.resetEverything();
    expect(state.onboarded, isFalse);
    expect(state.saved, isEmpty);
    expect(state.corpus.dishes, isNotEmpty);
    expect(state.personalRecipes, isEmpty);
    expect(state.recipeImages, isEmpty);
  });

  test('isoWeekKey matches the spec format', () {
    expect(isoWeekKey(DateTime(2026, 4, 15)), '2026-W16');
    expect(isoWeekKey(DateTime(2026, 1, 1)), '2026-W01');
  });
}
