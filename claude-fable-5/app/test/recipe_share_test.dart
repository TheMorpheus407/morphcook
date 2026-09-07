import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/app_state.dart';
import 'package:morphcook/data/store.dart';
import 'package:morphcook/logic/cook/cook_controller.dart';
import 'package:morphcook/logic/sharing/recipe_share.dart';
import 'package:morphcook/models/personal_recipe.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/recipe_image.dart';

import 'helpers.dart';

PersonalRecipe _recipe({
  int number = 1,
  String title = 'Family soup',
  List<PersonalRecipeStep>? steps,
}) => PersonalRecipe(
  id: 'personal-${number.toRadixString(16).padLeft(32, '0')}',
  title: title,
  description: 'A recipe to share.',
  sourceUrl: 'https://example.com/soup',
  sourceAuthor: 'A cook',
  sourceDiet: 'VegetarianDiet',
  timeMinutes: 30,
  servings: 2,
  ingredients: [
    PersonalRecipeIngredient(
      name: 'carrots',
      qty: 200,
      unit: 'g',
      note: 'peeled',
    ),
    PersonalRecipeIngredient(
      name: 'salt to taste',
      qty: 1,
      unit: 'raw',
      hasQuantity: false,
    ),
  ],
  steps:
      steps ??
      [PersonalRecipeStep(text: 'Simmer and serve.', timerMinutes: 10)],
  createdAt: DateTime.utc(2026, 1, 2),
  updatedAt: DateTime.utc(2026, 1, 3),
);

RecipeImage _image(String id, {bool different = false}) => RecipeImage(
  recipeId: id,
  bytes: different
      ? base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a5X8AAAAASUVORK5CYII=',
        )
      : testPngBytes(),
  updatedAt: DateTime.utc(2026, 1, 3),
);

Future<AppState> _state({MemoryStore? store}) async {
  final state = AppState(
    store: store ?? MemoryStore(),
    corpus: await loadRealCorpus(all: false),
  );
  await state.load();
  return state;
}

Uint8List _encode(dynamic value) =>
    Uint8List.fromList(utf8.encode(jsonEncode(value)));

Map<String, dynamic> _payload({
  List<dynamic>? recipes,
  List<dynamic>? images,
}) => {
  'format': recipeShareFormat,
  'version': recipeShareVersion,
  'recipes': recipes ?? [_recipe().toJson()],
  if (images != null) 'images': images,
};

class _FailingShareStore extends MemoryStore {
  bool failCollections = false;
  bool failImages = false;
  int collectionWrites = 0;
  int imageWrites = 0;

  @override
  Future<void> putCollections(Map<String, String> values) async {
    collectionWrites++;
    await super.putCollections(values);
    if (failCollections) {
      failCollections = false;
      throw const FileSystemException(
        'simulated collection failure after write',
      );
    }
  }

  @override
  Future<void> putRecipeImageBytesBatch(Map<String, Uint8List> values) async {
    imageWrites++;
    await super.putRecipeImageBytesBatch(values);
    if (failImages) {
      failImages = false;
      throw const FileSystemException('simulated image failure after write');
    }
  }
}

