import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:morphcook/data/stores.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/shopping.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var counter = 0;

  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('morphcook_test');
    Hive.init(dir.path);
  });

  setUp(() {
    counter++;
    SharedPreferences.setMockInitialValues({});
  });

  String prefix() => 't$counter-';

  Future<AppStore> makeStore() => AppStore.init(boxPrefix: prefix());

  test('profile persists through shared_preferences', () async {
    final store = await makeStore();
    store.updateProfile(const Profile(name: 'Ada', onboarded: true));
    final reloaded = await makeStore();
    expect(reloaded.profile.name, 'Ada');
    expect(reloaded.profile.onboarded, isTrue);
  });

  test('save/unsave recipes with timestamps', () async {
    final store = await makeStore();
    expect(store.isSaved('doener.vegan'), isFalse);
    store.saveRecipe('doener.vegan');
    expect(store.isSaved('doener.vegan'), isTrue);
    expect(store.savedAt['doener.vegan'], isNotNull);
    store.unsaveRecipe('doener.vegan');
    expect(store.isSaved('doener.vegan'), isFalse);
  });

  test('history records cooks, newest first, with lastCookedAt map', () async {
    final store = await makeStore();
    store.recordCooked('a', at: DateTime(2026, 1, 1));
    store.recordCooked('b', at: DateTime(2026, 1, 5));
    store.recordCooked('a', at: DateTime(2026, 2, 1));
    final history = store.history;
    expect(history.first.recipeId, 'a');
    expect(history.first.cookedAt, DateTime(2026, 2, 1));
    expect(store.lastCookedAt['a'], DateTime(2026, 2, 1));
    expect(store.lastCookedAt['b'], DateTime(2026, 1, 5));
  });

  test('meal plan slots assign, clear and persist', () async {
    final store = await makeStore();
    store.assignSlot('2026-W33', 'mon.dinner', 'doener.vegan');
    expect(store.plannedRecipe('2026-W33', 'mon.dinner'), 'doener.vegan');
    store.clearSlot('2026-W33', 'mon.dinner');
    expect(store.plannedRecipe('2026-W33', 'mon.dinner'), isNull);
    store.assignSlot('2026-W33', 'sun.lunch', 'hummus.classic');
    final reloaded = await makeStore();
    expect(reloaded.plannedRecipe('2026-W33', 'sun.lunch'), 'hummus.classic');
  });

  test('shopping entries persist, toggle and clear checked', () async {
    final store = await makeStore();
    store.addShoppingEntries([
      ShoppingEntry(
        ingredientId: 'produce.garlic',
        amount: 2,
        unit: 'clove',
        addedAt: DateTime(2026, 1, 1),
      ),
      ShoppingEntry(
        ingredientId: 'produce.onion',
        amount: 1,
        unit: 'piece',
        addedAt: DateTime(2026, 1, 1),
      ),
    ]);
    expect(store.shoppingEntries.length, 2);
    store.toggleChecked('produce.garlic', true);
    expect(
      store.shoppingEntries.firstWhere((e) => e.ingredientId == 'produce.garlic').checked,
      isTrue,
    );
    store.clearChecked();
    expect(store.shoppingEntries.length, 1);
    await store.clearAllShopping();
    expect(store.shoppingEntries, isEmpty);
  });

  test('content requests are stored locally and deduped', () async {
    final store = await makeStore();
    store.addContentRequest('pad thai');
    store.addContentRequest('pad thai');
    store.addContentRequest('  sushi  ');
    expect(store.contentRequests, ['pad thai', 'sushi']);
  });

  test('applyBackupReplace overwrites everything', () async {
    final store = await makeStore();
    store.saveRecipe('old.recipe');
    store.assignSlot('2026-W33', 'mon.dinner', 'old.recipe');

    await store.applyBackupReplace({
      'schema_version': 1,
      'profile': const Profile(name: 'Grace', onboarded: true).toJson(),
      'saved': ['new.recipe'],
      'meal_plan': {
        '2026-W34': {'tue.lunch': 'new.recipe'},
      },
      'history': [
        {'recipe_id': 'new.recipe', 'cooked_at': '2026-08-01T12:00:00.000Z'},
      ],
      'content_requests': ['soup dumplings'],
    });

    expect(store.profile.name, 'Grace');
    expect(store.savedIds, ['new.recipe']);
    expect(store.plannedRecipe('2026-W33', 'mon.dinner'), isNull);
    expect(store.plannedRecipe('2026-W34', 'tue.lunch'), 'new.recipe');
    expect(store.contentRequests, ['soup dumplings']);
  });

  test('applyBackupMerge unions saved and fills empty slots', () async {
    final store = await makeStore();
    store.saveRecipe('a');
    store.assignSlot('2026-W33', 'mon.dinner', 'a');

    await store.applyBackupMerge({
      'schema_version': 1,
      'profile': const Profile().toJson(),
      'saved': ['b'],
      'meal_plan': {
        '2026-W33': {'mon.dinner': 'b', 'tue.lunch': 'c'},
      },
      'history': const [],
      'content_requests': const [],
    });

    expect(store.savedIds.toSet(), {'a', 'b'});
    // newest-wins semantics: incoming b replaces a in the slot
    expect(store.plannedRecipe('2026-W33', 'mon.dinner'), 'b');
    expect(store.plannedRecipe('2026-W33', 'tue.lunch'), 'c');
  });

  test('cook progress persists and clears', () async {
    final store = await makeStore();
    store.saveCookProgress('doener.vegan', {'step': 3, 'servings': 4});
    final saved = store.readCookProgress('doener.vegan')!;
    expect(saved['step'], 3);
    expect(saved['servings'], 4);
    store.clearCookProgress('doener.vegan');
    expect(store.readCookProgress('doener.vegan'), isNull);
  });
}
