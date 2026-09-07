// Screenshot renders of the main screens with the real bundled fonts.
// Run with --update-goldens to regenerate; they are visual references.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/app.dart';
import 'package:morphcook/data/models/history_entry.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/state/app_controller.dart';
import 'package:morphcook/ui/cook/cook_mode_screen.dart';
import 'package:morphcook/ui/dish/dish_screen.dart';
import 'package:morphcook/ui/help/faq_screen.dart';
import 'package:morphcook/ui/insights/insights_screen.dart';
import 'package:morphcook/ui/onboarding/onboarding_flow.dart';
import 'package:morphcook/ui/settings/backup_screen.dart';
import 'package:morphcook/ui/settings/profile_editor_screen.dart';
import 'package:morphcook/ui/settings/settings_screen.dart';
import 'package:morphcook/ui/shell/app_shell.dart';

import 'helpers.dart';

Future<void> loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(rootBundle.load('assets/fonts/$f'));
    }
    await loader.load();
  }

  // Material icons ship inside the test asset bundle; without them icons draw as boxes.
  try {
    final icons = FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  } catch (_) {}
  await load('Playfair Display', ['PlayfairDisplay.ttf', 'PlayfairDisplay-Italic.ttf']);
  await load('JetBrains Mono', ['JetBrainsMono.ttf', 'JetBrainsMono-Italic.ttf']);
  await load('Caveat', ['Caveat.ttf']);
}

void main() {
  final clock = DateTime(2026, 9, 1, 19, 12);
  late AppController app;

  setUpAll(() async {
    await loadFonts();
  });

  Future<void> pumpApp(WidgetTester tester, {Widget? home, bool german = false}) async {
    tester.view.physicalSize = const Size(780, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    app = (await tester.runAsync(() async {
      final a = await newController(
        clock: () => clock,
        profile: Profile(name: 'cedric', lang: german ? 'de' : 'en', avoidFlags: const {'vegetarian'}, calorieTarget: 650, calorieTolerance: 200, onboardingComplete: true),
        loadAll: true,
      );
      await a.toggleSaved('doener-vegetarian-medium');
      await a.toggleSaved('alfredo-vegan-easy');
      await a.addHistory(HistoryEntry(recipeId: 'risotto-classic-medium', dishId: 'risotto', cookedAt: clock.subtract(const Duration(days: 40)), servings: 2));
      await a.addToShopping(a.recipeIfLoaded('doener-vegetarian-medium')!);
      await a.addToShopping(a.recipeIfLoaded('alfredo-vegan-easy')!);
      await a.assignMeal(a.currentWeekKey, 'mon.dinner', 'doener-vegetarian-medium');
      await a.assignMeal(a.currentWeekKey, 'wed.lunch', 'alfredo-vegan-easy');
      await a.assignMeal(a.currentWeekKey, 'sat.breakfast', 'pancakes-classic-easy');
      return a;
    }))!;
    await tester.pumpWidget(MorphCookApp(controller: app));
    await tester.pump(const Duration(milliseconds: 500));
    if (home != null) {
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.push(MaterialPageRoute(builder: (_) => home));
      await tester.pump(const Duration(milliseconds: 600));
    }
  }

  Future<void> shot(WidgetTester tester, String name) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
  }

  testWidgets('home', (tester) async {
    await pumpApp(tester);
    await shot(tester, 'home');
    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -900));
    await shot(tester, 'home-scrolled');
  });

  testWidgets('home in german', (tester) async {
    await pumpApp(tester, german: true);
    await shot(tester, 'home-de');
  });

  testWidgets('dish page and variant switcher', (tester) async {
    await pumpApp(tester, home: const DishScreen(dishId: 'doener'));
    await shot(tester, 'dish');
    await tester.tap(find.text('— diet'));
    await tester.pump(const Duration(milliseconds: 400));
    await shot(tester, 'dish-diet-open');
    await tester.tap(find.text('vegan').last);
    await tester.pump(const Duration(milliseconds: 700));
    await shot(tester, 'dish-vegan');
    // The tabs sit below the fold; scroll them into view before tapping.
    await tester.drag(find.byType(CustomScrollView).last, const Offset(0, -900));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('method'));
    await tester.pump(const Duration(milliseconds: 400));
    await shot(tester, 'dish-method');
  });

  testWidgets('cook mode', (tester) async {
    await pumpApp(tester);
    final r = app.recipeIfLoaded('doener-vegetarian-medium')!;
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute(builder: (_) => CookModeScreen(recipe: r)));
    await tester.pump(const Duration(milliseconds: 600));
    await shot(tester, 'cook');
    await tester.tap(find.text('next'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('start timer'));
    await tester.pump(const Duration(milliseconds: 400));
    await shot(tester, 'cook-timer');
    // Leave cook mode so the periodic ticker is disposed, and let the pop
    // transition finish before the test ends.
    nav.pop();
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  });

  testWidgets('tabs', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField).first, 'pasta');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    await shot(tester, 'search');
    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pump(const Duration(milliseconds: 600));
    await shot(tester, 'cookbook');
    await tester.tap(find.byIcon(Icons.calendar_view_week_outlined));
    await tester.pump(const Duration(milliseconds: 600));
    await shot(tester, 'plan');
    await tester.tap(find.byIcon(Icons.shopping_basket_outlined));
    await tester.pump(const Duration(milliseconds: 600));
    await shot(tester, 'shopping');
  });

  testWidgets('settings cluster', (tester) async {
    await pumpApp(tester, home: const SettingsScreen());
    await shot(tester, 'settings');
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute(builder: (_) => const ProfileEditorScreen()));
    await tester.pump(const Duration(milliseconds: 600));
    await shot(tester, 'profile');
    nav.push(MaterialPageRoute(builder: (_) => const BackupScreen()));
    await tester.pump(const Duration(milliseconds: 600));
    await shot(tester, 'backup');
    nav.push(MaterialPageRoute(builder: (_) => const FaqScreen(initialId: 'why-dish-missing')));
    await tester.pump(const Duration(milliseconds: 800));
    await shot(tester, 'faq');
    nav.push(MaterialPageRoute(builder: (_) => const InsightsScreen()));
    await tester.pump(const Duration(milliseconds: 600));
    await shot(tester, 'insights');
  });

  testWidgets('onboarding', (tester) async {
    tester.view.physicalSize = const Size(780, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final fresh = (await tester.runAsync(() => newController(clock: () => clock, loadAll: true)))!;
    await tester.pumpWidget(MorphCookApp(controller: fresh));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(OnboardingFlow), findsOneWidget);
    await shot(tester, 'onboarding-1');
    await tester.tap(find.text('next'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('next'));
    await tester.pump(const Duration(milliseconds: 500));
    await shot(tester, 'onboarding-3');
    expect(find.byType(AppShell), findsNothing);
    expect(app, isNotNull);
  });
}
