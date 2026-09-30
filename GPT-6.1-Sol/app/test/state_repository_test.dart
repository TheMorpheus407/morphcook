import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/models.dart';
import 'package:morphcook/core/repository.dart';
import 'package:morphcook/core/shopping.dart';
import 'package:morphcook/state/app_state.dart';
import 'package:morphcook/state/storage.dart';
import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'launch loads only core; cuisine partitions load on demand without duplication',
    () async {
      final repo = RecipeRepository();
      await repo.initialize();
      expect(repo.loadedPartitions, {'core'});
      expect(repo.recipes.length, 52);
      await Future.wait([
        repo.loadPartition('cuisine-asian'),
        repo.loadPartition('cuisine-asian'),
      ]);
      expect(repo.recipes.length, 56);
      expect(repo.loadedPartitions, {'core', 'cuisine-asian'});
      await repo.loadAll();
      expect(repo.recipes.length, 64);
      expect(repo.searchIndex.length, 64);
      expect(repo.guide.length, repo.dictionary.entries.length);
    },
  );
  test(
    'bilingual indexed search supports ingredients, tags, profiles and extended content',
    () async {
      final repo = RecipeRepository();
      await repo.initialize();
      final profile = Profile(
        maxTimeMinutes: 120,
        calorieTolerance: 1000,
        lang: 'de',
      );
      final results = await repo.search('Apfel', {}, profile);
      expect(results, isNotEmpty);
      expect(repo.loadedPartitions, contains('extended'));
      expect(
        results.any((r) => r.ingredients.any((i) => i.id == 'apples')),
        isTrue,
      );
      profile.diet = 'vegan';
      final vegan = await repo.search('Alfredo', {'dinner'}, profile);
      expect(vegan.length, 2);
      expect(vegan.every((r) => !r.contains.contains('dairy')), isTrue);
      expect(
        await repo.search('a dish that does not exist', {}, profile),
        isEmpty,
      );
    },
  );
  test(
    'every recipe is bilingual, linked, fully authored and accurately flagged',
    () async {
      final repo = RecipeRepository();
      await repo.initialize();
      await repo.loadAll();
      for (final recipe in repo.recipes.values) {
        expect(recipe.steps.length, greaterThanOrEqualTo(3), reason: recipe.id);
        expect(recipe.ingredients, isNotEmpty);
        expect(recipe.servings, greaterThan(0));
        expect(repo.dishes[recipe.dishId]!.recipeIds, contains(recipe.id));
        expect(recipe.title.keys, containsAll(['en', 'de']));
        for (final ingredient in recipe.ingredients) {
          expect(
            recipe.contains.containsAll(
              repo.dictionary.flagsFor(ingredient.id),
            ),
            isTrue,
            reason: '${recipe.id} omits ${ingredient.id} flags',
          );
          expect(ingredient.quantity, greaterThan(0));
        }
        for (final step in recipe.steps) {
          expect(step.text['en']!.length, greaterThan(20));
          expect(step.text['de']!.length, greaterThan(20));
        }
        for (final entry in recipe.dimensions.entries) {
          expect(
            repo.ontology.dimensionValues(entry.key),
            contains(entry.value),
          );
        }
      }
    },
  );
  test(
    'saved IDs identify variants and survive profile changes and relaunch',
    () async {
      final state = await testState();
      state.toggleSaved('doener-classic');
      state.toggleSaved('doener-mushroom');
      state.updateProfile(state.profile.copy()..diet = 'vegan');
      await state.flush();
      expect(state.savedRecipes.length, 2);
      expect(
        state.isVisible(state.repository.recipes['doener-classic']!),
        isFalse,
      );
      final restarted = AppState(
        repository: RecipeRepository(),
        storage: state.storage,
      );
      await restarted.initialize();
      expect(
        restarted.saved.keys,
        containsAll(['doener-classic', 'doener-mushroom']),
      );
      expect(restarted.profile.diet, 'vegan');
      state.dispose();
      restarted.dispose();
    },
  );
  test(
    'meal drag swaps filled slots and carries serving counts, then moves to an empty slot',
    () async {
      final state = await testState();
      final first = state.repository.recipes['doener-mushroom']!;
      final second = state.repository.recipes['alfredo-classic']!;
      state.assignMeal('2026-W40', 'mon.dinner', first, servings: 4);
      state.assignMeal('2026-W40', 'tue.lunch', second, servings: 1);
      state.moveMeal('2026-W40', 'mon.dinner', 'tue.lunch');
      expect(state.mealPlan['2026-W40']!['mon.dinner'], second.id);
      expect(state.planServings['2026-W40:tue.lunch'], 4);
      expect(state.planServings['2026-W40:mon.dinner'], 1);
      state.moveMeal('2026-W40', 'tue.lunch', 'wed.dinner');
      expect(state.mealPlan['2026-W40']!['tue.lunch'], isNull);
      expect(state.planServings['2026-W40:tue.lunch'], isNull);
      state.exportWeek('2026-W40');
      final oil = state.shopping.firstWhere(
        (i) => i.ingredientId == 'olive-oil',
      );
      expect(oil.quantity, 30);
      expect(state.shoppingEvents.length, 2);
      await state.flush();
      state.dispose();
    },
  );
  test(
    'backup replace restores every collection and profile atomically',
    () async {
      final original = await testState();
      final recipe = original.repository.recipes['miso-ramen-tofu']!;
      original.toggleSaved(recipe.id);
      original.assignMeal('2026-W40', 'sun.dinner', recipe, servings: 4);
      original.addShopping([RecipeSelection(recipe, 4)]);
      original.logContentRequest('sushi');
      original.persistCook({
        'recipe_id': recipe.id,
        'step': 1,
        'servings': 4,
        'remaining_seconds': 0,
        'running': false,
      });
      original.profile.extra['b2b'] = {'company': 'Example'};
      await original.flush();
      final backup = original.backupData();
      final target = await testState();
      target.toggleSaved('doener-classic');
      await target.flush();
      await target.restore(backup, merge: false);
      expect(target.saved.keys, [recipe.id]);
      expect(target.planServings['2026-W40:sun.dinner'], 4);
      expect(
        target.shopping.map((i) => i.toJson()),
        original.shopping.map((i) => i.toJson()),
      );
      expect(target.shoppingEvents.length, 1);
      expect(target.contentRequests, {'sushi'});
      expect(target.cookProgress!['step'], 1);
      expect(target.profile.extra['b2b'], {'company': 'Example'});
      final restarted = AppState(
        repository: RecipeRepository(),
        storage: target.storage,
      );
      await restarted.initialize();
      expect(restarted.saved.keys, [recipe.id]);
      expect(restarted.profile.extra['b2b'], {'company': 'Example'});
      original.dispose();
      target.dispose();
      restarted.dispose();
    },
  );
  test(
    'merge is idempotent, keeps current profile and wins meal conflicts',
    () async {
      final source = await testState();
      source.toggleSaved('doener-mushroom');
      source.assignMeal(
        '2026-W40',
        'mon.dinner',
        source.repository.recipes['doener-mushroom']!,
      );
      source.completeCook(source.repository.recipes['doener-mushroom']!, 2);
      source.addShopping([
        RecipeSelection(source.repository.recipes['doener-mushroom']!, 2),
      ]);
      await source.flush();
      final target = await testState();
      target.profile.name = 'Current';
      target.toggleSaved('alfredo-classic');
      target.assignMeal(
        '2026-W40',
        'mon.dinner',
        target.repository.recipes['alfredo-classic']!,
      );
      await target.flush();
      await target.restore(source.backupData(), merge: true);
      await target.restore(source.backupData(), merge: true);
      expect(target.profile.name, 'Current');
      expect(target.saved.length, 2);
      expect(target.mealPlan['2026-W40']!['mon.dinner'], 'alfredo-classic');
      expect(target.history.length, 1);
      expect(target.shoppingEvents.length, 1);
      expect(
        target.shopping
            .firstWhere((i) => i.ingredientId == 'olive-oil')
            .quantity,
        15,
      );
      source.dispose();
      target.dispose();
    },
  );
  test('invalid restores leave all previous data intact', () async {
    final state = await testState();
    state.toggleSaved('doener-mushroom');
    await state.flush();
    final before = jsonEncode(state.backupData()..remove('exported_at'));
    await expectLater(
      state.restore({...backupFixture(), 'schema_version': 99}, merge: false),
      throwsA(anything),
    );
    expect(jsonEncode(state.backupData()..remove('exported_at')), before);
    state.dispose();
  });
  test(
    'restoring an extended cooking session loads its recipe immediately',
    () async {
      final target = await testState(all: false);
      final data = backupFixture()
        ..['saved'] = <String>[]
        ..['meal_plan'] = <String, dynamic>{}
        ..['cook_progress'] = {
          'recipe_id': 'banana-bread-oat',
          'step': 1,
          'servings': 2,
          'remaining_seconds': 0,
          'running': false,
          'deadline': null,
          'timer_completed': false,
        };
      expect(target.repository.recipes, isNot(contains('banana-bread-oat')));
      await target.restore(data, merge: false);
      expect(target.repository.recipes, contains('banana-bread-oat'));
      expect(target.cookProgress!['recipe_id'], 'banana-bread-oat');
      target.dispose();
    },
  );
  test(
    'profile snapshot recovers if preferences write was interrupted',
    () async {
      final storage = MemoryStorage();
      await storage.writeProfile(Profile(name: 'Old').toJson());
      await storage.writeCollections({
        'profile_snapshot': Profile(
          name: 'Recovered',
          onboarded: true,
        ).toJson(),
      });
      final state = AppState(repository: RecipeRepository(), storage: storage);
      await state.initialize();
      expect(state.profile.name, 'Recovered');
      expect(state.profile.onboarded, isTrue);
      state.dispose();
    },
  );
  test('local wish queries deduplicate and never leave the device', () async {
    final state = await testState();
    state.logContentRequest(' SUSHI ');
    state.logContentRequest('sushi');
    expect(state.contentRequests, {'sushi'});
    await state.flush();
    state.dispose();
  });
  test('missing assets fail with a retryable partition error', () async {
    final bundle = _FailingBundle();
    final repo = RecipeRepository(bundle: bundle);
    await repo.initialize();
    await expectLater(
      repo.loadPartition('extended'),
      throwsA(isA<FlutterError>()),
    );
    bundle.fail = false;
    await repo.loadPartition('extended');
    expect(repo.loadedPartitions, contains('extended'));
  });
}

class _FailingBundle extends CachingAssetBundle {
  bool fail = true;
  @override
  Future<ByteData> load(String key) {
    if (key == 'assets/extended-recipes.json' && fail) {
      throw FlutterError('missing');
    }
    return rootBundle.load(key);
  }
}