void main() {
  test(
    'structurally dense cookbooks within model limits remain importable',
    () {
      final recipes = List.generate(
        500,
        (index) => PersonalRecipe(
          id: 'personal-${index.toRadixString(16).padLeft(32, '0')}',
          title: 'a',
          timeMinutes: 1,
          servings: 1,
          ingredients: List.generate(
            100,
            (_) => PersonalRecipeIngredient(
              name: 'a',
              qty: 1,
              unit: 'raw',
              note: 'a',
              hasQuantity: false,
            ),
          ),
          steps: List.generate(
            15,
            (_) => PersonalRecipeStep(text: 'a', timerMinutes: 1),
          ),
          createdAt: DateTime.utc(1970),
          updatedAt: DateTime.utc(1970),
        ),
      );
      final data = RecipeShareData(recipes: recipes);
      final bytes = encodeRecipeShare(data);
      final imported = decodeRecipeShare(bytes);
      expect(imported.recipes, hasLength(500));
      expect(imported.recipes.last.toJson(), recipes.last.toJson());
      expect(imported.recipes.first.ingredients, hasLength(100));
      expect(imported.recipes.first.steps, hasLength(15));
    },
  );

  test(
    'shallow containers and scalar floods are bounded before JSON decoding',
    () {
      for (final values in [
        List<Object>.filled(120001, const []),
        List<Object>.filled(1000001, ''),
      ]) {
        // Without structural preflight this reaches unknown-field validation
        // after allocation and reports invalidFormat instead of tooLarge.
        final bytes = _encode({..._payload(), 'unexpected': values});
        expect(bytes.length, lessThan(maxRecipeShareBytes));
        expect(
          () => decodeRecipeShare(bytes),
          throwsA(
            isA<RecipeShareException>().having(
              (e) => e.failure,
              'failure',
              RecipeShareFailure.tooLarge,
            ),
          ),
        );
      }
    },
  );

  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'personal export roundtrip preserves text, raw amounts, source and optional photos',
    () async {
      final state = await _state();
      final recipe = _recipe();
      await state.savePersonalRecipe(recipe);
      await state.setRecipeImage(recipe.id, testPngBytes());
      final textOnly = await collectRecipeShare(state, recipeId: recipe.id);
      expect(textOnly.images, isEmpty);
      final data = await collectRecipeShare(
        state,
        recipeId: recipe.id,
        includeImages: true,
      );
      final restored = decodeRecipeShare(encodeRecipeShare(data));
      expect(restored.recipes.single.toJson(), recipe.toJson());
      expect(restored.images.single.bytes, testPngBytes());
      expect(restored.images.single.recipeId, recipe.id);
      expect(() => restored.recipes.clear(), throwsUnsupportedError);
      final text = recipeShareText(restored, lang: 'en');
      expect(text, contains('200 g carrots (peeled)'));
      expect(text, contains('- salt to taste'));
      expect(text, isNot(contains('1 raw')));
      expect(text, contains('timer: 10 min'));
      expect(text, contains(recipe.sourceUrl!));
      expect(text, contains('Diet (unverified): VegetarianDiet'));
    },
  );

  test(
    'cookbook export includes saved and unsaved personal recipes exactly once',
    () async {
      final state = await _state();
      await state.savePersonalRecipe(_recipe());
      await state.savePersonalRecipe(
        _recipe(number: 2, title: 'Second recipe'),
      );
      await state.toggleSaved(_recipe(number: 2).id);
      await state.toggleSaved('doener-vegan');
      final share = await collectRecipeShare(state);
      expect(share.recipes, hasLength(3));
      expect(share.recipes.map((recipe) => recipe.id).toSet(), hasLength(3));
      expect(
        share.recipes.map((recipe) => recipe.title),
        containsAll(['Family soup', 'Second recipe']),
      );
    },
  );

  test(
    'bundled export resolves localized names and stable independent recipe and photo ids',
    () async {
      final state = await _state();
      await state.updateProfile(const Profile(lang: 'de'));
      const id = 'doener-vegan';
      final bundled = (await state.recipeById(id))!;
      await state.setRecipeImage(id, testPngBytes());
      final data = await collectRecipeShare(
        state,
        recipeId: id,
        includeImages: true,
      );
      final recipe = data.recipes.single;
      expect(recipe.title, bundled.title.of('de'));
      expect(recipe.id, startsWith('personal-'));
      expect(recipe.id, isNot(id));
      expect(
        recipe.ingredients.first.name,
        state.corpus.dictionary
            .byId(bundled.ingredients.first.ingredientId)!
            .name
            .of('de'),
      );
      expect(recipe.ingredients.first.qty, bundled.ingredients.first.qty);
      expect(recipe.steps.first.text, bundled.steps.first.text.of('de'));
      expect(
        recipe.steps.map((step) => step.timerMinutes),
        bundled.steps.map((step) => step.timerMinutes),
      );
      expect(data.images.single.recipeId, recipe.id);
      expect(
        (await collectRecipeShare(state, recipeId: id)).recipes.single.toJson(),
        recipe.toJson(),
      );
      expect(recipeShareText(data, lang: 'de'), contains('Zubereitung:'));
    },
  );

  test(
    'sharing never serializes profile, searches, plans, history or saved dates',
    () async {
      final state = await _state();
      final recipe = _recipe();
      await state.completeOnboarding(
        const Profile(
          name: 'private-profile-secret',
          avoidFlags: {'private-allergy-secret'},
        ),
      );
      await state.savePersonalRecipe(recipe);
      await state.assignMeal('2099-W44', 'mon.dinner', recipe.id);
      await state.logContentRequest('private-search-secret');
      await state.addToShoppingList([(recipe.asRecipe(), 2)]);
      await state.persistCookProgress(
        CookProgress(recipeId: recipe.id, stepIndex: 0, servings: 7),
      );
      final data = await collectRecipeShare(state);
      final json = utf8.decode(encodeRecipeShare(data));
      final text = recipeShareText(data, lang: 'en');
      expect(
        (jsonDecode(json) as Map).keys,
        unorderedEquals(['format', 'version', 'recipes']),
      );
      for (final secret in [
        'private-profile-secret',
        'private-allergy-secret',
        'private-search-secret',
        '2099-W44',
        'shopping_history',
        'cook_progress',
        'saved_at',
      ]) {
        expect(json, isNot(contains(secret)));
        expect(text, isNot(contains(secret)));
      }
    },
  );

  test(
    'share decoding rejects backup data, bad versions, duplicate IDs and invalid images',
    () {
      final recipe = _recipe();
      for (final payload in [
        {
          'schema_version': 2,
          'profile': {},
          'personal_recipes': [recipe.toJson()],
        },
        {..._payload(), 'version': 2},
        {
          ..._payload(),
          'profile': {'name': 'do not import me'},
        },
        _payload(recipes: []),
        _payload(recipes: [recipe.toJson(), recipe.toJson()]),
        _payload(
          recipes: [
            {...recipe.toJson(), 'title': ''},
          ],
        ),
        _payload(images: [_image(_recipe(number: 2).id).toBackupJson()]),
        _payload(
          images: [
            _image(recipe.id).toBackupJson(),
            _image(recipe.id).toBackupJson(),
          ],
        ),
        _payload(
          images: [
            {
              ..._image(recipe.id).toBackupJson(),
              'data_base64': base64Encode([1, 2, 3]),
            },
          ],
        ),
      ]) {
        expect(
          () => decodeRecipeShare(_encode(payload)),
          throwsA(isA<RecipeShareException>()),
        );
      }
      expect(
        () => decodeRecipeShare(Uint8List.fromList([0xff])),
        throwsA(isA<RecipeShareException>()),
      );
    },
  );

  test(
    'share decoding bounds file bytes, nesting, recipe and ingredient counts',
    () {
      for (final bytes in [
        Uint8List(maxRecipeShareBytes + 1),
        Uint8List.fromList(utf8.encode('${'[' * 34}0${']' * 34}')),
        _encode(
          _payload(
            recipes: List.filled(maxPersonalRecipes + 1, _recipe().toJson()),
          ),
        ),
        _encode(
          _payload(
            recipes: [
              {
                ..._recipe().toJson(),
                'ingredients': List.filled(
                  maxPersonalRecipeIngredients + 1,
                  _recipe().ingredients.first.toJson(),
                ),
              },
            ],
          ),
        ),
      ]) {
        expect(
          () => decodeRecipeShare(bytes),
          throwsA(
            isA<RecipeShareException>().having(
              (e) => e.failure,
              'reason',
              RecipeShareFailure.tooLarge,
            ),
          ),
        );
      }
    },
  );

  test(
    'old recipe ingredient JSON defaults remain compatible in share files',
    () {
      final recipe = _recipe().toJson();
      (recipe['ingredients'] as List).removeLast();
      final imported = decodeRecipeShare(_encode(_payload(recipes: [recipe])));
      expect(imported.recipes.single.ingredients.single.hasQuantity, isTrue);
    },
  );

  test(
    'merge preserves every unrelated collection and survives reopening',
    () async {
      final state = await _state();
      final local = _recipe();
      final incoming = _recipe(number: 2, title: 'Received soup');
      await state.completeOnboarding(
        const Profile(name: 'local person', lang: 'de'),
      );
      await state.savePersonalRecipe(local);
      await state.setRecipeImage(local.id, testPngBytes());
      await state.assignMeal('2026-W37', 'tue.lunch', local.id);
      await state.logContentRequest('local secret');
      await state.addToShoppingList([(local.asRecipe(), 3)]);
      await state.logCooked(local.id);
      await state.persistCookProgress(
        CookProgress(
          recipeId: local.id,
          stepIndex: 0,
          servings: 8,
          remainingTimerSeconds: 41,
        ),
      );
      final before = {
        for (final key in [
          'meal_plan',
          'history',
          'shopping_list',
          'shopping_history',
          'content_requests',
          'cook_progress',
        ])
          key: state.store.getCollection(key),
      };
      final added = await state.importSharedRecipes(
        RecipeShareData(recipes: [incoming], images: [_image(incoming.id)]),
      );
      expect(added, 1);
      expect(state.personalRecipeById(local.id)!.toJson(), local.toJson());
      expect(state.recipeImageFor(local.id)!.bytes, testPngBytes());
      expect(state.isSaved(local.id), isTrue);
      expect(state.isSaved(incoming.id), isTrue);
      expect(state.profile.name, 'local person');
      expect(state.cookProgress!.remainingTimerSeconds, 41);
      for (final entry in before.entries) {
        expect(state.store.getCollection(entry.key), entry.value);
      }
      final reloaded = AppState(store: state.store, corpus: state.corpus);
      await reloaded.load();
      expect(
        reloaded.personalRecipeById(incoming.id)!.toJson(),
        incoming.toJson(),
      );
      expect(reloaded.recipeImageFor(incoming.id)!.bytes, testPngBytes());
      expect(reloaded.profile.toJson(), state.profile.toJson());
      expect(reloaded.cookProgress!.toJson(), state.cookProgress!.toJson());
      expect(
        reloaded.shoppingList.map((item) => item.toJson()),
        state.shoppingList.map((item) => item.toJson()),
      );
    },
  );

  test(
    'conflicting IDs make stable copies and remap photos without overwriting local data',
    () async {
      final state = await _state();
      final local = _recipe();
      final received = local.copyWith(title: 'Someone else’s soup');
      await state.savePersonalRecipe(local);
      await state.setRecipeImage(local.id, testPngBytes());
      final data = RecipeShareData(
        recipes: [received],
        images: [_image(received.id, different: true)],
      );
      expect(await state.importSharedRecipes(data), 1);
      final copy = state.personalRecipes.singleWhere(
        (recipe) => recipe.id != local.id,
      );
      expect(copy.title, received.title);
      expect(state.recipeImageFor(copy.id)!.bytes, data.images.single.bytes);
      expect(state.recipeImageFor(local.id)!.bytes, testPngBytes());
      expect(state.personalRecipeById(local.id)!.toJson(), local.toJson());
      expect(await state.importSharedRecipes(data), 0);
      expect(state.personalRecipes, hasLength(2));
    },
  );

  test(
    'same-content duplicates skip, missing photos attach, conflicting photos get copies',
    () async {
      final state = await _state();
      final recipe = _recipe();
      await state.savePersonalRecipe(recipe);
      expect(
        await state.importSharedRecipes(RecipeShareData(recipes: [recipe])),
        0,
      );
      expect(
        await state.importSharedRecipes(
          RecipeShareData(recipes: [recipe], images: [_image(recipe.id)]),
        ),
        0,
      );
      expect(state.recipeImageFor(recipe.id)!.bytes, testPngBytes());
      final changedPhoto = RecipeShareData(
        recipes: [recipe],
        images: [_image(recipe.id, different: true)],
      );
      expect(await state.importSharedRecipes(changedPhoto), 1);
      expect(state.personalRecipes, hasLength(2));
      expect(await state.importSharedRecipes(changedPhoto), 0);
      expect(state.personalRecipes, hasLength(2));
    },
  );

  test(
    'conflict copy receives photos later without another duplicate',
    () async {
      final state = await _state();
      final local = _recipe();
      await state.savePersonalRecipe(local);
      final incoming = local.copyWith(title: 'Received variant');
      expect(
        await state.importSharedRecipes(RecipeShareData(recipes: [incoming])),
        1,
      );
      final copyId = state.personalRecipes.last.id;
      expect(
        await state.importSharedRecipes(
          RecipeShareData(recipes: [incoming], images: [_image(incoming.id)]),
        ),
        0,
      );
      expect(state.personalRecipes.last.id, copyId);
      expect(state.recipeImageFor(copyId)!.bytes, testPngBytes());
    },
  );

  test(
    'concurrent import requests serialize and cannot create duplicates',
    () async {
      final state = await _state();
      final data = RecipeShareData(recipes: [_recipe()]);
      expect(
        await Future.wait([
          state.importSharedRecipes(data),
          state.importSharedRecipes(data),
        ]),
        [1, 0],
      );
      expect(state.personalRecipes, hasLength(1));
    },
  );

  test(
    'image and collection write failures roll back recipes, saved IDs and image bytes',
    () async {
      for (final failImages in [false, true]) {
        final store = _FailingShareStore();
        final state = await _state(store: store);
        final local = _recipe();
        final incoming = _recipe(number: 2);
        await state.savePersonalRecipe(local);
        await state.setRecipeImage(local.id, testPngBytes());
        if (failImages) {
          store.failImages = true;
        } else {
          store.failCollections = true;
        }
        final data = RecipeShareData(
          recipes: [incoming],
          images: [_image(incoming.id)],
        );
        await expectLater(
          state.importSharedRecipes(data),
          throwsA(isA<FileSystemException>()),
        );
        expect(state.personalRecipes.single.toJson(), local.toJson());
        expect(state.recipeImages.single.recipeId, local.id);
        expect(store.loadRecipeImageBytes().keys, [local.id]);
        final restored = AppState(store: store, corpus: state.corpus);
        await restored.load();
        expect(restored.personalRecipes.single.id, local.id);
        expect(restored.saved.map((recipe) => recipe.recipeId), [local.id]);
        expect(restored.recipeImages.single.recipeId, local.id);
        expect(await state.importSharedRecipes(data), 1);
      }
    },
  );

  test(
    'recipe count overflow is rejected before touching persistence',
    () async {
      final store = _FailingShareStore();
      await store.putCollection(
        'personal_recipes',
        jsonEncode([
          for (var i = 1; i <= maxPersonalRecipes; i++)
            _recipe(number: i).toJson(),
        ]),
      );
      final state = await _state(store: store);
      await expectLater(
        state.importSharedRecipes(
          RecipeShareData(recipes: [_recipe(number: 501)]),
        ),
        throwsA(isA<PersonalRecipeLimitException>()),
      );
      expect(store.collectionWrites, 0);
      expect(store.imageWrites, 0);
      expect(state.personalRecipes, hasLength(maxPersonalRecipes));
      expect(
        await state.importSharedRecipes(RecipeShareData(recipes: [_recipe()])),
        0,
      );
    },
  );

  test(
    'cumulative recipe text budget is checked before import writes',
    () async {
      final store = _FailingShareStore();
      final steps = List.generate(
        100,
        (_) => PersonalRecipeStep(text: 'x' * 5000),
      );
      final existing = [
        for (var i = 1; i <= 16; i++) _recipe(number: i, steps: steps),
      ];
      expect(personalRecipesFitBackup(existing), isTrue);
      await store.putCollection(
        'personal_recipes',
        jsonEncode(existing.map((recipe) => recipe.toJson()).toList()),
      );
      final state = await _state(store: store);
      await expectLater(
        state.importSharedRecipes(
          RecipeShareData(recipes: [_recipe(number: 17, steps: steps)]),
        ),
        throwsA(
          isA<PersonalRecipeLimitException>().having(
            (e) => e.reason,
            'reason',
            PersonalRecipeLimitReason.backupSize,
          ),
        ),
      );
      expect(store.collectionWrites, 0);
      expect(state.personalRecipes, hasLength(16));
    },
  );

  test(
    'aggregate photo count overflow is rejected before persistence writes',
    () async {
      final store = _FailingShareStore();
      final existing = [
        for (var i = 1; i <= maxBackupRecipeImages; i++) _recipe(number: i),
      ];
      final images = existing.map((recipe) => _image(recipe.id)).toList();
      await store.putCollection(
        'personal_recipes',
        jsonEncode(existing.map((recipe) => recipe.toJson()).toList()),
      );
      await store.putCollection(
        'recipe_image_metadata',
        jsonEncode(images.map((image) => image.metadata.toJson()).toList()),
      );
      await store.putRecipeImageBytesBatch({
        for (final image in images) image.recipeId: image.bytes,
      });
      final state = await _state(store: store);
      final incoming = _recipe(number: 101);
      final beforeWrites = store.imageWrites;
      await expectLater(
        state.importSharedRecipes(
          RecipeShareData(recipes: [incoming], images: [_image(incoming.id)]),
        ),
        throwsA(
          isA<RecipeShareException>().having(
            (e) => e.failure,
            'reason',
            RecipeShareFailure.tooLarge,
          ),
        ),
      );
      expect(store.collectionWrites, 0);
      expect(store.imageWrites, beforeWrites);
      expect(state.personalRecipes, hasLength(100));
      expect(state.recipeImages, hasLength(100));
    },
  );
}
