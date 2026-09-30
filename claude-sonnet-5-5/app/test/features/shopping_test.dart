import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/app/home_shell.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/features/insights/insights_screen.dart';
import 'package:morphcook/features/shopping/shopping_screen.dart';
import 'package:morphcook/state/app_services.dart';

import '../support/test_app.dart';

void main() {
  final now = DateTime(2026, 9, 28, 18);

  Future<AppServices> open(
    WidgetTester tester, {
    Profile profile = const Profile(name: 'Sam'),
    List<(String, double?)> recipes = const [],
  }) async {
    usePhone(tester);
    await loadBundledFonts(tester);
    final services = await buildServices(tester, profile: profile, now: now);
    for (final (id, servings) in recipes) {
      final recipe = await tester.runAsync(() => services.corpus.loadRecipe(id));
      await services.shopping.addRecipe(recipe!, servings: servings, at: now);
    }
    await pumpApp(tester, services, home: const HomeShell(initialTab: 4));
    await settleAsync(tester, rounds: 8);
    return services;
  }

  group('empty list', () {
    testWidgets('invites to add something', (tester) async {
      await open(tester);
      expect(find.text('list'), findsWidgets);
      expect(find.text('your list is empty.'), findsOneWidget);
      expect(find.text('ADD AN ITEM'), findsOneWidget);
    });
  });

  group('smart aggregation', () {
    testWidgets('unit-aware: the garlic of two recipes becomes one line', (tester) async {
      await open(tester, recipes: [('chili-vegan', null), ('doener-vegan', null)]);
      // chili 3 cloves for 4 people + doener 3 + 1 cloves for 2 people = 7 cloves
      expect(find.text('garlic'), findsOneWidget, reason: 'deduplicated');
      expect(find.text('7 cloves'), findsOneWidget);
      expect(find.text('for Chili sin Carne, Vegan Döner'), findsOneWidget);
    });

    testWidgets('grouped by aisle in shopping-route order', (tester) async {
      await open(tester, recipes: [('chili-vegan', null)]);
      final produce = tester.getTopLeft(find.text('produce'));
      final pantry = tester.getTopLeft(find.text('pantry'));
      expect(produce.dy, lessThan(pantry.dy));
      expect(
        find.text('0/${find.byType(Dismissible).evaluate().length}'),
        findsNothing,
        reason: 'counters are per aisle',
      );
    });

    testWidgets('changing the number of people rescales the amounts', (tester) async {
      await open(tester, recipes: [('pancakes-classic', 2)]);
      expect(find.text('150 g'), findsOneWidget);
      await tester.tap(find.byTooltip('more servings'));
      await settleAsync(tester, rounds: 6);
      expect(find.text('225 g'), findsOneWidget);
      expect(find.text('3 people'), findsOneWidget);
    });

    testWidgets('the recipes on the list can be taken off again', (tester) async {
      final services = await open(tester, recipes: [('pancakes-classic', 2), ('chili-vegan', 4)]);
      expect(find.text('Fluffy Buttermilk Pancakes'), findsOneWidget);
      await tester.tap(find.byTooltip('remove').first);
      await settleAsync(tester, rounds: 6);
      expect(services.shopping.sources.map((s) => s.recipeId), ['chili-vegan']);
      expect(find.text('wheat flour'), findsNothing);
    });

    testWidgets('amounts without a quantity read "to taste"', (tester) async {
      await open(tester, recipes: [('chili-vegan', null)]);
      await tester.scrollUntilVisible(
        find.text('salt'),
        300,
        scrollable: find.descendant(of: find.byType(ShoppingScreen), matching: find.byType(Scrollable)).first,
      );
      expect(find.text('to taste'), findsWidgets);
    });

    testWidgets('German: German names and units', (tester) async {
      await open(
        tester,
        profile: const Profile(lang: 'de'),
        recipes: [('chili-vegan', null), ('doener-vegan', null)],
      );
      expect(find.text('knoblauch'), findsOneWidget);
      expect(find.text('7 Zehen'), findsOneWidget);
    });
  });

  group('checking off', () {
    testWidgets('tapping a line ticks it, counts it and moves it to the end of its aisle', (tester) async {
      final services = await open(tester, recipes: [('chili-vegan', null)]);
      final firstProduce = tester.getTopLeft(find.text('cilantro')).dy;
      await tester.tap(find.text('cilantro'));
      await settleAsync(tester, rounds: 4);
      expect(services.shopping.isChecked('cilantro'), isTrue);
      expect(
        tester.getTopLeft(find.text('cilantro')).dy,
        greaterThan(firstProduce),
        reason: 'ticked lines sink to the bottom of their aisle',
      );
      await tester.tap(find.text('cilantro'));
      await settleAsync(tester, rounds: 4);
      expect(services.shopping.isChecked('cilantro'), isFalse);
    });

    testWidgets('"clear ticked" removes the ticked lines', (tester) async {
      final services = await open(tester, recipes: [('chili-vegan', null)]);
      expect(find.text('CLEAR TICKED'), findsNothing);
      await tester.tap(find.text('cilantro'));
      await settleAsync(tester, rounds: 4);
      await tester.scrollUntilVisible(
        find.text('CLEAR TICKED'),
        300,
        scrollable: find.descendant(of: find.byType(ShoppingScreen), matching: find.byType(Scrollable)).first,
      );
      await tester.tap(find.text('CLEAR TICKED'));
      await settleAsync(tester, rounds: 6);
      expect(find.text('cilantro'), findsNothing);
      expect(services.shopping.checked, isEmpty);
    });

    testWidgets('swiping a line away hides it', (tester) async {
      final services = await open(tester, recipes: [('chili-vegan', null)]);
      await tester.drag(find.text('cilantro'), const Offset(-400, 0));
      await settleAsync(tester, rounds: 6);
      expect(find.text('cilantro'), findsNothing);
      expect(services.shopping.dismissed, contains('cilantro'));
    });
  });

  group('adding items by hand', () {
    testWidgets('a dictionary ingredient merges into the aisle it belongs to', (tester) async {
      final services = await open(tester);
      await tester.tap(find.text('ADD AN ITEM'));
      await settle(tester, frames: 15);
      expect(find.text('add an item'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'oat mil');
      await tester.pump();
      await tester.tap(find.text('oat milk').last);
      await tester.pump();
      await tester.enterText(find.byType(TextField).last, '2');
      await tester.tap(find.text('l'));
      await tester.pump();
      await tester.tap(find.text('ADD'));
      await settleAsync(tester, rounds: 8);
      expect(services.shopping.manualItems.single.ingredientId, 'oat-milk');
      expect(find.text('oat milk'), findsOneWidget);
      expect(find.text('2 l'), findsOneWidget);
      expect(find.text('dairy & eggs'), findsOneWidget);
    });

    testWidgets('free text goes to "other"', (tester) async {
      final services = await open(tester);
      await tester.tap(find.text('ADD AN ITEM'));
      await settle(tester, frames: 15);
      await tester.enterText(find.byType(TextField).first, 'birthday candles');
      await tester.pump();
      await tester.tap(find.text('ADD'));
      await settleAsync(tester, rounds: 8);
      expect(services.shopping.manualItems.single.label, 'birthday candles');
      expect(find.text('birthday candles'), findsOneWidget);
      expect(find.text('other'), findsOneWidget);
    });

    testWidgets('a hand-added ingredient adds up with recipe lines', (tester) async {
      await open(tester, recipes: [('chili-vegan', null)]);
      await tester.scrollUntilVisible(
        find.text('ADD ITEM'),
        300,
        scrollable: find.descendant(of: find.byType(ShoppingScreen), matching: find.byType(Scrollable)).first,
      );
      await tester.tap(find.text('ADD ITEM'));
      await settle(tester, frames: 15);
      await tester.enterText(find.byType(TextField).first, 'garlic');
      await tester.pump();
      await tester.tap(find.text('garlic').last);
      await tester.pump();
      await tester.enterText(find.byType(TextField).last, '2');
      await tester.pump();
      await tester.tap(find.text('ADD'));
      await settleAsync(tester, rounds: 8);
      await tester.scrollUntilVisible(
        find.text('garlic'),
        -300,
        scrollable: find.descendant(of: find.byType(ShoppingScreen), matching: find.byType(Scrollable)).first,
      );
      expect(find.text('garlic'), findsOneWidget);
    });

    testWidgets('an empty name is not added', (tester) async {
      final services = await open(tester);
      await tester.tap(find.text('ADD AN ITEM'));
      await settle(tester, frames: 15);
      await tester.tap(find.text('ADD'));
      await settle(tester);
      expect(services.shopping.manualItems, isEmpty);
    });
  });

  group('starting over and insights', () {
    testWidgets('start over asks, then clears the list but keeps the insights history', (tester) async {
      final services = await open(tester, recipes: [('chili-vegan', null)]);
      final events = services.shopping.events.length;
      await tester.scrollUntilVisible(
        find.text('START OVER'),
        300,
        scrollable: find.descendant(of: find.byType(ShoppingScreen), matching: find.byType(Scrollable)).first,
      );
      await tester.tap(find.text('START OVER'));
      await settle(tester);
      expect(find.text('start a fresh list?'), findsOneWidget);
      await tester.tap(find.text('cancel'));
      await settle(tester);
      expect(services.shopping.isEmpty, isFalse);
      await tester.tap(find.text('START OVER'));
      await settle(tester);
      await tester.tap(find.text('start over').last);
      await settleAsync(tester, rounds: 8);
      expect(services.shopping.isEmpty, isTrue);
      expect(services.shopping.events.length, events);
      expect(find.text('your list is empty.'), findsOneWidget);
    });

    testWidgets('the insights dashboard is one tap away', (tester) async {
      await open(tester);
      await tester.tap(find.byTooltip('insights'));
      await settle(tester, frames: 15);
      expect(find.byType(InsightsScreen), findsOneWidget);
    });
  });
}
