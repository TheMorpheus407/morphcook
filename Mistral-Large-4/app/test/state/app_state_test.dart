import 'dart:io';

import 'package:flutter_test/flutter_test.dart' hide Matcher;
import 'package:morphcook/core/corpus.dart';
import 'package:morphcook/core/matching.dart';
import 'package:morphcook/core/model/localized.dart';
import 'package:morphcook/core/model/profile.dart';
import 'package:morphcook/core/model/recipe.dart';
import 'package:morphcook/state/app_state.dart';
import 'package:morphcook/state/backup_service.dart';
import 'package:morphcook/state/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AppState tests run against a real (temp-dir) Hive + a mocked
/// SharedPreferences, with the real bundled corpus for shopping/aisle data.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Corpus corpus;
  late Matcher matcher;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('morphcook_state_test_');
    corpus = Corpus();
    await corpus.init();
    matcher = Matcher(ontology: corpus.ontology, ingredients: corpus.ingredients);
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await AppStorage.resetForTest();
    await AppStorage.initForTest(tempDir.path);
  });

  Future<AppState> freshState() async {
    final state = AppState();
    await state.init(corpus: corpus, matcher: matcher);
    return state;
  }

  Recipe recipe({
    String id = 'r1',
    int servings = 2,
    List<IngredientLine> ingredients = const [],
  }) =>
      Recipe(
        id: id,
        dishId: 'dish',
        title: const LocalizedText({'en': 'dish'}),
        subtitle: const LocalizedText({'en': 'sub'}),
        diet: 'classic',
        effort: 'easy',
        timeMinutes: 20,
        caloriesPerServing: 500,
        servings: servings,
        contains: const {},
        attributes: const {},
        tags: const [],
        mealType: 'lunch',
        ingredients: ingredients,
        steps: const [CookStep(text: LocalizedText({'en': 'cook it'})),],
        macros: const Macros(kcal: 500, proteinG: 20, carbsG: 50, fatG: 18),
      );

  group('profile', () {
    test('starts with the documented defaults', () async {
      final state = await freshState();
      expect(state.profile.toJson(), const UserProfile().toJson());
      expect(state.onboardingComplete, false);
    });

    test('updateProfile persists across AppState instances', () async {
      final state = await freshState();
      await state.updateProfile(const UserProfile(
        name: 'sam',
        lang: 'de',
        calorieTarget: 700,
        avoidFlags: {'dairy'},
        onboardingComplete: true,
      ));
      final reloaded = await freshState();
      expect(reloaded.profile.name, 'sam');
      expect(reloaded.profile.lang, 'de');
      expect(reloaded.profile.calorieTarget, 700);
      expect(reloaded.profile.avoidFlags, {'dairy'});
      expect(reloaded.onboardingComplete, true);
    });

    test('setLang and completeOnboarding are profile updates', () async {
      final state = await freshState();
      await state.setLang('de');
      expect(state.profile.lang, 'de');
      await state.completeOnboarding();
      expect(state.onboardingComplete, true);
    });
  });

  group('cookbook (saved variants)', () {
    test('toggleSaved adds newest-first and removes again', () async {
      final state = await freshState();
      await state.toggleSaved('doener-classic');
      await state.toggleSaved('ramen-vegan');
      expect(state.savedRecipeIds, ['ramen-vegan', 'doener-classic']);
      expect(state.isSaved('doener-classic'), true);
      await state.toggleSaved('doener-classic');
      expect(state.isSaved('doener-classic'), false);
      expect(state.savedRecipeIds, ['ramen-vegan']);
      // persisted
      final reloaded = await freshState();
      expect(reloaded.savedRecipeIds, ['ramen-vegan']);
    });
  });

  group('history', () {
    test('addToHistory is newest-first and feeds lastCookedByRecipe', () async {
      final state = await freshState();
      await state.addToHistory('doener-classic', at: DateTime.utc(2026, 10, 1));
      await state.addToHistory('ramen-vegan', at: DateTime.utc(2026, 10, 5));
      await state.addToHistory('doener-classic', at: DateTime.utc(2026, 10, 3));
      expect(state.history.first.recipeId, 'ramen-vegan');
      final lastCooked = state.lastCookedByRecipe;
      expect(lastCooked['doener-classic'], DateTime.utc(2026, 10, 3));
      expect(lastCooked['ramen-vegan'], DateTime.utc(2026, 10, 5));
    });
  });

  group('meal plan', () {
    test('set, read, move and clear slots', () async {
      final state = await freshState();
      await state.setMealSlot('2026-W41', 'mon.dinner', 'doener-classic');
      expect(state.recipeIdAt('2026-W41', 'mon.dinner'), 'doener-classic');
      await state.moveMealSlot('2026-W41', 'mon.dinner', '2026-W41', 'tue.lunch');
      expect(state.recipeIdAt('2026-W41', 'mon.dinner'), isNull);
      expect(state.recipeIdAt('2026-W41', 'tue.lunch'), 'doener-classic');
      await state.setMealSlot('2026-W41', 'tue.lunch', null);
      expect(state.recipeIdAt('2026-W41', 'tue.lunch'), isNull);
      // moving an empty slot is a no-op
      await state.moveMealSlot('2026-W41', 'wed.breakfast', '2026-W41', 'thu.dinner');
      expect(state.recipeIdAt('2026-W41', 'thu.dinner'), isNull);
    });

    test('weekRecipes resolves planned recipes and export adds them to market', () async {
      final state = await freshState();
      await state.setMealSlot('2026-W41', 'mon.dinner', 'doener-classic');
      await state.setMealSlot('2026-W41', 'tue.dinner', 'doener-vegan');
      final week = state.weekRecipes('2026-W41');
      expect(week.map((r) => r.id), containsAll(['doener-classic', 'doener-vegan']));
      final added = await state.exportWeekToShopping('2026-W41');
      expect(added, greaterThan(0));
      expect(state.shoppingItems, isNotEmpty);
    });
  });

  group('shopping', () {
    test('adding a recipe twice aggregates unit-aware (2 + 2 cloves = 4)', () async {
      final state = await freshState();
      final r = recipe(ingredients: [
        const IngredientLine(ingredientId: 'garlic', amount: 2, unit: 'cloves'),
      ]);
      await state.addRecipeToShopping(r);
      await state.addRecipeToShopping(r);
      expect(state.shoppingItems.length, 1);
      final item = state.shoppingItems.single;
      expect(item.ingredientId, 'garlic');
      expect(item.amount, 4);
      expect(item.unit, 'cloves');
      expect(item.sourceRecipeIds, ['r1']);
      expect(state.shoppingLog.length, 2);
    });

    test('volume units convert when merging across recipes', () async {
      final state = await freshState();
      final a = recipe(id: 'a', ingredients: [
        const IngredientLine(ingredientId: 'olive-oil', amount: 100, unit: 'ml'),
      ]);
      final b = recipe(id: 'b', ingredients: [
        const IngredientLine(ingredientId: 'olive-oil', amount: 2, unit: 'tbsp'), // 30 ml
      ]);
      await state.addRecipeToShopping(a);
      await state.addRecipeToShopping(b);
      final item = state.shoppingItems.single;
      expect(item.amount, 130);
      expect(item.unit, 'ml');
      expect(item.sourceRecipeIds, containsAll(['a', 'b']));
    });

    test('servings scale the added amounts', () async {
      final state = await freshState();
      final r = recipe(
        servings: 2,
        ingredients: [const IngredientLine(ingredientId: 'doener-meat', amount: 300, unit: 'g')],
      );
      await state.addRecipeToShopping(r, servings: 4);
      expect(state.shoppingItems.single.amount, 600);
    });

    test('check, clear-checked and clear-all', () async {
      final state = await freshState();
      final r = recipe(ingredients: [
        const IngredientLine(ingredientId: 'garlic', amount: 2, unit: 'cloves'),
        const IngredientLine(ingredientId: 'doener-meat', amount: 300, unit: 'g'),
      ]);
      await state.addRecipeToShopping(r);
      await state.toggleShoppingItem('garlic', true);
      expect(state.shoppingItems.singleWhere((i) => i.ingredientId == 'garlic').checked, true);
      await state.clearCheckedShopping();
      expect(state.shoppingItems.map((i) => i.ingredientId), ['doener-meat']);
      await state.clearShopping();
      expect(state.shoppingItems, isEmpty);
    });

    test('shoppingByAisle groups by aisle in editorial order', () async {
      final state = await freshState();
      final r = recipe(ingredients: [
        const IngredientLine(ingredientId: 'garlic', amount: 2, unit: 'cloves'), // produce
        const IngredientLine(ingredientId: 'doener-meat', amount: 300, unit: 'g'), // meat
        const IngredientLine(ingredientId: 'milk', amount: 200, unit: 'ml'), // dairy
      ]);
      await state.addRecipeToShopping(r);
      final grouped = state.shoppingByAisle();
      expect(grouped.keys, orderedEquals(['produce', 'meat', 'dairy']));
    });
  });

  group('content requests', () {
    test('logContentRequest trims, dedups and persists', () async {
      final state = await freshState();
      await state.logContentRequest('  korean stew  ');
      await state.logContentRequest('korean stew');
      await state.logContentRequest('   ');
      expect(state.contentRequests, ['korean stew']);
      final reloaded = await freshState();
      expect(reloaded.contentRequests, ['korean stew']);
    });
  });

  group('backup restore', () {
    Map<String, dynamic> backupPayload({
      bool onboarding = false,
      List<String> saved = const [],
      Map<String, dynamic> mealPlan = const {},
      List<String> requests = const [],
    }) =>
        BackupService().buildPayload(
          profile: UserProfile(
            name: 'backup-user',
            lang: 'de',
            onboardingComplete: onboarding,
          ).toJson(),
          saved: saved,
          mealPlan: mealPlan,
          history: const [],
          contentRequests: requests,
        );

    test('replace wipes local data before importing', () async {
      final state = await freshState();
      await state.toggleSaved('local-only');
      await state.logContentRequest('local query');
      await state.restoreFromBackup(
        backupPayload(saved: ['doener-classic'], requests: ['backup query']),
        replace: true,
      );
      expect(state.savedRecipeIds, ['doener-classic']);
      expect(state.contentRequests, ['backup query']);
      expect(state.profile.name, 'backup-user');
    });

    test('merge unions collections and the backup wins slot conflicts', () async {
      final state = await freshState();
      await state.toggleSaved('local-only');
      await state.setMealSlot('2026-W41', 'mon.dinner', 'local-recipe');
      await state.restoreFromBackup(
        backupPayload(
          saved: ['doener-classic'],
          mealPlan: {
            '2026-W41': {'mon.dinner': 'backup-recipe', 'tue.lunch': 'doener-vegan'},
          },
        ),
        replace: false,
      );
      expect(state.savedRecipeIds, containsAll(['local-only', 'doener-classic']));
      expect(state.recipeIdAt('2026-W41', 'mon.dinner'), 'backup-recipe');
      expect(state.recipeIdAt('2026-W41', 'tue.lunch'), 'doener-vegan');
    });

    test('restore never traps the user in onboarding', () async {
      final state = await freshState();
      await state.completeOnboarding();
      await state.restoreFromBackup(backupPayload(onboarding: false), replace: false);
      expect(state.onboardingComplete, true);
    });

    test('restored data survives a reload', () async {
      final state = await freshState();
      await state.restoreFromBackup(
        backupPayload(saved: ['ramen-vegan'], requests: ['kimchi']),
        replace: true,
      );
      final reloaded = await freshState();
      expect(reloaded.savedRecipeIds, ['ramen-vegan']);
      expect(reloaded.contentRequests, ['kimchi']);
      expect(reloaded.profile.name, 'backup-user');
    });
  });
}
