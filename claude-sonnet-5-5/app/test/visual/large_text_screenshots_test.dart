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
import 'package:morphcook/features/onboarding/onboarding_flow.dart';
import 'package:morphcook/features/settings/settings_screen.dart';
import 'package:morphcook/state/app_services.dart';

import '../support/screenshots.dart';
import '../support/test_app.dart';

/// The main screens at double text size on a small phone (360 by 740 dp), for
/// a person to look at. The layout tests only catch what throws. Clipped or
/// awkwardly wrapped text needs eyes:
///
///   flutter test --tags visual test/visual/large_text_screenshots_test.dart
void main() {
  setUpAll(() {
    goldenFileComparator = ScreenshotComparator.standard();
  });

  final evening = DateTime(2026, 9, 28, 18, 30);
  const sam = Profile(name: 'Sam', avoidFlags: {'vegan'}, maxTimeMinutes: 60);

  Future<AppServices> setup(WidgetTester tester, {bool onboarded = true, Profile profile = sam}) async {
    usePhone(tester, size: const Size(360, 740));
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await loadBundledFonts(tester);
    await loadMaterialIcons(tester);
    return buildServices(tester, profile: profile, onboarded: onboarded, now: evening);
  }

  Future<void> seed(WidgetTester tester, AppServices services) async {
    await tester.runAsync(() async {
      for (final id in ['doener-vegan', 'pancakes-vegan', 'chili-vegan']) {
        await services.cookbook.save(id, at: evening);
      }
      await services.history.add(HistoryEntry(recipeId: 'chili-vegan', cookedAt: evening, servings: 2));
      final week = WeekKey.fromDate(evening);
      await services.mealPlan.assign(week, 'mon.dinner', 'chili-vegan');
      await services.mealPlan.assign(week, 'tue.breakfast', 'pancakes-vegan');
      await services.shopping.addRecipe((await services.corpus.loadRecipe('chili-vegan'))!, at: evening);
    });
  }

  Future<void> scrollBy(WidgetTester tester, double dy) async {
    final scrollables = find.byType(Scrollable).evaluate().where((e) {
      final state = (e as StatefulElement).state as ScrollableState;
      return state.widget.axisDirection == AxisDirection.down && state.position.maxScrollExtent > 0;
    });
    for (final element in scrollables) {
      final state = (element as StatefulElement).state as ScrollableState;
      state.position.jumpTo((state.position.pixels + dy).clamp(0, state.position.maxScrollExtent));
    }
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('the tabs', (tester) async {
    final services = await setup(tester);
    await seed(tester, services);
    await pumpApp(tester, services, home: const HomeShell());
    await settleAsync(tester, rounds: 12);
    await settle(tester);
    await shot(tester, 'large-home');
    for (final (tab, name) in [('SEARCH', 'search'), ('COOKBOOK', 'cookbook'), ('PLAN', 'plan'), ('LIST', 'list')]) {
      await tester.tap(find.text(tab));
      await settleAsync(tester, rounds: 8);
      await settle(tester);
      await shot(tester, 'large-$name');
    }
  });

  testWidgets('a dish', (tester) async {
    final services = await setup(tester);
    await pumpApp(tester, services, home: const DishScreen(dishId: 'doener'));
    await pumpUntilFound(tester, find.text('START COOKING'));
    await settleAsync(tester, rounds: 6);
    await shot(tester, 'large-dish-top');
    await scrollBy(tester, 620);
    await shot(tester, 'large-dish-switcher');
    await tester.tap(find.textContaining('— DIET').first);
    await settle(tester);
    await shot(tester, 'large-dish-diet-open');
    await scrollBy(tester, 500);
    await shot(tester, 'large-dish-ingredients');
    await tester.ensureVisible(find.text('MACROS'));
    await tester.pump();
    await tester.tap(find.text('MACROS'));
    await settle(tester);
    await shot(tester, 'large-dish-macros');
  });

  testWidgets('cook mode', (tester) async {
    final services = await setup(tester);
    await pumpApp(tester, services, home: const CookScreen(recipeId: 'pancakes-classic'));
    await pumpUntilFound(tester, find.text('NEXT'));
    await settleAsync(tester, rounds: 6);
    await shot(tester, 'large-cook-step-1');
    services.cook.goTo(3);
    await settle(tester);
    await shot(tester, 'large-cook-step-4');
  });

  testWidgets('settings, backup and onboarding', (tester) async {
    final services = await setup(tester);
    await pumpApp(tester, services, home: const SettingsScreen());
    await settleAsync(tester, rounds: 8);
    await settle(tester);
    await shot(tester, 'large-settings-top');
    await scrollBy(tester, 700);
    await shot(tester, 'large-settings-middle');
    await pumpApp(tester, services, home: const BackupScreen());
    await settle(tester);
    await shot(tester, 'large-backup');
    final fresh = await buildServices(tester, onboarded: false, now: evening);
    await pumpApp(tester, fresh, home: const OnboardingFlow());
    await settle(tester);
    await tester.tap(find.text('NEXT'));
    await settle(tester);
    await tester.tap(find.text('NEXT'));
    await settle(tester);
    await shot(tester, 'large-onboarding-diet');
  });
}
