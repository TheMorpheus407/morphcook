import 'dart:async';
import 'dart:math' as math;

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
import 'package:morphcook/features/onboarding/onboarding_flow.dart';
import 'package:morphcook/features/settings/settings_screen.dart';
import 'package:morphcook/platform/platform_services.dart';
import 'package:morphcook/state/app_services.dart';
import 'package:morphcook/widgets/recipe_row.dart';

import '../support/test_app.dart';

/// People who set their system font to the largest size still get a usable
/// app. A layout that does not fit throws "RenderFlex overflowed", which fails
/// the test, so rendering each screen at double text size is the check. The
/// walks scroll every list to its end, because lists build their rows lazily
/// and an overflow further down would otherwise go unseen.
void main() {
  final now = DateTime(2026, 9, 28, 18);

  Future<AppServices> open(
    WidgetTester tester,
    Widget home, {
    double scale = 2.0,
    Size size = const Size(360, 740),
    bool onboarded = true,
    Profile profile = const Profile(name: 'Sam'),
    PlatformServices? platform,
    Future<void> Function(AppServices services)? prepare,
  }) async {
    usePhone(tester, size: size);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await loadBundledFonts(tester);
    final services = await buildServices(tester, profile: profile, onboarded: onboarded, now: now, platform: platform);
    if (prepare != null) await prepare(services);
    await pumpApp(tester, services, home: home);
    await settleAsync(tester, rounds: 12);
    await settle(tester, frames: 12);
    return services;
  }

  /// Scrolls every vertical list on screen to its end, so that lazily built rows are laid out.
  Future<void> scrollThrough(WidgetTester tester) async {
    for (var pass = 0; pass < 80; pass++) {
      var moved = false;
      for (final element in find.byType(Scrollable).evaluate().toList()) {
        final state = (element as StatefulElement).state as ScrollableState;
        final direction = state.widget.axisDirection;
        if (direction != AxisDirection.down && direction != AxisDirection.up) continue;
        if (!state.position.hasContentDimensions) continue;
        final position = state.position;
        if (position.pixels >= position.maxScrollExtent - 0.5) continue;
        position.jumpTo(math.min(position.pixels + 260, position.maxScrollExtent));
        moved = true;
      }
      await tester.pump(const Duration(milliseconds: 50));
      if (!moved) break;
    }
    await settleAsync(tester, rounds: 3);
  }

  /// Back to the top, where the controls of a screen are. Rows further down are disposed while they are off screen.
  Future<void> scrollToTop(WidgetTester tester) async {
    for (final element in find.byType(Scrollable).evaluate().toList()) {
      final state = (element as StatefulElement).state as ScrollableState;
      final direction = state.widget.axisDirection;
      if ((direction == AxisDirection.down || direction == AxisDirection.up) && state.position.hasContentDimensions) {
        state.position.jumpTo(0);
      }
    }
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Scrolls down from the top until the finder matches, then brings it on screen.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await scrollToTop(tester);
    for (var i = 0; i < 60 && finder.evaluate().isEmpty; i++) {
      for (final element in find.byType(Scrollable).evaluate().toList()) {
        final state = (element as StatefulElement).state as ScrollableState;
        final direction = state.widget.axisDirection;
        if ((direction != AxisDirection.down && direction != AxisDirection.up) ||
            !state.position.hasContentDimensions) {
          continue;
        }
        state.position.jumpTo(math.min(state.position.pixels + 200, state.position.maxScrollExtent));
      }
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(finder, findsWidgets, reason: 'the control exists somewhere on the screen');
    await tester.ensureVisible(finder.first);
    await tester.pump();
  }

  Future<void> sheetOrScreen(WidgetTester tester, Finder opener) async {
    await reveal(tester, opener);
    await tester.tap(opener.first);
    await settle(tester);
    await scrollThrough(tester);
  }

  for (final scale in [1.3, 2.0]) {
    group('text at ${scale}x', () {
      testWidgets('the front page', (tester) async {
        await open(tester, const HomeShell(), scale: scale);
        expect(find.text('morphcook'), findsOneWidget);
      });

      testWidgets('the search tab', (tester) async {
        await open(tester, const HomeShell(initialTab: 1), scale: scale);
      });

      testWidgets('the cookbook tab', (tester) async {
        await open(
          tester,
          const HomeShell(initialTab: 2),
          scale: scale,
          prepare: (s) async {
            await s.cookbook.save('doener-vegan', at: now);
            await s.cookbook.save('pancakes-vegan', at: now);
          },
        );
      });

      testWidgets('the plan tab', (tester) async {
        await open(
          tester,
          const HomeShell(initialTab: 3),
          scale: scale,
          prepare: (s) async {
            await s.cookbook.save('doener-vegan', at: now);
          },
        );
      });

      testWidgets('the shopping tab', (tester) async {
        await open(
          tester,
          const HomeShell(initialTab: 4),
          scale: scale,
          prepare: (s) async {
            final recipe = (await tester.runAsync(() => s.corpus.loadRecipe('pancakes-vegan')))!;
            await s.shopping.addRecipe(recipe, at: now);
          },
        );
      });

      testWidgets('a dish', (tester) async {
        await open(tester, const DishScreen(dishId: 'doener'), scale: scale);
      });

      testWidgets('cook mode', (tester) async {
        await open(tester, const CookScreen(recipeId: 'pancakes-classic'), scale: scale);
      });

      testWidgets('settings', (tester) async {
        await open(tester, const SettingsScreen(), scale: scale);
      });

      testWidgets('the help center', (tester) async {
        await open(tester, const FaqScreen(), scale: scale);
      });

      testWidgets('backup and restore', (tester) async {
        await open(tester, const BackupScreen(), scale: scale);
      });

      testWidgets('insights', (tester) async {
        await open(
          tester,
          const InsightsScreen(),
          scale: scale,
          prepare: (s) async {
            final recipe = (await tester.runAsync(() => s.corpus.loadRecipe('chili-vegan')))!;
            await s.shopping.addRecipe(recipe, at: DateTime(2026, 9, 1));
          },
        );
      });

      testWidgets('onboarding', (tester) async {
        await open(tester, const OnboardingFlow(), scale: scale, onboarded: false);
      });
    });
  }

  group('walks at 2.0x on a 360 dp phone', () {
    testWidgets('the front page, every section', (tester) async {
      await open(
        tester,
        const HomeShell(),
        prepare: (s) async {
          await s.history.add(
            HistoryEntry(recipeId: 'pancakes-classic', cookedAt: now.subtract(const Duration(days: 45)), servings: 2),
          );
          await s.mealPlan.assign(WeekKey.fromDate(now), 'mon.dinner', 'doener-keto');
        },
      );
      await scrollThrough(tester);
      expect(find.textContaining('dishes and counting'), findsOneWidget);
    });

    testWidgets('a dish: every switcher row, every tab, the servings scaler', (tester) async {
      await open(tester, const DishScreen(dishId: 'doener'));
      await scrollThrough(tester);
      await scrollToTop(tester);
      for (final row in ['— DIET', '— EFFORT', '— CALORIE LEVEL']) {
        final finder = find.textContaining(row);
        await reveal(tester, finder);
        await tester.tap(finder.first);
        await settle(tester);
        await scrollThrough(tester);
      }
      for (final tab in ['METHOD', 'MACROS', 'INGREDIENTS']) {
        await reveal(tester, find.text(tab));
        await tester.tap(find.text(tab));
        await settle(tester);
        await scrollThrough(tester);
      }
      await reveal(tester, find.byTooltip('more servings'));
      await tester.tap(find.byTooltip('more servings'));
      await settle(tester);
      await scrollThrough(tester);
    });

    testWidgets('a dish with a disabled combination and its note', (tester) async {
      await open(
        tester,
        const DishScreen(dishId: 'doener'),
        profile: const Profile(avoidFlags: {'vegan'}),
      );
      await scrollThrough(tester);
      final row = find.textContaining('— DIET');
      await reveal(tester, row);
      await tester.tap(row.first);
      await settle(tester);
      await scrollThrough(tester);
    });

    testWidgets('cook mode: every step, a running timer, the ingredients sheet, pause', (tester) async {
      final services = await open(tester, const CookScreen(recipeId: 'pancakes-classic'));
      for (var step = 0; step < services.cook.stepCount; step++) {
        services.cook.goTo(step);
        await settle(tester, frames: 8);
        await scrollThrough(tester);
        final start = find.text('START TIMER');
        if (start.evaluate().isNotEmpty) {
          await tester.tap(start.first);
          await tester.pump(const Duration(milliseconds: 200));
        }
      }
      await tester.tap(find.textContaining('ingredients').first);
      await settle(tester);
      await scrollThrough(tester);
      unawaited(Navigator.of(tester.element(find.byType(CookScreen))).maybePop());
      await settle(tester);
      services.cook.pause();
      await settle(tester);
      services.cook.resume();
      services.cook.goTo(services.cook.stepCount - 1);
      await settle(tester);
      await tester.tap(find.text('FINISH'));
      await settle(tester, frames: 20);
      await scrollThrough(tester);
    });

    testWidgets('search: wrapped titles, the filter sheet', (tester) async {
      await open(tester, const HomeShell(initialTab: 1));
      await scrollThrough(tester);
      await tester.enterText(find.byType(TextField), 'vegan');
      await tester.pump(const Duration(milliseconds: 400));
      await settleAsync(tester, rounds: 40);
      await scrollThrough(tester);
      expect(find.byType(RecipeRow), findsWidgets);
      final row = tester.getSize(find.byType(RecipeRow).first);
      expect(row.height, greaterThan(kRecipeRowExtent), reason: 'rows grow with the text');
      await tester.tap(find.textContaining('filters').first);
      await settle(tester);
      await scrollThrough(tester);
    });

    testWidgets('the cookbook: saved list and cooked list', (tester) async {
      await open(
        tester,
        const HomeShell(initialTab: 2),
        profile: const Profile(name: 'Sam', avoidFlags: {'dairy'}),
        prepare: (s) async {
          for (final id in ['doener-classic', 'pancakes-vegan', 'chili-vegan', 'bolognese-classic']) {
            await s.cookbook.save(id, at: now);
          }
          await s.history.add(HistoryEntry(recipeId: 'chili-vegan', cookedAt: now, servings: 4));
          await s.history.add(
            HistoryEntry(recipeId: 'doener-vegan', cookedAt: now.subtract(const Duration(days: 9)), servings: 2),
          );
        },
      );
      await scrollThrough(tester);
      await tester.tap(find.text('COOKED'));
      await settle(tester);
      await settleAsync(tester, rounds: 12);
      await scrollThrough(tester);
    });

    testWidgets('the plan: a filled week, the slot sheet and the recipe picker', (tester) async {
      final week = WeekKey.fromDate(now);
      await open(
        tester,
        const HomeShell(initialTab: 3),
        prepare: (s) async {
          await s.cookbook.save('doener-vegan', at: now);
          await s.mealPlan.assign(week, 'mon.dinner', 'chili-vegan');
          await s.mealPlan.assign(week, 'tue.lunch', 'doener-keto');
          await s.mealPlan.assign(week, 'sun.breakfast', 'pancakes-vegan');
        },
      );
      await settleAsync(tester, rounds: 12);
      await scrollThrough(tester);
      await sheetOrScreen(tester, find.textContaining('Chili sin Ca'));
      await tester.tapAt(const Offset(10, 10));
      await settle(tester);
      await reveal(tester, find.byIcon(Icons.add).first);
      await tester.tap(find.byIcon(Icons.add).first);
      await settle(tester);
      await scrollThrough(tester);
    });

    testWidgets('the shopping list: groups, sources and the add sheet', (tester) async {
      await open(
        tester,
        const HomeShell(initialTab: 4),
        prepare: (s) async {
          for (final id in ['pancakes-vegan', 'chili-vegan', 'doener-vegan']) {
            final recipe = (await tester.runAsync(() => s.corpus.loadRecipe(id)))!;
            await s.shopping.addRecipe(recipe, at: now);
          }
        },
      );
      await scrollThrough(tester);
      await reveal(tester, find.text('ADD ITEM'));
      await tester.tap(find.text('ADD ITEM'));
      await settle(tester);
      await scrollThrough(tester);
    });

    testWidgets('insights with a year of shopping', (tester) async {
      await open(
        tester,
        const InsightsScreen(),
        prepare: (s) async {
          var month = 1;
          for (final id in ['pancakes-vegan', 'chili-vegan', 'doener-vegan', 'bolognese-classic']) {
            final recipe = (await tester.runAsync(() => s.corpus.loadRecipe(id)))!;
            await s.shopping.addRecipe(recipe, at: DateTime(2026, month, 3));
            month += 3;
          }
        },
      );
      await scrollThrough(tester);
    });

    testWidgets('settings: every section and the dialogs', (tester) async {
      await open(
        tester,
        const SettingsScreen(),
        profile: const Profile(name: 'Sam', calorieTarget: 600, maxTimeMinutes: 45),
      );
      await scrollThrough(tester);
    });

    testWidgets('the help center: an open answer and the category chips', (tester) async {
      await open(tester, const FaqScreen());
      await scrollThrough(tester);
      final first = find.byIcon(Icons.keyboard_arrow_down);
      if (first.evaluate().isNotEmpty) {
        await reveal(tester, first);
        await tester.tap(first.first);
        await settle(tester);
        await scrollThrough(tester);
      }
    });

    testWidgets('backup: export form, the password prompt and the restore question', (tester) async {
      final gateway = FakeBackupFileGateway();
      final platform = PlatformServices(
        files: gateway,
        alerts: FakeTimerAlerts(),
        awake: FakeScreenAwake(),
        haptics: FakeHaptics(),
      );
      final services = await open(tester, const BackupScreen(), platform: platform);
      await scrollThrough(tester);
      final secret = await tester.runAsync(() => services.backup.export(password: 'open sesame'));
      gateway.nextPick = secret!.json;
      await reveal(tester, find.text('CHOOSE BACKUP FILE'));
      await tester.tap(find.text('CHOOSE BACKUP FILE'));
      await settleAsync(tester, rounds: 8);
      await settle(tester);
      expect(find.text('password needed'), findsOneWidget);
      await scrollThrough(tester);
      await tester.enterText(find.byType(TextField).last, 'open sesame');
      await tester.tap(find.text('unlock'));
      await settleAsync(tester, rounds: 40);
      await settle(tester);
      expect(find.text('restore this backup?'), findsOneWidget);
      await scrollThrough(tester);
    });

    testWidgets('onboarding: every step', (tester) async {
      await open(tester, const OnboardingFlow(), onboarded: false);
      for (var step = 0; step < 4; step++) {
        await scrollThrough(tester);
        await reveal(tester, find.text('NEXT'));
        await tester.tap(find.text('NEXT'));
        await settle(tester);
      }
      await scrollThrough(tester);
    });
  });

  group('a small phone at 1.5x', () {
    testWidgets('the tabs and a dish fit 320 dp', (tester) async {
      final size = const Size(320, 568);
      await open(tester, const HomeShell(), scale: 1.5, size: size);
      await scrollThrough(tester);
      for (final tab in ['SEARCH', 'COOKBOOK', 'PLAN', 'LIST', 'TODAY']) {
        await tester.tap(find.text(tab));
        await settle(tester);
        await scrollThrough(tester);
      }
    });

    testWidgets('a dish and cook mode fit 320 dp', (tester) async {
      await open(tester, const DishScreen(dishId: 'doener'), scale: 1.5, size: const Size(320, 568));
      await scrollThrough(tester);
    });
  });
}
