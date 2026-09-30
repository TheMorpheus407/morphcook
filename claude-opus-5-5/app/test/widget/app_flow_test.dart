import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:morphcook/app.dart';
import 'package:morphcook/data/corpus_repository.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/state/kv_store.dart';
import 'package:morphcook/state/library_store.dart';
import 'package:morphcook/state/profile_controller.dart';
import 'package:morphcook/ui/screens/cook_mode_screen.dart';
import 'package:morphcook/ui/screens/dish_detail_screen.dart';

class Harness {
  Harness({Profile? profile}) {
    if (profile != null) prefs.data['profile'] = jsonEncode(profile.toJson());
    this.profile = ProfileController(prefs, deviceLang: 'en');
    library = LibraryStore(hive, clock: () => DateTime(2026, 9, 22, 18, 30));
  }

  final prefs = MemoryKvStore();
  final hive = MemoryKvStore();
  final repo = CorpusRepository();
  late final ProfileController profile;
  late final LibraryStore library;

  Widget app() => MorphCookApp(repo: repo, profile: profile, library: library);
}

Future<void> boot(WidgetTester tester, Harness h) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(h.app());
  // corpus loads from the real asset bundle
  await tester.runAsync(() => h.repo.isReady ? Future.value() : Future<void>.delayed(const Duration(milliseconds: 50)));
  for (var i = 0; i < 20 && !h.repo.isReady; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
  await tester.runAsync(h.repo.prefetchRemaining);
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('onboarding walks through five steps and lands on the home feed', (tester) async {
    final h = Harness();
    await boot(tester, h);
    expect(find.text('hello & welcome'), findsOneWidget);

    // step 1: language → deutsch switches the UI live
    await tester.tap(find.byKey(const Key('lang-de')));
    await tester.pump();
    expect(find.text('hallo & willkommen'), findsOneWidget);
    await tester.tap(find.byKey(const Key('lang-en')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('ob-next')));
    await tester.pumpAndSettle();
    // step 2: name
    await tester.enterText(find.byKey(const Key('ob-name')), 'Ada');
    await tester.tap(find.byKey(const Key('ob-next')));
    await tester.pumpAndSettle();
    // step 3: diet & allergies
    expect(find.text('how do you eat?'), findsOneWidget);
    await tester.tap(find.text('vegan').first);
    await tester.pump();
    await tester.enterText(find.byKey(const Key('avoid-search')), 'cilan');
    await tester.pump();
    await tester.ensureVisible(find.text('cilantro').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('cilantro').first);
    await tester.pump();
    expect(h.profile.profile.avoidIngredients, {'cilantro'});
    await tester.tap(find.byKey(const Key('ob-next')));
    await tester.pumpAndSettle();
    // step 4: calories & time
    await tester.ensureVisible(find.text('45 min'));
    await tester.tap(find.text('45 min'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ob-next')));
    await tester.pumpAndSettle();
    // step 5: confirm
    expect(find.text('your kitchen, Ada'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ob-start')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    final p = h.profile.profile;
    expect(p.onboarded, isTrue);
    expect(p.name, 'Ada');
    expect(p.avoidFlags, {'vegan'});
    expect(p.maxTimeMinutes, 45);
    expect(find.textContaining('MorphCook', findRichText: true), findsWidgets);
    expect(find.text('today’s feature'), findsOneWidget);
    // a vegan never sees the classic döner in the feed
    expect(find.text('classic döner'), findsNothing);
  });

  testWidgets('dish detail: variant rows switch the recipe in place', (tester) async {
    final h = Harness(profile: const Profile(onboarded: true, name: 'Ada'));
    await boot(tester, h);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => const DishDetailScreen(dishId: 'doener', initialRecipeId: 'doener-classic'),
      ),
    );
    await tester.runAsync(() => h.repo.ensureDish('doener'));
    await tester.pumpAndSettle();

    expect(find.text('classic döner'), findsWidgets);
    // collapsed by default: chips hidden
    expect(find.byKey(const Key('opt-diet-vegan')), findsNothing);
    await tester.tap(find.byKey(const Key('dim-diet')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('opt-diet-vegan')), findsOneWidget);
    await tester.tap(find.byKey(const Key('opt-diet-vegan')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('vegan döner'), findsWidgets);

    // effort row: no vegan × easy version yet → disabled with a note
    await tester.tap(find.byKey(const Key('dim-effort')));
    await tester.pumpAndSettle();
    expect(find.textContaining('no vegan × easy version yet'), findsOneWidget);

    // save the specific variant
    await tester.tap(find.byKey(const Key('save-toggle')));
    await tester.pump();
    expect(h.library.isSaved('doener-vegan'), isTrue);

    // add to shopping list
    await tester.ensureVisible(find.byKey(const Key('list-btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('list-btn')));
    await tester.pump();
    expect(h.library.shoppingSources.single.recipeId, 'doener-vegan');

    // tabs
    await tester.ensureVisible(find.byKey(const Key('tab-method')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-method')));
    await tester.pumpAndSettle();
    expect(find.text('1.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tab-macros')));
    await tester.pumpAndSettle();
    expect(find.text('610'), findsOneWidget);
  });

  testWidgets('cook mode: steps, timer, quick tap, completion', (tester) async {
    final h = Harness(profile: const Profile(onboarded: true, quickNextTapEnabled: true, reduceMotion: true));
    await boot(tester, h);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute<void>(builder: (_) => const CookModeScreen(recipeId: 'pad-thai-weeknight')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('step 1 / 4'), findsOneWidget);
    expect(find.byKey(const Key('timer-start')), findsOneWidget);

    await tester.tap(find.byKey(const Key('timer-start')));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('07:58'), findsOneWidget);
    await tester.tap(find.byKey(const Key('timer-pause')));
    await tester.pump();

    // servings scaler
    await tester.tap(find.byKey(const Key('cook-servings-plus')));
    await tester.pump();
    expect(find.text('5'), findsOneWidget);

    // quick tap advances one step, debounced
    await tester.tap(find.byKey(const Key('step-content')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('step-content')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('step 2 / 4'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cook-next')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('cook-next')));
    await tester.pump();
    expect(find.text('step 4 / 4'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cook-next')));
    await tester.pump();
    await tester.pump();
    expect(find.text('& that’s that.'), findsOneWidget);
    expect(h.library.history.single.recipeId, 'pad-thai-weeknight');
    expect(h.library.history.single.servings, 5);
  });

  testWidgets('cook mode timer completion flashes when visual alerts are on', (tester) async {
    final h = Harness(profile: const Profile(onboarded: true, reduceMotion: false, visualAlertEnabled: true));
    await boot(tester, h);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute<void>(builder: (_) => const CookModeScreen(recipeId: 'shakshuka-low-fodmap')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('timer-start')));
    for (var i = 0; i < 421; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.byKey(const Key('visual-alert-flash')), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.byKey(const Key('visual-alert-flash')), findsNothing);
    await tester.tap(find.byKey(const Key('cook-pause')));
    await tester.pumpAndSettle();
    expect(h.library.progressFor('shakshuka-low-fodmap'), isNotNull);
  });

  testWidgets('bottom tabs: search, cookbook, plan, list render', (tester) async {
    final h = Harness(profile: const Profile(onboarded: true));
    await boot(tester, h);

    await tester.tap(find.byKey(const Key('tab-1')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byKey(const Key('search-field')), 'lentil');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('lentil & mushroom bolognese'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('search-field')), 'sushi');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('nothing on this shelf'), findsOneWidget);
    expect(h.library.contentRequests, contains('sushi'));

    await tester.tap(find.byKey(const Key('tab-2')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('your cookbook'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-3')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('the week ahead'), findsOneWidget);
    expect(find.text('this week'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-4')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('the list is blank'), findsOneWidget);
  });

  testWidgets('settings: language toggle switches everything to German', (tester) async {
    final h = Harness(profile: const Profile(onboarded: true));
    await boot(tester, h);
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    expect(find.text('settings'), findsOneWidget);
    expect(find.textContaining('We never claim halal or kosher certification'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings-lang-de')));
    await tester.pumpAndSettle();
    expect(find.text('einstellungen'), findsOneWidget);
    expect(h.profile.lang, 'de');
  });
}
