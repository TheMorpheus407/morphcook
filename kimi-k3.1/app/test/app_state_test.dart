import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/user_data.dart';
import 'package:morphcook/services/local_store.dart';
import 'package:morphcook/services/recipe_repository.dart';
import 'package:morphcook/state/app_state.dart';

import 'test_helpers.dart';

void main() {
  test('saved items always reference a specific recipe variant', () async {
    final repository = RecipeRepository();
    final store = MemoryStateStore();
    final app = AppState(repository: repository, store: store);
    await app.initialize();
    app.toggleSaved('vegan-doener');
    expect(app.snapshot.saved.single.recipeId, 'vegan-doener');
    expect(app.isSaved('vegan-doener'), isTrue);
    app.toggleSaved('vegan-doener');
    expect(app.snapshot.saved, isEmpty);
    await app.writesSettled;
    expect(store.snapshotWrites, greaterThan(0));
  });

  test('planner assigns, swaps and exports exact recipe IDs', () async {
    final repository = RecipeRepository();
    final first = testRecipe(
      id: 'first',
      ingredients: [ingredient('garlic', 2, 'clove')],
    );
    final second = testRecipe(
      id: 'second',
      ingredients: [ingredient('basil', 1, 'bunch')],
    );
    repository.recipes.addAll({'first': first, 'second': second});
    final app = AppState(repository: repository, store: MemoryStateStore());
    await app.initialize();
    app.assignRecipe('2026-W16', 'mon.dinner', 'first');
    app.assignRecipe('2026-W16', 'tue.dinner', 'second');
    app.moveSlot(
      sourceWeek: '2026-W16',
      sourceSlot: 'mon.dinner',
      targetWeek: '2026-W16',
      targetSlot: 'tue.dinner',
    );
    expect(app.snapshot.mealPlan['2026-W16']?['mon.dinner'], 'second');
    expect(app.snapshot.mealPlan['2026-W16']?['tue.dinner'], 'first');
    await app.exportWeekToShopping('2026-W16');
    expect(app.snapshot.shoppingRecipeIds, containsAll(['first', 'second']));
    expect(app.snapshot.shoppingEvents, hasLength(2));
    app.clearSlot('2026-W16', 'mon.dinner');
    expect(app.snapshot.mealPlan['2026-W16']?['mon.dinner'], isNull);
  });

  test(
    'cook completion creates history and clears resumable progress',
    () async {
      final now = DateTime.utc(2026, 4, 18, 12);
      final app = AppState(
        repository: RecipeRepository(),
        store: MemoryStateStore(),
        clock: () => now,
      );
      await app.initialize();
      app.saveCookProgress(
        CookProgress(
          recipeId: 'r1',
          stepIndex: 2,
          remainingSeconds: 10,
          servings: 3,
          isRunning: false,
          updatedAt: now,
        ),
      );
      app.completeCook('r1', 3);
      expect(app.snapshot.history.single.recipeId, 'r1');
      expect(app.snapshot.history.single.servings, 3);
      expect(app.snapshot.cookProgress, isEmpty);
      expect(app.lastCooked['r1'], now);
    },
  );

  test(
    'restore merge keeps local collections and uses imported profile',
    () async {
      final app = AppState(
        repository: RecipeRepository(),
        store: MemoryStateStore(
          profile: const Profile(name: 'Local', onboardingComplete: true),
        ),
      );
      await app.initialize();
      app.toggleSaved('local');
      final incoming = BackupData(
        profile: const Profile(
          name: 'Imported',
          lang: 'de',
          onboardingComplete: true,
        ),
        snapshot: UserSnapshot(
          saved: [
            SavedRecipe(
              recipeId: 'incoming',
              savedAt: DateTime.utc(2026, 1, 1),
            ),
          ],
        ),
      );
      await app.restore(incoming, merge: true);
      expect(app.profile.name, 'Imported');
      expect(
        app.snapshot.saved.map((item) => item.recipeId),
        containsAll(['local', 'incoming']),
      );
      await app.restore(incoming, merge: false);
      expect(app.snapshot.saved.single.recipeId, 'incoming');
    },
  );

  test('ISO week keys handle year boundaries and Mondays', () {
    expect(weekKey(DateTime(2026, 1, 1)), '2026-W01');
    expect(weekKey(DateTime(2026, 4, 13)), '2026-W16');
    expect(weekKey(DateTime(2027, 1, 1)), '2026-W53');
    expect(mondayForWeek(DateTime(2026, 4, 18)), DateTime(2026, 4, 13));
  });
}
