import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/app/home_shell.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/domain/plan/meal_plan.dart';
import 'package:morphcook/features/dish/dish_screen.dart';
import 'package:morphcook/features/plan/recipe_picker.dart';
import 'package:morphcook/features/plan/week_grid.dart';
import 'package:morphcook/state/app_services.dart';
import 'package:morphcook/widgets/paper_controls.dart';

import '../support/test_app.dart';

void main() {
  // Monday 28 September 2026 is in ISO week 2026-W40.
  final now = DateTime(2026, 9, 28, 18);
  final week = WeekKey.fromDate(now);

  Future<AppServices> open(
    WidgetTester tester, {
    Map<String, String> planned = const {},
    List<String> saved = const [],
    Profile profile = const Profile(name: 'Sam'),
  }) async {
    usePhone(tester, size: const Size(390, 1100));
    await loadBundledFonts(tester);
    final services = await buildServices(tester, profile: profile, now: now);
    for (final entry in planned.entries) {
      await services.mealPlan.assign(week, entry.key, entry.value);
    }
    for (final id in saved) {
      await services.cookbook.save(id, at: now);
    }
    await pumpApp(tester, services, home: const HomeShell(initialTab: 3));
    await pumpUntilFound(tester, find.byType(WeekGrid));
    await settleAsync(tester, rounds: 8);
    return services;
  }

  group('the weekly grid', () {
    testWidgets('shows this week with its dates and a row per day', (tester) async {
      await open(tester);
      expect(find.text('plan'), findsWidgets);
      expect(find.text('this week'), findsOneWidget);
      expect(find.text('MON 28 SEP – SUN 4 OCT'), findsOneWidget);
      for (final meal in ['BREAKFAST', 'LUNCH', 'DINNER']) {
        expect(find.text(meal), findsOneWidget);
      }
      for (final day in ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN']) {
        expect(find.text(day), findsOneWidget, reason: day);
      }
      expect(find.byIcon(Icons.add), findsNWidgets(21), reason: 'seven days times three meals, all empty');
    });

    testWidgets('today is marked', (tester) async {
      await open(tester);
      expect(find.text('28'), findsOneWidget);
    });

    testWidgets('filled slots show the recipe', (tester) async {
      await open(tester, planned: {'mon.dinner': 'chili-vegan', 'tue.breakfast': 'pancakes-vegan'});
      expect(find.textContaining('Chili sin Ca'), findsOneWidget);
      expect(find.textContaining('Vegan Banana'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsNWidgets(19));
    });

    testWidgets('weekly pages: one week at a time, forward and back', (tester) async {
      await open(tester, planned: {'mon.dinner': 'chili-vegan'});
      await tester.tap(find.byTooltip('next week'));
      await settle(tester, frames: 15);
      expect(find.text('week 41'), findsOneWidget);
      expect(find.text('MON 5 OCT – SUN 11 OCT'), findsOneWidget);
      expect(find.textContaining('Chili sin Ca'), findsNothing, reason: 'that dinner is in the previous week');
      await tester.tap(find.byTooltip('previous week'));
      await settle(tester, frames: 15);
      expect(find.text('this week'), findsOneWidget);
      expect(find.textContaining('Chili sin Ca'), findsOneWidget);
    });

    testWidgets('swiping between weeks works too', (tester) async {
      await open(tester);
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await settle(tester, frames: 15);
      expect(find.text('week 41'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(300, 0));
      await settle(tester, frames: 15);
      expect(find.text('this week'), findsOneWidget);
    });

    testWidgets('no more than a few weeks stay built, however far you go', (tester) async {
      await open(tester);
      for (var i = 0; i < 8; i++) {
        await tester.tap(find.byTooltip('next week'));
        await settle(tester, frames: 12);
      }
      expect(find.byType(WeekGrid).evaluate().length, lessThanOrEqualTo(4));
      expect(find.text('week 48'), findsOneWidget);
    });
  });

  group('choosing a recipe for a slot', () {
    testWidgets('tapping an empty slot offers the cookbook and search', (tester) async {
      final services = await open(tester, saved: ['doener-vegan', 'pancakes-vegan']);
      await tester.tap(find.byIcon(Icons.add).at(2)); // monday dinner
      await settle(tester, frames: 15);
      await pumpUntilFound(tester, find.byType(RecipePickerScreen));
      expect(find.text('choose a recipe'), findsOneWidget);
      expect(find.text('MONDAY DINNER'), findsOneWidget);
      expect(find.text('SAVED'), findsOneWidget);
      await pumpUntilFound(tester, find.textContaining('Vegan Döner'));
      await tester.tap(find.textContaining('Vegan Döner'));
      await settle(tester, frames: 15);
      expect(services.mealPlan.recipeAt(week, 'mon.dinner'), 'doener-vegan');
      expect(find.byType(RecipePickerScreen), findsNothing);
    });

    testWidgets('a recipe can also come straight from search', (tester) async {
      final services = await open(tester);
      await tester.tap(find.byIcon(Icons.add).first);
      await settle(tester, frames: 15);
      await pumpUntilFound(tester, find.byType(RecipePickerScreen));
      await tester.tap(find.text('SEARCH'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'carbonara');
      await tester.pump(const Duration(milliseconds: 400));
      await settleAsync(tester, rounds: 20);
      await tester.tap(find.textContaining('Carbonara').first);
      await settle(tester, frames: 15);
      expect(services.mealPlan.recipeAt(week, 'mon.breakfast')?.startsWith('carbonara-'), isTrue);
    });

    testWidgets('closing the picker changes nothing', (tester) async {
      final services = await open(tester);
      await tester.tap(find.byIcon(Icons.add).first);
      await settle(tester, frames: 15);
      await tester.tap(find.byTooltip('close'));
      await settle(tester, frames: 15);
      expect(services.mealPlan.plan.isEmpty, isTrue);
    });
  });

  group('actions on a filled slot', () {
    testWidgets('open, choose another, remove', (tester) async {
      final services = await open(tester, planned: {'mon.dinner': 'chili-vegan'});
      await tester.tap(find.textContaining('Chili sin Ca'));
      await settle(tester);
      expect(find.text('open recipe'), findsOneWidget);
      expect(find.text('choose another'), findsOneWidget);
      expect(find.text('remove from plan'), findsOneWidget);
      await tester.tap(find.text('remove from plan'));
      await settle(tester);
      expect(services.mealPlan.recipeAt(week, 'mon.dinner'), isNull);
    });

    testWidgets('open shows that exact variant, not just the dish', (tester) async {
      await open(tester, planned: {'mon.dinner': 'doener-keto'});
      await tester.tap(find.textContaining('Keto Döner'));
      await settle(tester);
      await tester.tap(find.text('open recipe'));
      await settle(tester, frames: 15);
      await pumpUntilFound(tester, find.byType(DishScreen));
      await pumpUntilFound(tester, find.text('keto döner bowl'));
    });

    testWidgets('choose another replaces the recipe', (tester) async {
      final services = await open(tester, planned: {'mon.dinner': 'chili-vegan'}, saved: ['pancakes-vegan']);
      await tester.tap(find.textContaining('Chili sin Ca'));
      await settle(tester);
      await tester.tap(find.text('choose another'));
      await settle(tester, frames: 15);
      await pumpUntilFound(tester, find.textContaining('Vegan Banana'));
      await tester.tap(find.textContaining('Vegan Banana'));
      await settle(tester, frames: 15);
      expect(services.mealPlan.recipeAt(week, 'mon.dinner'), 'pancakes-vegan');
    });
  });

  group('drag and drop', () {
    Future<void> dragTo(WidgetTester tester, Finder from, Finder to) async {
      final gesture = await tester.startGesture(tester.getCenter(from));
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.moveTo(tester.getCenter(to));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(tester.getCenter(to) + const Offset(2, 2));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await settleAsync(tester, rounds: 6);
    }

    testWidgets('a long press and drag moves a meal to a free slot', (tester) async {
      final services = await open(tester, planned: {'mon.dinner': 'chili-vegan'});
      await dragTo(tester, find.textContaining('Chili sin Ca'), find.byIcon(Icons.add).at(10));
      expect(services.mealPlan.recipeAt(week, 'mon.dinner'), isNull);
      final moved = services.mealPlan.plan.slotsOf(week).entries.single;
      expect(moved.value, 'chili-vegan');
      expect(moved.key, isNot('mon.dinner'));
    });

    testWidgets('dropping onto a filled slot swaps the two meals', (tester) async {
      final services = await open(tester, planned: {'mon.dinner': 'chili-vegan', 'tue.dinner': 'pancakes-vegan'});
      await dragTo(tester, find.textContaining('Chili sin Ca'), find.textContaining('Vegan Banana'));
      expect(services.mealPlan.recipeAt(week, 'mon.dinner'), 'pancakes-vegan');
      expect(services.mealPlan.recipeAt(week, 'tue.dinner'), 'chili-vegan');
    });

    testWidgets('a plain tap does not start a drag', (tester) async {
      final services = await open(tester, planned: {'mon.dinner': 'chili-vegan'});
      await tester.tap(find.textContaining('Chili sin Ca'));
      await settle(tester);
      expect(find.text('open recipe'), findsOneWidget);
      expect(services.mealPlan.recipeAt(week, 'mon.dinner'), 'chili-vegan');
    });
  });

  group('one-tap export to the shopping list', () {
    testWidgets('sends every planned meal of the week to the list, keeping repeats', (tester) async {
      final services = await open(
        tester,
        planned: {'mon.dinner': 'chili-vegan', 'tue.dinner': 'chili-vegan', 'wed.lunch': 'pancakes-vegan'},
      );
      await tester.tap(find.text('TO SHOPPING LIST'));
      await settleAsync(tester, rounds: 10);
      final sources = {for (final s in services.shopping.sources) s.recipeId: s.servings};
      expect(sources.keys, unorderedEquals(['chili-vegan', 'pancakes-vegan']));
      expect(sources['chili-vegan'], 8, reason: 'cooked twice for four people');
      expect(find.text('added 3 meals to your list'), findsOneWidget);
      expect(find.text('view list'), findsOneWidget);
    });

    testWidgets('the button waits for something to export', (tester) async {
      await open(tester);
      final button = tester.widget<PaperButton>(
        find.ancestor(of: find.text('TO SHOPPING LIST'), matching: find.byType(PaperButton)),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('"view list" opens the shopping tab', (tester) async {
      await open(tester, planned: {'mon.dinner': 'chili-vegan'});
      await tester.tap(find.text('TO SHOPPING LIST'));
      await settleAsync(tester, rounds: 10);
      await tester.tap(find.text('view list'));
      await settle(tester, frames: 15);
      expect(find.text('your list is empty.'), findsNothing);
      expect(find.text('on the list'), findsOneWidget);
    });
  });
}
