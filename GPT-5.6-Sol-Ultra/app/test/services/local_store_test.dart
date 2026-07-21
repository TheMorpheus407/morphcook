import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:morphcook/domain/models.dart';
import 'package:morphcook/services/cook_session_controller.dart';
import 'package:morphcook/services/local_store.dart';
import 'package:morphcook/services/shopping_service.dart';

void main() {
  test('memory store persists every offline collection', () async {
    final store = MemoryLocalApplicationStore();
    final savedAt = DateTime.utc(2026, 1, 2);
    await store.saveRecipe('recipe-a', savedAt: savedAt);
    await store.saveRecipe(
      'recipe-a',
      savedAt: savedAt.add(const Duration(days: 1)),
    );
    expect(await store.loadSavedRecipes(), <SavedRecipe>[
      SavedRecipe(recipeId: 'recipe-a', savedAt: savedAt),
    ]);

    final history = CookHistoryEntry(
      id: 'history-a',
      recipeId: 'recipe-a',
      cookedAt: DateTime.utc(2026, 2, 3),
      servings: 2,
    );
    await store.addHistory(history);
    expect(await store.loadHistory(), <CookHistoryEntry>[history]);

    final meal = MealPlanEntry(
      id: 'meal-a',
      date: DateTime(2026, 4, 13),
      slot: MealSlot.dinner,
      recipeId: 'recipe-a',
    );
    await store.assignMealPlan(meal);
    expect((await store.loadMealPlan()).at(meal.date, meal.slot), meal);

    final shopping = ShoppingEntry(
      id: 'garlic|clove',
      ingredientId: 'garlic',
      name: 'Garlic',
      quantity: 5,
      unit: 'clove',
      aisle: 'produce',
      addedAt: savedAt,
    );
    await store.putShoppingEntry(shopping);
    expect(await store.loadShoppingEntries(), <ShoppingEntry>[shopping]);

    await store.logContentRequest(
      ' Sushi ',
      languageCode: 'en',
      searchedAt: savedAt,
    );
    await store.logContentRequest(
      'sushi',
      languageCode: 'en',
      searchedAt: savedAt.add(const Duration(hours: 1)),
    );
    final requests = await store.loadContentRequests();
    expect(requests, hasLength(1));
    expect(requests.single.count, 2);
    expect(requests.single.normalizedQuery, 'sushi');

    final session = CookSessionSnapshot.fresh(
      recipeId: 'recipe-a',
      baseServings: 2,
      totalSteps: 3,
    );
    await store.saveCookSession(session);
    expect((await store.loadCookSession('recipe-a'))!.recipeId, 'recipe-a');

    final snapshot = await store.snapshot();
    expect(snapshot.savedRecipes, hasLength(1));
    expect(snapshot.history, hasLength(1));
    expect(snapshot.mealPlan.entries, hasLength(1));
    expect(snapshot.shoppingEntries, hasLength(1));
    expect(snapshot.contentRequests, hasLength(1));
    expect(snapshot.cookSessions, hasLength(1));
  });

  test('ISO week keys handle year boundaries', () {
    expect(isoWeekKey(DateTime(2025, 12, 29)), '2026-W01');
    expect(isoWeekKey(DateTime(2026, 1, 4)), '2026-W01');
    expect(weekdayKey(DateTime.sunday), 'sun');
  });

  test('Hive CE stores JSON maps and meal plans by week', () async {
    final directory = Directory(
      'test/services/.hive-${DateTime.now().microsecondsSinceEpoch}',
    );
    await directory.create(recursive: true);
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    Hive.init(directory.path);
    final prefix = 'test_${DateTime.now().microsecondsSinceEpoch}';
    final store = HiveLocalApplicationStore(
      hive: Hive,
      initializeHive: false,
      boxPrefix: prefix,
    );
    await store.initialize();
    addTearDown(store.close);

    final savedAt = DateTime.utc(2026, 4, 18, 12);
    await store.saveRecipe('recipe-a', savedAt: savedAt);
    await store.addHistory(
      CookHistoryEntry(
        id: 'history-a',
        recipeId: 'recipe-a',
        cookedAt: savedAt,
      ),
    );
    await store.assignMealPlan(
      MealPlanEntry(
        id: 'meal-a',
        date: DateTime(2026, 4, 13),
        slot: MealSlot.dinner,
        recipeId: 'recipe-a',
      ),
    );
    await store.putShoppingEntry(
      ShoppingEntry(
        id: 'garlic|clove',
        ingredientId: 'garlic',
        name: 'Garlic',
        quantity: 5,
        unit: 'clove',
        aisle: 'produce',
        addedAt: savedAt,
      ),
    );
    await store.logContentRequest(
      'ramen',
      languageCode: 'de',
      searchedAt: savedAt,
    );
    await store.saveCookSession(
      CookSessionSnapshot.fresh(
        recipeId: 'recipe-a',
        baseServings: 2,
        totalSteps: 2,
      ),
    );

    expect((await store.loadSavedRecipes()).single.savedAt, savedAt);
    expect((await store.loadHistory()).single.id, 'history-a');
    expect((await store.loadMealPlan()).entries, hasLength(1));
    expect((await store.loadShoppingEntries()).single.quantity, 5);
    expect((await store.loadContentRequests()).single.query, 'ramen');
    expect(await store.loadCookSession('recipe-a'), isNotNull);

    final weekBox = Hive.box<dynamic>('${prefix}_meal_plan');
    expect(weekBox.keys, contains('2026-W16'));
    expect((weekBox.get('2026-W16') as Map)['mon.dinner'], 'recipe-a');
  });
}
