import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/app/home_shell.dart';
import 'package:morphcook/core/app_info.dart';
import 'package:morphcook/data/models/history_entry.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/domain/plan/meal_plan.dart';
import 'package:morphcook/features/backup/backup_screen.dart';
import 'package:morphcook/features/faq/faq_screen.dart';
import 'package:morphcook/features/insights/insights_screen.dart';
import 'package:morphcook/features/onboarding/onboarding_flow.dart';
import 'package:morphcook/features/settings/settings_screen.dart';
import 'package:morphcook/state/app_services.dart';

import '../support/test_app.dart';

void main() {
  Future<AppServices> open(
    WidgetTester tester, {
    Profile profile = const Profile(name: 'Sam'),
    bool viaApp = false,
  }) async {
    usePhone(tester);
    await loadBundledFonts(tester);
    final services = await buildServices(tester, profile: profile, now: DateTime(2026, 9, 28, 18));
    if (viaApp) {
      await pumpApp(tester, services);
      await settle(tester, frames: 15);
      final navigator = Navigator.of(tester.element(find.byType(HomeShell)));
      unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())));
    } else {
      await pumpApp(tester, services, home: const SettingsScreen());
    }
    await settle(tester, frames: 15);
    return services;
  }

  /// The switch of the settings row with this title.
  Finder switchOf(String title) => find.descendant(
    of: find.ancestor(of: find.text(title), matching: find.byType(MergeSemantics)),
    matching: find.byType(Switch),
  );

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 250, scrollable: find.byType(Scrollable).first);
    await tester.pump();
  }

  group('profile editor', () {
    testWidgets('shows the name and every part of the profile', (tester) async {
      await open(
        tester,
        profile: const Profile(name: 'Sam', avoidFlags: {'vegan'}, maxTimeMinutes: 45),
      );
      expect(find.text('settings'), findsOneWidget);
      expect(find.text('Sam'), findsOneWidget);
      for (final heading in ['you', 'eating style', 'what stays out']) {
        expect(find.text(heading), findsOneWidget, reason: heading);
      }
      await scrollTo(tester, find.text('effort'));
      await scrollTo(tester, find.text('time budget'));
      await scrollTo(tester, find.text('calories'));
    });

    testWidgets('editing the name updates the profile', (tester) async {
      final services = await open(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Sam'), '  Robin ');
      await tester.pump();
      expect(services.profile.profile.name, 'Robin');
    });

    testWidgets('the language toggle switches every screen text at once', (tester) async {
      final services = await open(tester);
      expect(find.text('English'), findsOneWidget);
      await tester.tap(find.text('Deutsch'));
      await settle(tester);
      expect(services.profile.profile.lang, 'de');
      expect(find.text('einstellungen'), findsOneWidget);
      await tester.tap(find.text('English'));
      await settle(tester);
      expect(find.text('settings'), findsOneWidget);
    });

    testWidgets('diet shortcuts, class avoidance, required attributes, effort and time all write into the profile', (
      tester,
    ) async {
      final services = await open(tester);
      await tester.tap(find.text('halal'));
      await tester.pump();
      expect(services.profile.profile.avoidFlags, {'halal'});
      await tester.tap(find.text('halal'));
      await tester.pump();
      expect(services.profile.profile.avoidFlags, isEmpty, reason: 'tapping again removes it');

      await scrollTo(tester, find.text('gluten'));
      await tester.tap(find.text('gluten'));
      await tester.pump();
      expect(services.profile.profile.avoidFlags, {'gluten'});

      await scrollTo(tester, find.text('keto'));
      await tester.tap(find.text('keto'));
      await tester.pump();
      expect(services.profile.profile.requiredAttributes, {'keto'});

      await scrollTo(tester, find.text('easy'));
      await tester.tap(find.text('easy'));
      await tester.pump();
      expect(services.profile.profile.preferredEffort, 'easy');

      await scrollTo(tester, find.text('30 min'));
      await tester.tap(find.text('30 min'));
      await tester.pump();
      expect(services.profile.profile.maxTimeMinutes, 30);
      await tester.tap(find.text('no limit'));
      await tester.pump();
      expect(services.profile.profile.maxTimeMinutes, isNull);
    });

    testWidgets('specific ingredient avoidance finds parents and leaves and can be removed', (tester) async {
      final services = await open(tester);
      await scrollTo(tester, find.byType(TextField).last);
      await tester.enterText(find.byType(TextField).last, 'apple');
      await settle(tester); // the field scrolls itself into view first
      await tester.tap(find.text('apple').last);
      await tester.pump();
      expect(services.profile.profile.avoidIngredients, contains('apple'));
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pump();
      expect(services.profile.profile.avoidIngredients, isEmpty);
    });

    testWidgets('the calorie target is a switch with a slider and adjustable flexibility', (tester) async {
      final services = await open(tester);
      await scrollTo(tester, find.text('aim for a calorie target'));
      await tester.tap(find.byType(Switch).first);
      await settle(tester);
      expect(services.profile.profile.calorieTarget, 600);
      expect(find.text('~600'), findsOneWidget);
      await tester.drag(find.byType(Slider), const Offset(60, 0));
      await tester.pump();
      expect(services.profile.profile.calorieTarget, greaterThan(600));
      await scrollTo(tester, find.text('± 250'));
      await tester.tap(find.text('± 250'));
      await tester.pump();
      expect(services.profile.profile.calorieTolerance, 250);
    });

    testWidgets('halal and kosher come with a note that never claims certification', (tester) async {
      await open(tester);
      final note = find.textContaining('halal-compatible');
      expect(note, findsOneWidget);
      expect(find.textContaining('certified'), findsNothing);
      expect(find.textContaining('certification depends on sourcing'), findsOneWidget);
    });
  });

  group('adaptation preferences', () {
    testWidgets('variant tags can be hidden', (tester) async {
      final services = await open(tester);
      await scrollTo(tester, find.text('show variant tags'));
      await tester.tap(switchOf('show variant tags'));
      await tester.pump();
      expect(services.profile.profile.showVariantTags, isFalse);
    });

    testWidgets('reduceMotion: follow the system, reduced or full', (tester) async {
      final services = await open(tester);
      await scrollTo(tester, find.text('reduced'));
      expect(services.profile.profile.reduceMotion, isNull);
      await tester.tap(find.text('reduced'));
      await tester.pump();
      expect(services.profile.profile.reduceMotion, isTrue);
      expect(services.motion.reduceMotion, isTrue);
      await tester.tap(find.text('full'));
      await tester.pump();
      expect(services.profile.profile.reduceMotion, isFalse);
      expect(services.motion.reduceMotion, isFalse);
      await tester.tap(find.text('follow system'));
      await tester.pump();
      expect(services.profile.profile.reduceMotion, isNull);
    });
  });

  group('cook mode options', () {
    testWidgets('visual alert, timer sound and tap-to-advance', (tester) async {
      final services = await open(tester);
      await scrollTo(tester, find.text('flash when a timer ends'));
      expect(services.profile.settings.visualAlertEnabled, isTrue, reason: 'on by default');
      expect(services.profile.settings.quickNextTapEnabled, isFalse, reason: 'opt-in');
      await tester.tap(switchOf('flash when a timer ends'));
      await tester.pump();
      expect(services.profile.settings.visualAlertEnabled, isFalse);

      await tester.tap(switchOf('timer sound'));
      await tester.pump();
      expect(services.profile.settings.timerSoundEnabled, isFalse);

      await tester.tap(switchOf('tap to advance'));
      await tester.pump();
      expect(services.oneHanded.quickNextTapEnabled, isTrue);
      expect(services.profile.settings.quickNextTapEnabled, isTrue);
    });
  });

  group('data, help and about', () {
    testWidgets('links open Shopping Insights, backup and the Help Center', (tester) async {
      await open(tester);
      await scrollTo(tester, find.text('insights'));
      await tester.tap(find.text('insights'));
      await settle(tester, frames: 15);
      expect(find.byType(InsightsScreen), findsOneWidget);
      await tester.tap(find.byTooltip('back'));
      await settle(tester, frames: 15);

      await scrollTo(tester, find.text('backup & restore'));
      await tester.tap(find.text('backup & restore'));
      await settle(tester, frames: 15);
      expect(find.byType(BackupScreen), findsOneWidget);
      await tester.tap(find.byTooltip('back'));
      await settle(tester, frames: 15);

      await scrollTo(tester, find.text('help center'));
      await tester.tap(find.text('help center'));
      await settle(tester, frames: 15);
      expect(find.byType(FaqScreen), findsOneWidget);
    });

    testWidgets('shows the version and how many searches were noted for the wish list', (tester) async {
      final services = await open(tester);
      await services.contentRequests.add('sushi');
      await services.contentRequests.add('tacos');
      await tester.pump();
      await scrollTo(tester, find.text('version $kAppVersion'));
      expect(find.text('version $kAppVersion'), findsOneWidget);
      expect(find.text('2 searches noted for the wish list'), findsOneWidget);
    });

    testWidgets('the app says that it lives on the phone and sends nothing anywhere', (tester) async {
      await open(tester);
      await scrollTo(tester, find.textContaining('nothing you do is sent anywhere'));
      expect(find.textContaining('lives entirely on your phone'), findsOneWidget);
    });
  });

  group('delete all my data', () {
    testWidgets('asks first, and cancelling changes nothing', (tester) async {
      final services = await open(tester, viaApp: true);
      await services.cookbook.save('doener-vegan');
      await scrollTo(tester, find.text('DELETE ALL MY DATA'));
      await tester.tap(find.text('DELETE ALL MY DATA'));
      await settle(tester);
      expect(find.textContaining('this cannot be undone'), findsOneWidget);
      await tester.tap(find.text('cancel'));
      await settle(tester);
      expect(services.cookbook.count, 1);
      expect(services.profile.onboarded, isTrue);
    });

    testWidgets('confirming wipes everything and returns to onboarding', (tester) async {
      final services = await open(tester, viaApp: true);
      await services.cookbook.save('doener-vegan');
      await services.history.add(HistoryEntry(recipeId: 'chili-vegan', cookedAt: DateTime(2026, 9, 1), servings: 2));
      await services.mealPlan.assign(WeekKey.fromDate(DateTime(2026, 9, 28)), 'mon.dinner', 'chili-vegan');
      await services.contentRequests.add('sushi');
      final chili = await tester.runAsync(() => services.corpus.loadRecipe('chili-vegan'));
      await services.shopping.addRecipe(chili!);
      await services.profile.setCalorieOverride('doener', true);
      await scrollTo(tester, find.text('DELETE ALL MY DATA'));
      await tester.tap(find.text('DELETE ALL MY DATA'));
      await settle(tester);
      await tester.tap(find.text('delete all my data').last);
      await settle(tester, frames: 25);
      expect(services.cookbook.count, 0);
      expect(services.history.count, 0);
      expect(services.mealPlan.plan.isEmpty, isTrue);
      expect(services.contentRequests.count, 0);
      expect(services.shopping.isEmpty, isTrue);
      expect(services.shopping.events, isEmpty);
      expect(services.profile.onboarded, isFalse);
      expect(services.profile.calorieOverrideFor('doener'), isFalse);
      expect(find.byType(OnboardingFlow), findsOneWidget);
    });
  });
}
