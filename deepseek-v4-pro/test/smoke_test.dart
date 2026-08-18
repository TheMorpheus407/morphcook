import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:morphcook/app.dart';
import 'package:morphcook/core/l10n.dart';
import 'package:morphcook/data/corpus.dart';
import 'package:morphcook/data/stores.dart';
import 'package:morphcook/models/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// End-to-end widget smoke test: real corpus assets, real stores,
/// onboarding → shell → dish detail → variant switching → tabs → settings.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Corpus corpus;
  late AppStore store;
  late LocaleController loc;

  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('morphcook_widget');
    Hive.init(dir.path);
    SharedPreferences.setMockInitialValues({});
    store = await AppStore.init();
    loc = LocaleController(await SharedPreferences.getInstance());
    corpus = await Corpus.load(bundle: rootBundle);
    // Preload the lazy partition: the screen fetchers await it, and real
    // asset IO cannot complete inside the widget-test fake-async zone.
    await corpus.loadPartition('extended');
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MorphCookApp(corpus: corpus, store: store, loc: loc),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Scrolls the primary CustomScrollView in precise steps until [text]
  /// is built (lazy slivers), then parks it in a comfortable tap zone.
  Future<void> scrollToText(WidgetTester tester, String text) async {
    final sv = find.byType(CustomScrollView).first;
    final position = tester
        .state<ScrollableState>(
            find.descendant(of: sv, matching: find.byType(Scrollable)).first)
        .position;
    for (var i = 0; i < 20; i++) {
      final f = find.text(text);
      if (f.evaluate().isNotEmpty) {
        await tester.ensureVisible(f.first);
        await settle(tester);
        final box = tester.renderObject<RenderBox>(f.first);
        final top = box.localToGlobal(Offset.zero).dy;
        if (top < 120) {
          position.jumpTo((position.pixels - 160).clamp(0, double.infinity));
          await settle(tester);
        }
        return;
      }
      position.jumpTo(position.pixels + 400);
      await settle(tester);
    }
  }

  Future<void> tapByText(WidgetTester tester, String text) async {
    final finder = find.text(text).first;
    await tester.ensureVisible(finder);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(finder, warnIfMissed: false);
    await settle(tester);
  }

  /// Taps the LAST match — used when the query text itself is also
  /// rendered inside a TextField.
  Future<void> tapByTextLast(WidgetTester tester, String text) async {
    final finder = find.text(text).last;
    await tester.ensureVisible(finder);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(finder, warnIfMissed: false);
    await settle(tester);
  }

  testWidgets('onboarding flow reaches the shell', (tester) async {
    await pumpApp(tester);

    // Step 1: language — pick English
    expect(find.text('morphcook'), findsWidgets);
    await tapByText(tester, 'English');
    await tapByText(tester, 'next');

    // Step 2: name
    await tester.enterText(find.byType(TextField).first, 'Ada');
    await tester.pump(const Duration(milliseconds: 200));
    await tapByText(tester, 'next');

    // Step 3: diet & allergies — pick vegan + avoid cilantro
    await tapByText(tester, 'vegan');
    await tester.enterText(find.byType(TextField).first, 'cilantro');
    await tester.pump(const Duration(milliseconds: 300));
    await tapByTextLast(tester, 'cilantro');
    await tapByText(tester, 'next');

    // Step 4: budgets
    await tapByText(tester, 'next');

    // Step 5: confirm
    await tapByText(tester, 'open my cookbook');
    await settle(tester);

    expect(find.text('good appetite, Ada'), findsOneWidget);
    expect(store.profile.onboarded, isTrue);
    expect(store.profile.avoidFlags, contains('dairy'));
    expect(store.profile.avoidIngredients, contains('produce.cilantro'));
  });

  testWidgets('home feed renders featured dish and sections', (tester) async {
    store.updateProfile(const Profile(name: 'Ada', onboarded: true));
    await pumpApp(tester);

    expect(find.text('good appetite, Ada'), findsOneWidget);
    expect(find.text('for you right now'), findsOneWidget);
    // featured dish rendered
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('featured dish'.toUpperCase()), findsWidgets);

    // lazily-built sections below the fold
    await scrollToText(tester, 'quick & easy');
    expect(find.text('quick & easy'), findsOneWidget);
    await scrollToText(tester, 'for the weekend');
    expect(find.text('for the weekend'), findsOneWidget);
  });

  testWidgets('dish detail switches variants with morph animation',
      (tester) async {
    store.updateProfile(const Profile(name: 'Ada', onboarded: true));
    await pumpApp(tester);

    // open the doener dish via featured / search tab
    await tester.tap(find.text('search').last);
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'döner');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byIcon(Icons.arrow_forward).first);
    await settle(tester);

    // open the classic doener card
    await tester.tap(find.text('Classic Döner').first, warnIfMissed: false);
    await settle(tester);

    await scrollToText(tester, 'diet');
    expect(find.text('diet'), findsOneWidget);

    // expand diet dimension and switch to vegan while the chips
    // are still on screen
    await tester.tap(find.text('diet'));
    await settle(tester);
    await scrollToText(tester, 'classic');
    expect(find.text('classic'), findsWidgets);
    await scrollToText(tester, 'vegan');
    await tester.tap(find.text('vegan').first, warnIfMissed: false);
    await settle(tester);

    await scrollToText(tester, 'effort');
    expect(find.text('effort'), findsOneWidget);
    await scrollToText(tester, 'calorie level');
    expect(find.text('calorie level'), findsOneWidget);
    await scrollToText(tester, 'ingredients');
    expect(find.text('ingredients'), findsOneWidget);
    expect(find.text('method'), findsOneWidget);
    expect(find.text('macros'), findsOneWidget);

    // save to cookbook
    await tester.tap(find.byIcon(Icons.favorite_border).first,
        warnIfMissed: false);
    await settle(tester);
    expect(store.isSaved('doener.vegan'), isTrue);
  });

  testWidgets('cookbook, planner, shopping and settings render',
      (tester) async {
    store.updateProfile(const Profile(name: 'Ada', onboarded: true));
    store.saveRecipe('doener.vegan');
    store.addShoppingEntries(const []);
    await pumpApp(tester);

    // cookbook tab
    await tester.tap(find.text('cookbook').last);
    await settle(tester);
    expect(find.text('Vegan Döner'), findsOneWidget);

    // planner tab
    await tester.tap(find.text('planner').last);
    await settle(tester);
    expect(find.text('meal planner'), findsOneWidget);

    // assign a recipe to a slot
    await tester.tap(find.text('+').first);
    await settle(tester);
    await tester.tap(find.text('Vegan Döner').first, warnIfMissed: false);
    await settle(tester);
    expect(store.plannedRecipe(IsoWeekNow.week, 'mon.breakfast'),
        'doener.vegan');

    // shopping tab
    await tester.tap(find.text('shopping').last);
    await settle(tester);
    expect(find.text('shopping list'), findsOneWidget);

    // settings (icon lives on the home tab masthead)
    await tester.tap(find.text('home').last);
    await settle(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined).first,
        warnIfMissed: false);
    await settle(tester);
    expect(find.text('settings'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await settle(tester);
    expect(find.text('help center'), findsWidgets);
    expect(find.text('backup & restore'), findsWidgets);
  });

  testWidgets('cook mode runs through steps and completes', (tester) async {
    store.updateProfile(const Profile(
        name: 'Ada', onboarded: true, calorieTarget: 350, calorieTolerance: 150));
    await pumpApp(tester);

    await tester.tap(find.text('search').last);
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'hummus');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byIcon(Icons.arrow_forward).first);
    await settle(tester);
    await tester.tap(find.text('Classic Hummus').first, warnIfMissed: false);
    await settle(tester);

    await tester.tap(find.text('cook this').first, warnIfMissed: false);
    await settle(tester);

    // cook mode: step 1 of N
    expect(find.textContaining('of 3'), findsOneWidget);

    // servings scaler
    await tester.tap(find.byIcon(Icons.add).first);
    await settle(tester);

    // advance through steps (the last button reads 'done')
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('next').last, warnIfMissed: false);
      await settle(tester);
    }
    await tester.tap(find.text('done').last, warnIfMissed: false);
    await settle(tester);
    expect(find.text('plated & proud'), findsOneWidget);

    // history recorded (bestVariant picks the hummus closest to target)
    expect(store.lastCookedAt.keys.any((k) => k.startsWith('hummus.')), isTrue);
  });

  testWidgets('language toggle switches the whole app to german',
      (tester) async {
    store.updateProfile(const Profile(name: 'Ada', onboarded: true));
    await pumpApp(tester);

    await tester.tap(find.text('home').last);
    await settle(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined).first,
        warnIfMissed: false);
    await settle(tester);
    await tester.tap(find.text('deutsch').first, warnIfMissed: false);
    await settle(tester);

    expect(loc.lang, 'de');
    expect(find.text('einstellungen'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -800));
    await settle(tester);
    expect(find.text('hilfe-center'), findsWidgets);
  });
}

/// helper to avoid importing the model in the test
class IsoWeekNow {
  static String get week {
    final now = DateTime.now();
    final monday = DateTime.utc(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final thursday = monday.add(const Duration(days: 3));
    final jan1 = DateTime.utc(thursday.year, 1, 1);
    final doy = thursday.difference(jan1).inDays + 1;
    final w = ((doy + 6) ~/ 7);
    return '${thursday.year}-W${w.toString().padLeft(2, '0')}';
  }
}
