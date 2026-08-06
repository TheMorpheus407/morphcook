import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:morphcook/data/app_state.dart';
import 'package:morphcook/models/models.dart';
import 'package:morphcook/services/backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late List<Box> boxes;
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final dir = await Directory.systemTemp.createTemp('morphcook_test');
    Hive.init(dir.path);
    boxes = [
      await Hive.openBox('cookbook'),
      await Hive.openBox('history'),
      await Hive.openBox('meal_plan'),
      await Hive.openBox('shopping'),
      await Hive.openBox('shopping_checked'),
      await Hive.openBox('events'),
    ];
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    for (final b in boxes) {
      await b.clear();
    }
    AppState.debugReset();
  });

  Future<AppState> buildState() async {
    final state = AppState.instance;
    await state.init(
      prefs: prefs,
      cookbookBox: Hive.box('cookbook'),
      historyBox: Hive.box('history'),
      mealPlanBox: Hive.box('meal_plan'),
      shoppingBox: Hive.box('shopping'),
      checkedBox: Hive.box('shopping_checked'),
      eventsBox: Hive.box('events'),
    );
    return state;
  }

  test('profile persists across instances', () async {
    final state = await buildState();
    state.patchProfile((p) {
      p.name = 'ada';
      p.lang = 'de';
      p.avoidFlags.add('vegan');
    });
    final reloaded = await buildState();
    expect(reloaded.profile.name, 'ada');
    expect(reloaded.profile.lang, 'de');
    expect(reloaded.profile.avoidFlags, {'vegan'});
  });

  test('cookbook save/toggle and ordering', () async {
    final state = await buildState();
    await Future<void>.delayed(const Duration(milliseconds: 2));
    state.toggleSaved('r1');
    await Future<void>.delayed(const Duration(milliseconds: 2));
    state.toggleSaved('r2');
    expect(state.savedEntries.map((e) => e.recipeId), ['r2', 'r1']);
    state.toggleSaved('r1');
    expect(state.savedEntries, hasLength(1));
  });

  test('history records, orders desc, lastCooked and clear', () async {
    final state = await buildState();
    state.recordCook('r1', at: DateTime(2026, 1, 1));
    state.recordCook('r2', at: DateTime(2026, 1, 2));
    expect(state.history.map((e) => e.recipeId), ['r2', 'r1']);
    expect(state.cookedCount('r1'), 1);
    expect(state.lastCookedByRecipe['r2'], DateTime(2026, 1, 2));
    await state.clearHistory();
    expect(state.history, isEmpty);
  });

  test('meal plan set/get/clear', () async {
    final state = await buildState();
    state.setSlot('2026-W32', slotKey('mon', 'dinner'), 'r1');
    state.setSlot('2026-W32', slotKey('tue', 'lunch'), 'r2');
    expect(state.week('2026-W32')[slotKey('mon', 'dinner')], 'r1');
    state.setSlot('2026-W32', slotKey('mon', 'dinner'), null);
    expect(state.week('2026-W32').containsKey(slotKey('mon', 'dinner')),
        isFalse);
  });

  test('shopping lines, servings, checked, clear-checked', () async {
    final state = await buildState();
    state.addShoppingLine('r1', servings: 2);
    state.addShoppingLine('r2', servings: 4);
    state.updateShoppingServings('r1', 6);
    expect(state.shoppingLineFor('r1')!.servings, 6);
    expect(state.shoppingLines, hasLength(2));

    state.toggleShoppingChecked('r1');
    expect(state.checkedShopping, {'r1'});
    state.clearCheckedShopping();
    expect(state.shoppingLines, hasLength(1));
    expect(state.shoppingLineFor('r1'), isNull);
  });

  test('content requests are deduped', () async {
    final state = await buildState();
    state.addContentRequest('a');
    state.addContentRequest('a');
    state.addContentRequest('b');
    expect(state.contentRequests, ['a', 'b']);
    state.removeContentRequest('a');
    expect(state.contentRequests, ['b']);
  });

  test('uniqueIngredients expands via resolver', () async {
    final state = await buildState();
    state.addShoppingLine('r1');
    final ids = state.uniqueIngredients((id) => id == 'r1' ? _recipe('r1') : null);
    expect(ids, {'garlic', 'salt', 'lemon'});
  });

  test('import merge unions without duplicating existing entries', () async {
    final state = await buildState();
    state.toggleSaved('existing');
    final payload = BackupPayload(
      profile: UserProfile(name: 'imported'),
      saved: [
        SavedEntry(recipeId: 'new', savedAt: DateTime(2026, 2, 1)),
        SavedEntry(recipeId: 'existing', savedAt: DateTime(2026, 3, 1)),
      ],
      history: [
        HistoryEntry(recipeId: 'new', at: DateTime(2026, 1, 1)),
      ],
      mealPlan: {
        '2026-W32': {'mon.dinner': 'new'},
      },
      contentRequests: const ['added'],
    );
    await state.importPayload(payload);
    expect(
        state.savedEntries.map((e) => e.recipeId).toSet(), {'existing', 'new'});
    expect(state.history.map((e) => e.recipeId), ['new']);
    expect(state.week('2026-W32')[slotKey('mon', 'dinner')], 'new');
    expect(state.contentRequests, ['added']);
  });

  test('import replace wipes previous state', () async {
    final state = await buildState();
    state.toggleSaved('old');
    final payload = BackupPayload(
      profile: UserProfile(name: 'replaced'),
      saved: [
        SavedEntry(recipeId: 'fresh', savedAt: DateTime(2026, 1, 1)),
      ],
      history: const [],
      mealPlan: const {},
      contentRequests: const [],
    );
    await state.importPayload(payload, merge: false);
    expect(state.savedEntries.map((e) => e.recipeId), ['fresh']);
    expect(state.profile.name, 'replaced');
  });
}

Recipe _recipe(String id) => Recipe(
      id: id,
      dishId: 'd',
      title: {'en': id},
      summary: {'en': id},
      diet: 'classic',
      contains: const {},
      attributes: const [],
      timeMinutes: 10,
      calories: 100,
      protein: 0,
      carbs: 0,
      fat: 0,
      servings: 2,
      mealTypes: const ['dinner'],
      tags: const [],
      ingredients: [
        IngredientRef(id: 'garlic', amount: 1, unit: 'clove'),
        IngredientRef(id: 'salt', amount: 1, unit: 'tsp'),
        IngredientRef(id: 'lemon', amount: 1, unit: 'piece'),
      ],
      steps: const [],
    );