import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/app/home_shell.dart';
import 'package:morphcook/data/models/history_entry.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/features/cookbook/cookbook_screen.dart';
import 'package:morphcook/features/dish/dish_screen.dart';
import 'package:morphcook/state/app_services.dart';
import 'package:morphcook/widgets/recipe_row.dart';

import '../support/test_app.dart';

void main() {
  final now = DateTime(2026, 9, 30, 12); // a Wednesday

  Future<AppServices> open(
    WidgetTester tester, {
    Profile profile = const Profile(name: 'Sam'),
    List<String> saved = const [],
    List<(String, int)> cooked = const [],
    int tab = 2,
  }) async {
    usePhone(tester);
    await loadBundledFonts(tester);
    final services = await buildServices(tester, profile: profile, now: now);
    for (var i = 0; i < saved.length; i++) {
      await services.cookbook.save(saved[i], at: now.subtract(Duration(minutes: i)));
    }
    for (final (id, daysAgo) in cooked) {
      await services.history.add(
        HistoryEntry(
          recipeId: id,
          cookedAt: now.subtract(Duration(days: daysAgo)),
          servings: 2,
        ),
      );
    }
    await pumpApp(tester, services, home: HomeShell(initialTab: tab));
    await settleAsync(tester, rounds: 12);
    return services;
  }

  group('saved recipes', () {
    testWidgets('an empty cookbook says what to do', (tester) async {
      await open(tester);
      expect(find.text('cookbook'), findsWidgets);
      expect(find.text('nothing saved yet.'), findsOneWidget);
      expect(find.text('FIND SOMETHING TO COOK'), findsOneWidget);
    });

    testWidgets('the empty state leads back to the today tab', (tester) async {
      await open(tester);
      await tester.tap(find.text('FIND SOMETHING TO COOK'));
      await settle(tester);
      expect(find.text('a cookbook for every body.'), findsOneWidget);
    });

    testWidgets('lists the saved variants, newest first, with the date they were saved', (tester) async {
      await open(tester, saved: ['doener-vegan', 'pancakes-vegan', 'chili-vegan']);
      final titles = ['Vegan Döner', 'Vegan Banana Pancakes', 'Chili sin Carne'];
      final positions = [for (final t in titles) tester.getTopLeft(find.text(t)).dy];
      expect(positions, [...positions]..sort());
      expect(find.text('saved wed 30 sep'), findsWidgets);
    });

    testWidgets('you save a specific variant: tapping it opens exactly that recipe', (tester) async {
      await open(tester, saved: ['doener-keto']);
      await tester.tap(find.text('Keto Döner Bowl'));
      await settle(tester, frames: 15);
      await pumpUntilFound(tester, find.byType(DishScreen));
      await pumpUntilFound(tester, find.text('keto döner bowl'));
    });

    testWidgets('the bookmark removes it, with an undo that restores it', (tester) async {
      final services = await open(tester, saved: ['doener-vegan', 'pancakes-vegan']);
      await tester.tap(find.byTooltip('remove from cookbook').first);
      await settleAsync(tester, rounds: 6);
      expect(services.cookbook.isSaved('doener-vegan'), isFalse);
      expect(find.text('Vegan Döner'), findsNothing);
      expect(find.text('removed from your cookbook'), findsOneWidget);
      await tester.tap(find.text('undo'));
      await settleAsync(tester, rounds: 6);
      expect(services.cookbook.isSaved('doener-vegan'), isTrue);
      expect(services.cookbook.saved.first.recipeId, 'doener-vegan', reason: 'back at its original date');
      expect(find.text('Vegan Döner'), findsOneWidget);
    });

    testWidgets('a saved recipe that no longer fits an allergy stays, flagged with what clashes', (tester) async {
      await open(
        tester,
        profile: const Profile(avoidFlags: {'dairy'}, avoidIngredients: {'tahini'}),
        saved: ['doener-classic', 'doener-vegan'],
      );
      final warnings = tester.widgetList<Text>(find.textContaining('contains ')).map((t) => t.data!).toList();
      expect(warnings.any((t) => t.contains('yogurt')), isTrue, reason: 'the classic one has yogurt, which is dairy');
      expect(warnings.any((t) => t.contains('tahini')), isTrue, reason: 'the vegan one has tahini');
      expect(find.text('Classic Döner Kebab'), findsOneWidget, reason: 'saved recipes are never dropped silently');
    });

    testWidgets('the warning names the ingredients that clash, not abstract classes', (tester) async {
      await open(
        tester,
        profile: const Profile(avoidFlags: {'vegan'}),
        saved: ['doener-classic'],
      );
      final warning = tester.widgetList<Text>(find.textContaining('contains ')).map((t) => t.data!).first;
      expect(warning, contains('lamb shoulder'));
      expect(warning, isNot(contains('meat,')));
    });

    testWidgets('German copy', (tester) async {
      await open(
        tester,
        profile: const Profile(lang: 'de'),
        saved: ['doener-vegan'],
      );
      expect(find.text('kochbuch'), findsWidgets);
      expect(find.text('Veganer Döner'), findsOneWidget);
      expect(find.textContaining('gespeichert'), findsOneWidget);
    });
  });

  group('pagination: only what is on screen exists', () {
    Future<List<String>> manyRecipes(WidgetTester tester, int count) async {
      final services = await buildServices(tester);
      final ids = [for (final d in services.corpus.dishes.values) ...d.recipeIds];
      expect(ids.length, greaterThanOrEqualTo(count));
      return ids.take(count).toList();
    }

    testWidgets('a long cookbook builds only a screenful of rows and loads more while scrolling', (tester) async {
      final ids = await manyRecipes(tester, 90);
      final services = await open(tester, saved: ids);
      final scrollable = find.descendant(of: find.byType(CookbookScreen), matching: find.byType(Scrollable)).first;
      // Only rows near the top exist: ListView.builder with an unknown item count.
      expect(find.byType(RecipeRow).evaluate().length, lessThan(14));
      final first = tester.widgetList<RecipeRow>(find.byType(RecipeRow)).first.title;
      expect(services.cookbook.count, 90);

      // Scroll down through several pages.
      for (var i = 0; i < 40; i++) {
        await tester.drag(scrollable, const Offset(0, -700));
        await settleAsync(tester, rounds: 3);
      }
      expect(find.byType(RecipeRow).evaluate().length, lessThan(14));
      final scrolled = tester.widgetList<RecipeRow>(find.byType(RecipeRow)).first.title;
      expect(scrolled, isNot(first), reason: 'we are deep in the list, the first rows were disposed');
    });

    testWidgets('reaching the end of a page fetches the next one, 30 at a time', (tester) async {
      final ids = await manyRecipes(tester, 70);
      await open(tester, saved: ids);
      final scrollable = find.descendant(of: find.byType(CookbookScreen), matching: find.byType(Scrollable)).first;
      // Row 35 exists only after the second page has been loaded.
      final seen = <String>{};
      for (var i = 0; i < 30; i++) {
        for (final row in tester.widgetList<RecipeRow>(find.byType(RecipeRow))) {
          seen.add(row.title);
        }
        await tester.drag(scrollable, const Offset(0, -600));
        await settleAsync(tester, rounds: 3);
      }
      expect(seen.length, greaterThan(40), reason: 'later pages were fetched on demand');
    });
  });

  group('cooking history', () {
    testWidgets('empty history', (tester) async {
      await open(tester);
      await tester.tap(find.text('COOKED'));
      await settle(tester);
      expect(find.text('nothing cooked yet.'), findsOneWidget);
    });

    testWidgets('grouped by week with handwritten headings', (tester) async {
      await open(
        tester,
        cooked: [('chili-vegan', 1), ('pancakes-vegan', 2), ('doener-vegan', 9), ('shakshuka-vegan', 30)],
      );
      await tester.tap(find.text('COOKED'));
      await settleAsync(tester, rounds: 8);
      expect(find.text('this week'), findsOneWidget);
      expect(find.text('last week'), findsOneWidget);
      expect(find.textContaining('week of'), findsOneWidget);
      expect(find.text('Chili sin Carne'), findsOneWidget);
      expect(find.text('COOKED TUE 29 SEP · FOR 2'), findsOneWidget);
    });

    testWidgets('"cook again" opens the exact recipe', (tester) async {
      await open(tester, cooked: [('doener-keto', 1)]);
      await tester.tap(find.text('COOKED'));
      await settleAsync(tester, rounds: 8);
      await tester.tap(find.byTooltip('cook again'));
      await settle(tester, frames: 15);
      await pumpUntilFound(tester, find.text('keto döner bowl'));
    });

    testWidgets('history pages by weeks and loads older weeks when you reach them', (tester) async {
      final cooked = [('chili-vegan', 1)];
      final entries = <(String, int)>[for (var w = 0; w < 30; w++) ('chili-vegan', 1 + w * 7)];
      await open(tester, cooked: [...cooked, ...entries.skip(1)]);
      await tester.tap(find.text('COOKED'));
      await settleAsync(tester, rounds: 8);
      final scrollable = find.descendant(of: find.byType(CookbookScreen), matching: find.byType(Scrollable)).first;
      expect(find.byType(RecipeRow).evaluate().length, lessThan(12));
      for (var i = 0; i < 30; i++) {
        await tester.drag(scrollable, const Offset(0, -600));
        await settleAsync(tester, rounds: 3);
      }
      expect(find.textContaining('week of'), findsWidgets);
    });
  });
}
