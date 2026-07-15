import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/app_state.dart';
import 'package:morphcook/data/store.dart';
import 'package:morphcook/logic/backup/backup_service.dart';
import 'package:morphcook/models/collections.dart';
import 'package:morphcook/models/personal_recipe.dart';
import 'package:morphcook/models/profile.dart';

import 'helpers.dart';

Future<AppState> buildState() async {
  final corpus = await loadRealCorpus();
  final state = AppState(store: MemoryStore(), corpus: corpus);
  await state.load();
  return state;
}

PersonalRecipe personalRecipe({String title = 'My soup'}) => PersonalRecipe(
  id: 'personal-0123456789abcdef0123456789abcdef',
  title: title,
  description: 'A family note',
  timeMinutes: 25,
  servings: 3,
  ingredients: [
    PersonalRecipeIngredient(name: 'Secret spice', qty: 2, unit: 'tsp'),
  ],
  steps: [PersonalRecipeStep(text: 'Stir it in.')],
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

      final reloaded = AppState(store: state.store, corpus: state.corpus);
      await reloaded.load();
      expect(reloaded.shoppingList.single.customName, 'Secret spice');
    },
  );

  test('deleting a personal recipe removes dangling references', () async {
    final state = await buildState();
    final recipe = personalRecipe();
    await state.savePersonalRecipe(recipe);
    await state.assignMeal('2026-W29', 'tue.lunch', recipe.id);
    await state.logCooked(recipe.id);

    await state.deletePersonalRecipe(recipe.id);

    expect(state.personalRecipes, isEmpty);
    expect(state.isSaved(recipe.id), isFalse);
    expect(state.mealPlan, isEmpty);
    expect(state.history, isEmpty);
    expect(await state.recipeById(recipe.id), isNull);
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

    final export = BackupService.export(state.buildBackup());
    final imported = BackupService.import(export.gzipFile);

    final fresh = AppState(store: MemoryStore(), corpus: state.corpus);
    await fresh.load();
    await fresh.applyBackup(imported, merge: false);
    expect(fresh.profile.name, 'a');
    expect(fresh.isSaved('falafel-baked'), isTrue);
    expect(fresh.mealPlan['2026-W20']?['wed.lunch'], 'falafel-baked');
    expect(fresh.contentRequests, ['pho']);
    expect(fresh.personalRecipes.single.title, 'My soup');
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

  test('resetEverything wipes user state but not the corpus', () async {
    final state = await buildState();
    await state.completeOnboarding(const Profile(name: 'x'));
    await state.toggleSaved('doener-vegan');
    await state.resetEverything();
    expect(state.onboarded, isFalse);
    expect(state.saved, isEmpty);
    expect(state.corpus.dishes, isNotEmpty);
    expect(state.personalRecipes, isEmpty);
  });

  test('isoWeekKey matches the spec format', () {
    expect(isoWeekKey(DateTime(2026, 4, 15)), '2026-W16');
    expect(isoWeekKey(DateTime(2026, 1, 1)), '2026-W01');
  });
}
