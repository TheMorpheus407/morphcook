import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/app/home_shell.dart';
import 'package:morphcook/data/models/history_entry.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/domain/plan/meal_plan.dart';
import 'package:morphcook/features/cook/cook_screen.dart';
import 'package:morphcook/features/dish/dish_screen.dart';
import 'package:morphcook/features/faq/faq_screen.dart';
import 'package:morphcook/features/settings/settings_screen.dart';
import 'package:morphcook/state/app_services.dart';

import '../support/test_app.dart';

void main() {
  // Monday 28 September 2026.
  DateTime at(int hour, {int day = 28}) => DateTime(2026, 9, day, hour, 20);

  Future<AppServices> open(
    WidgetTester tester, {
    Profile profile = const Profile(name: 'Sam'),
    DateTime? now,
    Future<void> Function(AppServices services)? prepare,
  }) async {
    usePhone(tester);
    await loadBundledFonts(tester);
    final services = await buildServices(tester, profile: profile, now: now ?? at(18));
    if (prepare != null) await prepare(services);
    await pumpApp(tester, services, home: const HomeShell());
    await settleAsync(tester, rounds: 12);
    return services;
  }

  group('the front page', () {
    testWidgets('a newspaper masthead with edition and date', (tester) async {
      await open(tester);
      expect(find.text('morphcook'), findsOneWidget);
      expect(find.text('a cookbook for every body.'), findsOneWidget);
      expect(find.text('VOL. 01 · NO. 271'), findsOneWidget);
      expect(find.text('MONDAY, 28 SEPTEMBER 2026'), findsOneWidget);
    });

    testWidgets('a featured dish and grid sections', (tester) async {
      await open(tester);
      expect(find.text('ON THE FRONT PAGE'), findsOneWidget);
      expect(find.text('READ THE RECIPE'), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await tester.pump();
      expect(find.text('tonight'), findsOneWidget);
    });

    testWidgets('the greeting follows the time of day and uses the name', (tester) async {
      for (final (hour, greeting) in [
        (7, 'good morning, Sam.'),
        (14, 'good afternoon, Sam.'),
        (19, 'good evening, Sam.'),
        (2, 'still up, Sam?'),
      ]) {
        await open(tester, now: at(hour));
        expect(find.text(greeting), findsOneWidget, reason: '$hour:20');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('without a name the greeting stands alone', (tester) async {
      await open(tester, profile: const Profile());
      expect(find.text('good evening.'), findsOneWidget);
    });

    testWidgets('German copy, dates and lowercase display', (tester) async {
      await open(
        tester,
        profile: const Profile(name: 'Anna', lang: 'de'),
      );
      expect(find.text('ein Kochbuch für jeden Körper.'), findsOneWidget);
      expect(find.text('guten Abend, Anna.'), findsOneWidget);
      expect(find.text('MONTAG, 28. SEPTEMBER 2026'), findsOneWidget);
      expect(find.text('AUF DER TITELSEITE'), findsOneWidget);
    });

    testWidgets('the footer counts the dishes', (tester) async {
      await open(tester);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -20000));
      await tester.pump();
      expect(find.textContaining('28 dishes and counting'), findsOneWidget);
    });
  });

  group('time-aware ranking on the front page', () {
    Future<String> featured(WidgetTester tester, DateTime now, {Profile profile = const Profile()}) async {
      await open(tester, now: now, profile: profile);
      final title = tester.widgetList<Text>(find.byType(Text)).where((t) => t.style?.fontSize == 40).first.data!;
      await tester.pumpWidget(const SizedBox());
      return title;
    }

    testWidgets('mornings put breakfast on the front page', (tester) async {
      final title = await featured(tester, at(8));
      final meals = ['pancakes', 'oats', 'toast', 'shakshuka', 'baked oats'];
      expect(meals.any(title.contains), isTrue, reason: title);
    });

    testWidgets('the evening favors dinner', (tester) async {
      final title = await featured(tester, at(19));
      final breakfast = ['pancakes', 'oats', 'avocado toast'];
      expect(breakfast.any(title.contains), isFalse, reason: title);
    });
  });

  group('effort today', () {
    testWidgets('three chips change the profile and the ranking', (tester) async {
      final services = await open(tester);
      expect(find.text('effort today:'), findsOneWidget);
      await tester.tap(find.text('hard'));
      await settleAsync(tester, rounds: 6);
      expect(services.profile.profile.preferredEffort, 'hard');
      await tester.tap(find.text('easy'));
      await settleAsync(tester, rounds: 6);
      expect(services.profile.profile.preferredEffort, 'easy');
    });
  });

  group('sections', () {
    testWidgets('cuisine shelves load in the background and lead to search', (tester) async {
      final services = await open(tester);
      expect(services.corpus.isPartitionLoaded('cuisine-italian'), isTrue);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await settleAsync(tester, rounds: 4);
      expect(find.text('from the italian shelf'), findsOneWidget);
      await tester.tap(find.text('MORE').last);
      await settle(tester, frames: 15);
    });

    testWidgets('"back on the table" brings back what has not been cooked for a month', (tester) async {
      await open(
        tester,
        prepare: (s) async {
          await s.history.add(
            HistoryEntry(
              recipeId: 'pancakes-classic',
              cookedAt: at(12).subtract(const Duration(days: 45)),
              servings: 2,
            ),
          );
        },
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
      await tester.pump();
      expect(find.text('back on the table'), findsOneWidget);
    });

    testWidgets('"quick & easy" only offers thirty minutes or less', (tester) async {
      await open(tester);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1600));
      await tester.pump();
      expect(find.text('quick & easy'), findsOneWidget);
    });

    testWidgets('tapping the featured dish opens exactly that variant', (tester) async {
      await open(tester);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -250));
      await tester.pump();
      await tester.tap(find.text('READ THE RECIPE'));
      await settle(tester, frames: 15);
      await pumpUntilFound(tester, find.byType(DishScreen));
    });
  });

  group("today's plan", () {
    testWidgets('meals planned for today show on top, and open that variant', (tester) async {
      final now = at(9);
      await open(
        tester,
        now: now,
        prepare: (s) async {
          await s.mealPlan.assign(WeekKey.fromDate(now), 'mon.dinner', 'doener-keto');
        },
      );
      expect(find.text('ON THE PLAN TODAY'), findsOneWidget);
      expect(find.text('dinner'), findsOneWidget);
      await tester.tap(find.text('Keto Döner Bowl'));
      await settle(tester, frames: 15);
      await pumpUntilFound(tester, find.text('keto döner bowl'));
    });

    testWidgets('nothing planned, no block', (tester) async {
      await open(tester);
      expect(find.text('ON THE PLAN TODAY'), findsNothing);
    });
  });

  group('continue cooking', () {
    testWidgets('a run that was left in the middle can be picked up from the front page', (tester) async {
      final services = await open(
        tester,
        prepare: (s) async {
          final recipe = (await tester.runAsync(() => s.corpus.loadRecipe('pancakes-classic')))!;
          await s.cook.begin(recipe);
          s.cook.goTo(3);
          await s.cook.suspend();
        },
      );
      expect(find.text('keep cooking'), findsOneWidget);
      expect(find.text('Fluffy Buttermilk Pancakes'), findsOneWidget);
      expect(find.text('step 4 of 6'), findsOneWidget);
      await tester.tap(find.text('Fluffy Buttermilk Pancakes'));
      await settle(tester, frames: 15);
      await pumpUntilFound(tester, find.byType(CookScreen));
      await settleAsync(tester, rounds: 6);
      expect(services.cook.stepIndex, 3);
    });

    testWidgets('no banner without a stored run', (tester) async {
      await open(tester);
      expect(find.text('keep cooking'), findsNothing);
    });
  });

  group('when nothing fits', () {
    testWidgets('says so kindly and offers the profile', (tester) async {
      await open(tester, profile: const Profile(avoidFlags: {'vegan'}, maxTimeMinutes: 5));
      expect(find.text('nothing fits right now.'), findsOneWidget);
      expect(find.text('ADJUST MY PROFILE'), findsOneWidget);
      await tester.tap(find.text('ADJUST MY PROFILE'));
      await settle(tester, frames: 15);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('and explains why in the help center', (tester) async {
      await open(tester, profile: const Profile(avoidFlags: {'vegan'}, maxTimeMinutes: 5));
      await tester.tap(find.text('WHY IS NOTHING SHOWING?'));
      await settle(tester, frames: 15);
      await pumpUntilFound(tester, find.byType(FaqScreen));
    });
  });

  group('header buttons', () {
    testWidgets('help and settings', (tester) async {
      await open(tester);
      await tester.tap(find.byTooltip('help'));
      await settle(tester, frames: 15);
      expect(find.byType(FaqScreen), findsOneWidget);
      await tester.tap(find.byTooltip('back'));
      await settle(tester, frames: 15);
      await tester.tap(find.byTooltip('settings').first);
      await settle(tester, frames: 15);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });

  group('the tab bar', () {
    testWidgets('five tabs: today, search, cookbook, plan, list', (tester) async {
      await open(tester);
      for (final tab in ['TODAY', 'SEARCH', 'COOKBOOK', 'PLAN', 'LIST']) {
        expect(find.text(tab), findsOneWidget, reason: tab);
      }
      await tester.tap(find.text('COOKBOOK'));
      await settle(tester);
      expect(find.text('your versions, kept close.'), findsOneWidget);
      await tester.tap(find.text('LIST'));
      await settle(tester);
      expect(find.text('one list, sorted by aisle.'), findsOneWidget);
      await tester.tap(find.text('PLAN'));
      await settle(tester);
      expect(find.text('the week, penciled in.'), findsOneWidget);
    });
  });
}
