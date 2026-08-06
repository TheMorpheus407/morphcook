import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:morphcook/domain/shopping.dart';
import 'package:morphcook/state/library_model.dart';

void main() {
  late Directory tempDir;
  late LibraryModel library;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('morphcook_hive_test');
    Hive.init(tempDir.path);
    library = LibraryModel();
    await library.init(directory: tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('saved', () {
    test('toggle saves and removes a specific variant', () async {
      await library.toggleSaved('doener-vegan');
      expect(library.isSaved('doener-vegan'), isTrue);
      expect(library.savedByDateDesc(), ['doener-vegan']);
      await library.toggleSaved('doener-vegan');
      expect(library.isSaved('doener-vegan'), isFalse);
    });

    test('savedByDateDesc orders newest first', () async {
      await library.toggleSaved('a');
      await Future.delayed(const Duration(milliseconds: 5));
      await library.toggleSaved('b');
      expect(library.savedByDateDesc(), ['b', 'a']);
    });
  });

  group('history', () {
    test('records and aggregates last cooked', () async {
      await library.recordCooked('r1', at: DateTime(2026, 1, 1));
      await library.recordCooked('r1', at: DateTime(2026, 3, 1));
      await library.recordCooked('r2', at: DateTime(2026, 2, 1));
      final last = library.lastCookedMap();
      expect(last['r1'], DateTime(2026, 3, 1));
      expect(last['r2'], DateTime(2026, 2, 1));
      expect(library.historyEntries().length, 3);
    });
  });

  group('meal plan', () {
    test('set, read, clear slots', () async {
      await library.setPlanSlot('2026-W16', 'mon', 'dinner', 'chili-classic');
      expect(library.planAt('2026-W16', 'mon', 'dinner'), 'chili-classic');
      expect(library.weekAssignments('2026-W16'),
          {'mon.dinner': 'chili-classic'});
      await library.clearPlanSlot('2026-W16', 'mon', 'dinner');
      expect(library.planAt('2026-W16', 'mon', 'dinner'), isNull);
    });

    test('backup map round-trips', () async {
      await library.setPlanSlot('2026-W16', 'mon', 'dinner', 'r1');
      await library.setPlanSlot('2026-W17', 'tue', 'lunch', 'r2');
      final backupMap = library.planAsBackupMap();
      await library.replacePlanFromBackup(backupMap);
      expect(library.planAt('2026-W16', 'mon', 'dinner'), 'r1');
      expect(library.planAt('2026-W17', 'tue', 'lunch'), 'r2');
    });
  });

  group('shopping', () {
    test('adding items merges same ingredient+unit', () async {
      await library.addItemsToShopping([
        ShoppingItem(ingredientId: 'garlic', qty: 2, unit: 'clove'),
      ]);
      await library.addItemsToShopping([
        ShoppingItem(ingredientId: 'garlic', qty: 3, unit: 'clove'),
      ]);
      final items = library.shoppingItems();
      expect(items, hasLength(1));
      expect(items.first.qty, 5);
      // events recorded for insights
      expect(library.shoppingEvents().length, 2);
    });

    test('checked state toggles and clears work', () async {
      await library.addItemsToShopping([
        ShoppingItem(ingredientId: 'garlic', qty: 2, unit: 'clove'),
      ]);
      await library.toggleShoppingChecked('garlic', 'clove');
      expect(library.shoppingItems().first.checked, isTrue);
      await library.clearShopping();
      expect(library.shoppingItems(), isEmpty);
    });
  });

  group('content requests', () {
    test('logs unique zero-result queries', () async {
      await library.logContentRequest('Pad Thai');
      await library.logContentRequest('pad thai');
      await library.logContentRequest('ok'); // too short
      expect(library.contentRequests(), ['pad thai']);
    });
  });

  group('cook progress', () {
    test('saves and clears per recipe', () async {
      await library.saveCookProgress('r1', 3);
      expect(library.cookProgress()['r1'], 3);
      await library.clearCookProgress('r1');
      expect(library.cookProgress().containsKey('r1'), isFalse);
    });
  });

  group('backup merge/replace', () {
    test('replace wipes and restores', () async {
      await library.toggleSaved('mine');
      await library.replaceAllFromBackup(
        saved: ['theirs'],
        mealPlan: {},
        history: [],
        contentRequests: ['x'],
      );
      expect(library.isSaved('mine'), isFalse);
      expect(library.isSaved('theirs'), isTrue);
      expect(library.contentRequests(), ['x']);
    });

    test('merge keeps existing data', () async {
      await library.toggleSaved('mine');
      await library.mergeFromBackup(
        saved: ['theirs'],
        mealPlan: {},
        history: [],
        contentRequests: ['x'],
      );
      expect(library.isSaved('mine'), isTrue);
      expect(library.isSaved('theirs'), isTrue);
    });
  });
}
