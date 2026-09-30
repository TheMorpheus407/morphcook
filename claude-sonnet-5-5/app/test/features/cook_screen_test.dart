import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/theme/palette.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/features/cook/cook_screen.dart';
import 'package:morphcook/features/cook/timer_widgets.dart';
import 'package:morphcook/features/dish/dish_screen.dart';
import 'package:morphcook/platform/platform_services.dart';
import 'package:morphcook/state/app_services.dart';

import '../support/test_app.dart';

void main() {
  var now = DateTime(2026, 9, 28, 18);

  late FakeTimerAlerts alerts;
  late FakeHaptics haptics;
  late FakeScreenAwake awake;

  Future<AppServices> open(
    WidgetTester tester, {
    String recipe = 'pancakes-classic',
    Profile profile = const Profile(name: 'Jo'),
    bool resume = false,
    double? servings,
    AppServices? existing,
    String ready = 'NEXT',
  }) async {
    usePhone(tester);
    await loadBundledFonts(tester);
    now = DateTime(2026, 9, 28, 18);
    alerts = FakeTimerAlerts();
    haptics = FakeHaptics();
    awake = FakeScreenAwake();
    final services =
        existing ??
        await buildServices(
          tester,
          profile: profile,
          clock: () => now,
          platform: PlatformServices(files: FakeBackupFileGateway(), alerts: alerts, awake: awake, haptics: haptics),
        );
    // Cook mode is pushed on top of another page, as in the app, so "leave" can pop it.
    await pumpApp(tester, services, home: const Scaffold(body: Text('kitchen')));
    unawaited(
      Navigator.of(tester.element(find.text('kitchen'))).push(
        MaterialPageRoute<void>(
          builder: (_) => CookScreen(recipeId: recipe, resume: resume, servings: servings),
        ),
      ),
    );
    await pumpUntilFound(tester, find.text(ready));
    await settle(tester);
    return services;
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.text('NEXT'));
    await settle(tester);
  }

  /// Advances the fake clock and lets the controller notice.
  Future<void> passTime(WidgetTester tester, AppServices services, int seconds) async {
    now = now.add(Duration(seconds: seconds));
    services.cook.tick();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('look and feel', () {
    testWidgets('dark, full bleed, one step at a time', (tester) async {
      await open(tester);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, Palette.night);
      expect(find.text('Whisk the flour, sugar, baking powder and salt in a large bowl.'), findsOneWidget);
      expect(find.text('1'), findsOneWidget, reason: 'the big step number');
      expect(find.textContaining('step 1 of 6'), findsOneWidget);
    });

    testWidgets('the screen stays awake while cooking and is released afterwards', (tester) async {
      await open(tester);
      expect(awake.on, isTrue);
      await tester.tap(find.byTooltip('leave and keep my place'));
      await settle(tester, frames: 15);
      expect(awake.on, isFalse);
    });

    testWidgets('the copy follows the language', (tester) async {
      await open(
        tester,
        profile: const Profile(lang: 'de'),
        ready: 'WEITER',
      );
      expect(find.text('Verrühre Mehl, Zucker, Backpulver und Salz in einer großen Schüssel.'), findsOneWidget);
      expect(find.textContaining('Schritt 1 von 6'), findsOneWidget);
      expect(find.text('WEITER'), findsOneWidget);
    });
  });

  group('steps', () {
    testWidgets('next and previous move through the recipe', (tester) async {
      final services = await open(tester);
      await next(tester);
      expect(services.cook.stepIndex, 1);
      expect(find.text('In a second bowl whisk the buttermilk, egg and melted butter.'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await settle(tester);
      expect(services.cook.stepIndex, 0);
    });

    testWidgets('the last step offers "finish" instead of "next"', (tester) async {
      final services = await open(tester);
      services.cook.goTo(5);
      await settle(tester);
      expect(find.text('FINISH'), findsOneWidget);
      expect(find.text('NEXT'), findsNothing);
    });

    testWidgets('tapping a dash of the progress bar jumps to that step', (tester) async {
      final services = await open(tester);
      final dashes = find.byType(AnimatedContainer);
      expect(dashes, findsWidgets);
      await tester.tap(dashes.at(3));
      await settle(tester);
      expect(services.cook.stepIndex, 3);
    });

    testWidgets('swiping between steps works as well', (tester) async {
      final services = await open(tester);
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1500);
      await settle(tester);
      expect(services.cook.stepIndex, 1);
    });
  });

  group('per-step timer', () {
    testWidgets('a step with a timer offers it; a step without does not', (tester) async {
      final services = await open(tester);
      expect(find.byType(TimerRing), findsNothing, reason: 'step 1 has no timer');
      services.cook.goTo(2);
      await settle(tester);
      expect(find.byType(TimerRing), findsOneWidget);
      expect(find.text('05:00'), findsOneWidget);
      expect(find.text('START TIMER'), findsOneWidget);
    });

    testWidgets('start, count down, pause, resume, reset', (tester) async {
      final services = await open(tester);
      services.cook.goTo(2);
      await settle(tester);
      await tester.tap(find.text('START TIMER'));
      await settle(tester);
      expect(find.text('PAUSE TIMER'), findsOneWidget);
      await passTime(tester, services, 90);
      expect(find.text('03:30'), findsOneWidget);

      await tester.tap(find.text('PAUSE TIMER'));
      await settle(tester);
      await passTime(tester, services, 60);
      expect(find.text('03:30'), findsOneWidget, reason: 'frozen while paused');
      expect(find.text('RESUME TIMER'), findsOneWidget);

      await tester.tap(find.text('RESUME TIMER'));
      await settle(tester);
      await passTime(tester, services, 30);
      expect(find.text('03:00'), findsOneWidget);

      await tester.tap(find.byTooltip('reset timer'));
      await settle(tester);
      expect(find.text('05:00'), findsOneWidget);
      expect(find.text('START TIMER'), findsOneWidget);
    });

    testWidgets('a running timer stays visible while you read other steps', (tester) async {
      final services = await open(tester);
      services.cook.goTo(2);
      await settle(tester);
      await tester.tap(find.text('START TIMER'));
      await settle(tester);
      await next(tester);
      await passTime(tester, services, 10);
      expect(find.text('step 3  04:50'), findsOneWidget);
      await tester.tap(find.text('step 3  04:50'));
      await settle(tester);
      expect(services.cook.stepIndex, 2, reason: 'tapping the chip jumps back to its step');
    });

    testWidgets('the ring shows the fraction that is left', (tester) async {
      final services = await open(tester);
      services.cook.goTo(2);
      await settle(tester);
      await tester.tap(find.text('START TIMER'));
      await settle(tester);
      await passTime(tester, services, 150);
      final ring = tester.widget<TimerRing>(find.byType(TimerRing));
      expect(ring.remaining, 150);
      expect(ring.total, 300);
      expect(ring.running, isTrue);
    });
  });

  group('visual alert on timer completion (accessibility)', () {
    Future<AppServices> finishTimer(WidgetTester tester, {Profile profile = const Profile(name: 'Jo')}) async {
      final services = await open(tester, profile: profile);
      services.cook.goTo(4); // 120 seconds
      await settle(tester);
      await tester.tap(find.text('START TIMER'));
      await settle(tester);
      await passTime(tester, services, 121);
      return services;
    }

    testWidgets('a coral and teal flash covers the screen, with a way to dismiss it', (tester) async {
      await finishTimer(tester);
      expect(find.byType(TimerFlashOverlay), findsOneWidget);
      expect(
        find.descendant(of: find.byType(TimerFlashOverlay), matching: find.byType(AnimatedBuilder)),
        findsWidgets,
        reason: 'the pulse',
      );
      expect(find.text('timer done: step 5'), findsOneWidget);
      expect(find.text('GOT IT'), findsOneWidget);
      expect(alerts.alerts, 1, reason: 'sound and vibration go together with the flash');
      expect(alerts.lastSound, isTrue);

      Color overlayColor() {
        final container = tester
            .widgetList<Container>(
              find.descendant(of: find.byType(TimerFlashOverlay), matching: find.byType(Container)),
            )
            .first;
        return container.color!;
      }

      final first = overlayColor();
      await tester.pump(const Duration(milliseconds: 450));
      final second = overlayColor();
      expect(second, isNot(first), reason: 'it pulses between coral and teal');
      // Pulses are slow: one full cycle takes 1.8 seconds, far below three flashes per second.
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump(const Duration(milliseconds: 450));

      await tester.tap(find.text('GOT IT'));
      await settle(tester);
      expect(find.byType(TimerFlashOverlay), findsNothing);
      expect(alerts.stops, greaterThan(0));
    });

    testWidgets('it can be turned off with visualAlertEnabled; the sound still plays', (tester) async {
      final services = await open(tester);
      await services.profile.updateSettings((s) => s.copyWith(visualAlertEnabled: false));
      services.cook.goTo(4);
      await settle(tester);
      await tester.tap(find.text('START TIMER'));
      await settle(tester);
      await passTime(tester, services, 121);
      expect(find.byType(TimerFlashOverlay), findsNothing);
      expect(alerts.alerts, 1);
    });

    testWidgets('a muted device still flashes', (tester) async {
      final services = await open(tester);
      await services.profile.updateSettings((s) => s.copyWith(timerSoundEnabled: false));
      services.cook.goTo(4);
      await settle(tester);
      await tester.tap(find.text('START TIMER'));
      await settle(tester);
      await passTime(tester, services, 121);
      expect(find.byType(TimerFlashOverlay), findsOneWidget);
      expect(alerts.lastSound, isFalse);
    });

    testWidgets('with reduceMotion it does not flash: a still banner, and the screen stays usable', (tester) async {
      final services = await finishTimer(tester, profile: const Profile(name: 'Jo', reduceMotion: true));
      expect(find.byType(TimerFlashOverlay), findsOneWidget);
      expect(find.text('timer done: step 5'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(TimerFlashOverlay), matching: find.byType(AnimatedBuilder)),
        findsNothing,
        reason: 'nothing animates',
      );
      final before = tester.getTopLeft(find.byType(TimerFlashOverlay));
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.getTopLeft(find.byType(TimerFlashOverlay)), before);
      // Underneath, cook mode keeps working.
      await tester.tap(find.text('NEXT'));
      await settle(tester);
      expect(services.cook.stepIndex, 5);
    });

    testWidgets('the alert is announced to screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      await finishTimer(tester);
      expect(find.bySemanticsLabel(RegExp('timer done: step 5')), findsWidgets);
      semantics.dispose();
    });

    testWidgets('the flash goes away on its own after a while', (tester) async {
      await finishTimer(tester);
      expect(find.byType(TimerFlashOverlay), findsOneWidget);
      await tester.pump(const Duration(seconds: 13));
      expect(find.byType(TimerFlashOverlay), findsNothing);
    });
  });

  group('pause and resume', () {
    testWidgets('pausing freezes the timers, blocks "next" and shows a note', (tester) async {
      final services = await open(tester);
      services.cook.goTo(2);
      await settle(tester);
      await tester.tap(find.text('START TIMER'));
      await settle(tester);
      await passTime(tester, services, 20);
      await tester.tap(find.byTooltip('pause'));
      await settle(tester);
      expect(services.cook.paused, isTrue);
      expect(find.text('paused.'), findsOneWidget);
      await passTime(tester, services, 100);
      expect(services.cook.remainingSeconds(2), 280);
      await tester.tap(find.byTooltip('resume'));
      await settle(tester);
      expect(find.text('paused.'), findsNothing);
      await passTime(tester, services, 10);
      expect(services.cook.remainingSeconds(2), 270);
    });

    testWidgets('leaving keeps the place and coming back continues where it stopped', (tester) async {
      final services = await open(tester);
      await next(tester);
      await next(tester);
      await tester.tap(find.byTooltip('leave and keep my place'));
      await settle(tester, frames: 15);
      expect(services.cook.storedSession, isNotNull);
      expect(services.cook.storedSession!.stepIndex, 2);
      await tester.pumpWidget(const SizedBox());
      final again = await open(tester, existing: services, resume: true);
      expect(again.cook.stepIndex, 2);
      expect(find.text('3'), findsWidgets);
    });

    testWidgets('starting from the dish page asks whether to pick up the stored run', (tester) async {
      final services = await open(tester);
      await next(tester);
      await tester.tap(find.byTooltip('leave and keep my place'));
      await settle(tester, frames: 15);
      await tester.pumpWidget(const SizedBox());
      await pumpApp(
        tester,
        services,
        home: const DishScreen(dishId: 'pancakes', initialRecipeId: 'pancakes-classic'),
      );
      await pumpUntilFound(tester, find.text('START COOKING'));
      await tester.tap(find.text('START COOKING'));
      await settle(tester);
      expect(find.text('pick up where you left off?'), findsOneWidget);
      expect(find.text('you were on step 2.'), findsOneWidget);
      await tester.tap(find.text('continue'));
      await settle(tester, frames: 15);
      await pumpUntilFound(tester, find.byType(CookScreen));
      await settle(tester);
      expect(services.cook.stepIndex, 1);
    });
  });

  group('servings scaler', () {
    testWidgets('starts with the servings chosen on the dish page', (tester) async {
      final services = await open(tester, servings: 4);
      expect(services.cook.servings, 4);
      expect(find.text('4 people'), findsOneWidget);
    });

    testWidgets('the ingredients sheet scales amounts and the session remembers it', (tester) async {
      final services = await open(tester);
      await tester.tap(find.text('ingredients'));
      await settle(tester);
      expect(find.text('150 g'), findsOneWidget);
      await tester.tap(find.byTooltip('more servings'));
      await settle(tester);
      expect(services.cook.servings, 3);
      expect(find.text('225 g'), findsOneWidget);
      await tester.tap(find.byTooltip('fewer servings'));
      await tester.pump();
      await tester.tap(find.byTooltip('fewer servings'));
      await tester.pump();
      await tester.tap(find.byTooltip('fewer servings'));
      await settle(tester);
      expect(services.cook.servings, 1);
      expect(find.text('75 g'), findsOneWidget);
      await tester.tap(find.byTooltip('close'));
      await settle(tester);
      expect(find.text('1 person'), findsOneWidget);
    });
  });

  group('quick-tap to advance (one-handed)', () {
    testWidgets('is off by default: tapping the text does nothing', (tester) async {
      final services = await open(tester);
      await tester.tap(find.text('Whisk the flour, sugar, baking powder and salt in a large bowl.'));
      await settle(tester);
      expect(services.cook.stepIndex, 0);
      expect(haptics.taps, 0);
      expect(find.text('tap the text for the next step'), findsNothing);
    });

    testWidgets('when enabled a single tap advances with haptic feedback', (tester) async {
      final services = await open(tester);
      services.oneHanded.quickNextTapEnabled = true;
      await settle(tester);
      expect(find.text('tap the text for the next step'), findsOneWidget);
      await tester.tap(find.text('Whisk the flour, sugar, baking powder and salt in a large bowl.'));
      await settle(tester);
      expect(services.cook.stepIndex, 1);
      expect(haptics.taps, 1);
    });

    testWidgets('taps within 300 ms are ignored', (tester) async {
      final services = await open(tester);
      services.oneHanded.quickNextTapEnabled = true;
      await settle(tester);
      final text = find.text('Whisk the flour, sugar, baking powder and salt in a large bowl.');
      await tester.tap(text);
      await tester.pump(const Duration(milliseconds: 20));
      // The first page is still sliding out: an accidental second tap lands inside the debounce window.
      await tester.tap(text, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 20));
      expect(services.cook.stepIndex, 1);
      expect(haptics.taps, 1);
      now = now.add(const Duration(milliseconds: 400));
      await settle(tester);
      await tester.tap(find.text('In a second bowl whisk the buttermilk, egg and melted butter.'));
      await settle(tester);
      expect(services.cook.stepIndex, 2);
      expect(haptics.taps, 2);
    });

    testWidgets('with reduceMotion the step changes without a slide', (tester) async {
      final services = await open(tester, profile: const Profile(name: 'Jo', reduceMotion: true));
      services.oneHanded.quickNextTapEnabled = true;
      await settle(tester);
      await tester.tap(find.text('Whisk the flour, sugar, baking powder and salt in a large bowl.'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final pages = tester.widget<PageView>(find.byType(PageView)).controller!;
      expect(pages.page, 1.0, reason: 'jumped straight to the next page');
    });

    testWidgets('without reduceMotion the page slides', (tester) async {
      final services = await open(tester);
      services.oneHanded.quickNextTapEnabled = true;
      await settle(tester);
      await tester.tap(find.text('Whisk the flour, sugar, baking powder and salt in a large bowl.'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final pages = tester.widget<PageView>(find.byType(PageView)).controller!;
      expect(pages.page, allOf(greaterThan(0.0), lessThan(1.0)), reason: 'mid-slide');
      await settle(tester);
    });
  });

  group('completion', () {
    testWidgets('the last step leads to the completion screen', (tester) async {
      final services = await open(tester);
      services.cook.goTo(5);
      await settle(tester);
      await tester.tap(find.text('FINISH'));
      await settle(tester);
      expect(find.text('well done.'), findsOneWidget);
      expect(find.text('fluffy buttermilk pancakes'), findsOneWidget);
      expect(find.text('LOG THIS COOK'), findsOneWidget);
    });

    testWidgets('logging records the cook with the servings and clears the stored run', (tester) async {
      final services = await open(tester, servings: 3);
      services.cook.goTo(5);
      await settle(tester);
      await tester.tap(find.text('FINISH'));
      await settle(tester);
      await tester.tap(find.text('LOG THIS COOK'));
      await settle(tester);
      expect(find.text('saved to your history.'), findsOneWidget);
      expect(services.history.entries.single.recipeId, 'pancakes-classic');
      expect(services.history.entries.single.servings, 3);
      expect(services.history.entries.single.cookedAt, now);
      expect(services.cook.storedSession, isNull);
    });

    testWidgets('the recipe can be saved to the cookbook from the completion screen', (tester) async {
      final services = await open(tester);
      services.cook.goTo(5);
      await settle(tester);
      await tester.tap(find.text('FINISH'));
      await settle(tester);
      await tester.tap(find.text('SAVE TO COOKBOOK'));
      await settle(tester);
      expect(services.cookbook.isSaved('pancakes-classic'), isTrue);
      expect(find.text('in your cookbook'), findsOneWidget);
    });

    testWidgets('leaving without logging leaves no history entry', (tester) async {
      final services = await open(tester);
      services.cook.goTo(5);
      await settle(tester);
      await tester.tap(find.text('FINISH'));
      await settle(tester);
      await tester.tap(find.text('LEAVE WITHOUT LOGGING'));
      await settle(tester, frames: 15);
      expect(services.history.count, 0);
      expect(services.cook.storedSession, isNull);
    });
  });
}
