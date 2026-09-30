@Tags(<String>['visual'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/app/home_shell.dart';
import 'package:morphcook/data/models/history_entry.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/domain/plan/meal_plan.dart';
import 'package:morphcook/features/backup/backup_screen.dart';
import 'package:morphcook/features/cook/cook_screen.dart';
import 'package:morphcook/features/dish/dish_screen.dart';
import 'package:morphcook/features/faq/faq_screen.dart';
import 'package:morphcook/features/insights/insights_screen.dart';
import 'package:morphcook/features/settings/settings_screen.dart';
import 'package:morphcook/state/app_services.dart';

import '../support/screenshots.dart';
import '../support/test_app.dart';

const Profile _sam = Profile(
  name: 'Sam',
  lang: 'en',
  avoidFlags: {'vegan'},
  avoidIngredients: {'cilantro'},
  maxTimeMinutes: 60,
  preferredEffort: 'medium',
);

const Profile _anna = Profile(name: 'Anna', lang: 'de', preferredEffort: 'easy');

const Profile _open = Profile(name: 'Jo', lang: 'en');

/// Renders the real screens with the bundled fonts and writes PNGs to
/// build/screenshots instead of comparing goldens:
///
///   flutter test --tags visual test/visual
void main() {
  setUpAll(() {
    goldenFileComparator = ScreenshotComparator.standard();
  });

  final evening = DateTime(2026, 9, 28, 18, 30);

  Future<AppServices> setup(WidgetTester tester, {Profile profile = _sam, bool onboarded = true, DateTime? now}) async {
    usePhone(tester);
    await loadBundledFonts(tester);
    await loadMaterialIcons(tester);
    return buildServices(tester, profile: profile, onboarded: onboarded, now: now ?? evening);
  }

  /// Saved recipes, a little history, a filled week and a shopping list.
  Future<void> seed(WidgetTester tester, AppServices services) async {
    await tester.runAsync(() async {
      final now = evening;
      for (final id in [
        'doener-vegan',
        'pancakes-vegan',
        'chili-vegan',
        'bolognese-vegan',
        'shakshuka-vegan',
        'pad-thai-vegan',
      ]) {
        await services.cookbook.save(id, at: now.subtract(Duration(hours: id.length)));
      }
      await services.history.add(
        HistoryEntry(recipeId: 'chili-vegan', cookedAt: now.subtract(const Duration(days: 2)), servings: 2),
      );
      await services.history.add(
        HistoryEntry(recipeId: 'pancakes-vegan', cookedAt: now.subtract(const Duration(days: 9)), servings: 2),
      );
      await services.history.add(
        HistoryEntry(recipeId: 'doener-vegan', cookedAt: now.subtract(const Duration(days: 40)), servings: 4),
      );
      final week = WeekKey.fromDate(now);
      await services.mealPlan.assign(week, 'mon.dinner', 'chili-vegan');
      await services.mealPlan.assign(week, 'tue.breakfast', 'pancakes-vegan');
      await services.mealPlan.assign(week, 'wed.lunch', 'shakshuka-vegan');
      await services.mealPlan.assign(week, 'fri.dinner', 'doener-vegan');
      for (final id in ['chili-vegan', 'doener-vegan']) {
        final recipe = (await services.corpus.loadRecipe(id))!;
        await services.shopping.addRecipe(recipe, at: now);
      }
    });
  }

  testWidgets('onboarding', (tester) async {
    final services = await setup(tester, onboarded: false, profile: const Profile(lang: 'en'));
    await pumpApp(tester, services);
    await settle(tester);
    await shot(tester, 'onboarding-1-language');
    for (final step in ['2-name', '3-diet', '4-targets', '5-confirm']) {
      await tester.tap(find.text('NEXT'));
      await settle(tester);
      await shot(tester, 'onboarding-$step');
    }
  });

  testWidgets('home en evening + de morning', (tester) async {
    final services = await setup(tester);
    await seed(tester, services);
    await pumpApp(tester, services, home: const HomeShell());
    await settle(tester, frames: 20);
    await shot(tester, 'home');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await settle(tester);
    await shot(tester, 'home-scrolled');
  });

  testWidgets('home de', (tester) async {
    final services = await setup(tester, profile: _anna, now: DateTime(2026, 9, 26, 8, 15));
    await pumpApp(tester, services, home: const HomeShell());
    await settle(tester, frames: 20);
    await shot(tester, 'home-de-morning');
  });

  testWidgets('dish with an open profile', (tester) async {
    final services = await setup(tester, profile: _open);
    await pumpApp(tester, services, home: const DishScreen(dishId: 'doener'));
    await settle(tester, frames: 20);
    await shot(tester, 'dish-open-top');
    await tester.tap(find.textContaining('DIET').first);
    await settle(tester);
    await shot(tester, 'dish-open-diet-expanded');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -420));
    await settle(tester);
    await shot(tester, 'dish-open-ingredients');
  });

  testWidgets('dish disabled combinations', (tester) async {
    final services = await setup(tester, profile: _open);
    await pumpApp(tester, services, home: const DishScreen(dishId: 'doener'));
    await settleAsync(tester, rounds: 20);
    await tester.tap(find.textContaining('EFFORT').first);
    await settle(tester);
    await tester.tap(find.text('easy').first);
    await settle(tester);
    await tester.tap(find.textContaining('DIET').first);
    await settle(tester);
    await shot(tester, 'dish-open-disabled-combos');
  });

  testWidgets('dish vegan sam', (tester) async {
    final services = await setup(tester);
    await pumpApp(tester, services, home: const DishScreen(dishId: 'doener'));
    await settle(tester, frames: 20);
    await shot(tester, 'dish-sam-top');
    await tester.tap(find.text('METHOD').first);
    await settle(tester);
    await shot(tester, 'dish-sam-method');
    await tester.tap(find.text('MACROS').first);
    await settle(tester);
    await shot(tester, 'dish-sam-macros');
  });

  testWidgets('cook mode', (tester) async {
    var current = evening;
    usePhone(tester);
    await loadBundledFonts(tester);
    await loadMaterialIcons(tester);
    final services = await buildServices(tester, profile: _sam, clock: () => current);
    await pumpApp(tester, services, home: const CookScreen(recipeId: 'chili-vegan'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await settle(tester, frames: 20);
    await shot(tester, 'cook-step-1');

    // Walk to the first step that carries a timer, start it and let it run out.
    final cook = services.cook;
    final timed = [
      for (var i = 0; i < cook.stepCount; i++)
        if (cook.timerSecondsFor(i) != null) i,
    ];
    cook.goTo(timed.first);
    await settle(tester);
    cook.startTimer(timed.first);
    await settle(tester);
    await shot(tester, 'cook-timer-running');
    current = current.add(Duration(seconds: cook.timerSecondsFor(timed.first)! + 1));
    cook.tick();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 450));
    await shot(tester, 'cook-flash');
    await tester.tap(find.text('GOT IT'));
    await settle(tester);

    cook.goTo(cook.stepCount - 1);
    await settle(tester);
    cook.next();
    await settle(tester);
    await shot(tester, 'cook-done');
  });

  testWidgets('cookbook', (tester) async {
    final services = await setup(tester);
    await seed(tester, services);
    await pumpApp(tester, services, home: const HomeShell(initialTab: 2));
    await settle(tester, frames: 20);
    await shot(tester, 'cookbook-saved');
  });

  testWidgets('search', (tester) async {
    final services = await setup(tester);
    await pumpApp(tester, services, home: const HomeShell(initialTab: 1));
    await settle(tester, frames: 20);
    await shot(tester, 'search-empty');
    await tester.enterText(find.byType(TextField).first, 'pasta');
    await tester.pump(const Duration(milliseconds: 400));
    await settleAsync(tester, rounds: 20);
    await shot(tester, 'search-pasta');
    await tester.enterText(find.byType(TextField).first, 'sushi');
    await tester.pump(const Duration(milliseconds: 400));
    await settleAsync(tester, rounds: 20);
    await shot(tester, 'search-sushi');
  });

  testWidgets('plan', (tester) async {
    final services = await setup(tester);
    await seed(tester, services);
    await pumpApp(tester, services, home: const HomeShell(initialTab: 3));
    await settle(tester, frames: 20);
    await shot(tester, 'plan');
  });

  testWidgets('shopping', (tester) async {
    final services = await setup(tester);
    await seed(tester, services);
    await pumpApp(tester, services, home: const HomeShell(initialTab: 4));
    await settle(tester, frames: 20);
    await shot(tester, 'shopping');
  });

  testWidgets('settings, backup, faq, insights', (tester) async {
    final services = await setup(tester);
    await seed(tester, services);
    await tester.runAsync(() async {
      for (var m = 0; m < 6; m++) {
        for (final id in ['chili-vegan', 'pancakes-vegan', 'doener-vegan']) {
          final recipe = (await services.corpus.loadRecipe(id))!;
          await services.shopping.addRecipe(recipe, at: DateTime(2026, 4 + m, 5 + m));
        }
      }
    });
    await pumpApp(tester, services, home: const SettingsScreen());
    await settle(tester, frames: 20);
    await shot(tester, 'settings');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await settle(tester);
    await shot(tester, 'settings-2');

    await pumpApp(tester, services, home: const InsightsScreen());
    await settle(tester, frames: 20);
    await shot(tester, 'insights');

    await pumpApp(tester, services, home: const BackupScreen());
    await settle(tester, frames: 20);
    await shot(tester, 'backup');

    await pumpApp(tester, services, home: const FaqScreen());
    await settleAsync(tester, rounds: 20);
    await shot(tester, 'faq');
  });
}
