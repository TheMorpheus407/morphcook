import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/app_state.dart';
import 'package:morphcook/data/store.dart';
import 'package:morphcook/main.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/ui/screens/dish_detail_screen.dart';
import 'package:morphcook/ui/screens/home_screen.dart';
import 'package:morphcook/ui/screens/onboarding_screen.dart';
import 'package:morphcook/ui/screens/settings_screen.dart';
import 'package:morphcook/ui/strings.dart';
import 'package:morphcook/ui/theme.dart';
import 'package:morphcook/ui/widgets/decor.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

Future<AppState> onboardedState() async {
  final corpus = await loadRealCorpus();
  final state = AppState(store: MemoryStore(), corpus: corpus);
  await state.load();
  await state.completeOnboarding(
      const Profile(name: 'cedric', lang: 'en'));
  return state;
}

Widget app(AppState state, Widget child) => ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(theme: morphTheme(), home: child),
    );

void main() {
  testWidgets('home masthead renders and dish cards open the detail page',
      (tester) async {
    // Corpus loading does real file I/O, which never completes inside the
    // FakeAsync zone — run it on the real event loop.
    final state = (await tester.runAsync(onboardedState))!;
    await tester.pumpWidget(app(state, const RootShell()));
    await tester.pumpAndSettle();

    expect(find.text('morphcook'), findsOneWidget);
    expect(find.text('edition for cedric'), findsOneWidget);

    // The grid sits below the fold in the test viewport — scroll to it,
    // then tap a card to open the dish detail.
    final homeScrollable = find
        .descendant(
            of: find.byType(HomeScreen), matching: find.byType(Scrollable))
        .first;
    await tester.drag(homeScrollable, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.byType(PolaroidCard), findsWidgets);
    await tester.tap(find.byType(PolaroidCard).first);
    await tester.pumpAndSettle();
    expect(find.byType(DishDetailScreen), findsOneWidget);
  });

  testWidgets('dish detail shows dimension rows and switches variants',
      (tester) async {
    final state = (await tester.runAsync(onboardedState))!;
    // Titles come from the live corpus — the lattice regenerates, the
    // test shouldn't pin prose.
    final veganTitles = (await tester.runAsync(() async {
      final dish = state.corpus.dishById('doener')!;
      final variants = await state.corpus.variantsOf(dish);
      return variants
          .where((r) => r.variant.diet == 'vegan')
          .map((r) => r.title.of('en').toLowerCase())
          .toList();
    }))!;
    expect(veganTitles, isNotEmpty);

    await tester
        .pumpWidget(app(state, const DishDetailScreen(dishId: 'doener')));
    await tester.pumpAndSettle();

    expect(find.textContaining('— diet'), findsOneWidget);
    expect(find.textContaining('— effort'), findsOneWidget);
    expect(find.textContaining('— calorie'), findsOneWidget);

    // Expand the diet row and pick vegan.
    await tester.tap(find.textContaining('— diet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vegan').first);
    await tester.pumpAndSettle();
    final shown = veganTitles
        .where((t) => find.text(t).evaluate().isNotEmpty)
        .toList();
    expect(shown, isNotEmpty,
        reason: 'no vegan döner title visible after switching; '
            'expected one of $veganTitles');
    // Let the ingredient highlight-flash reset timer fire before teardown.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('onboarding completes into the shell', (tester) async {
    final state = (await tester.runAsync(() async {
      final corpus = await loadRealCorpus();
      final s = AppState(store: MemoryStore(), corpus: corpus);
      await s.load();
      return s;
    }))!;
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        theme: morphTheme(),
        home: Builder(
          builder: (context) => state.onboarded
              ? const RootShell()
              : const OnboardingScreen(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);

    // language -> name -> diet -> targets -> confirm
    for (var i = 0; i < 4; i++) {
      await tester.ensureVisible(find.text('next'));
      await tester.tap(find.text('next'));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('open my cookbook'));
    await tester.tap(find.text('open my cookbook'));
    await tester.pumpAndSettle();
    expect(state.onboarded, isTrue);
  });

  testWidgets('settings renders the about & support section', (tester) async {
    final state = (await tester.runAsync(onboardedState))!;
    await tester.pumpWidget(app(state, const RootShell()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('settings'));
    await tester.pumpAndSettle();

    const en = S('en');
    final settingsScrollable = find
        .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.text(en('supportBody')), 300,
        scrollable: settingsScrollable);

    expect(find.text(en('supportBody')), findsOneWidget);
    expect(find.text(en('supportMadeBy')), findsWidgets);
    expect(find.text(en('supportPatreon')), findsOneWidget);
    expect(find.text(en('supportWebsite')), findsOneWidget);
    // The logo asset is wired up (no URL is launched in this test).
    expect(
      find.byWidgetPredicate((w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == 'assets/mo-logo.png'),
      findsOneWidget,
    );
  });

  test('support copy exists in english and german', () {
    const en = S('en');
    const de = S('de');
    for (final key in [
      'aboutSupport', 'supportMadeBy', 'supportBody',
      'supportPatreon', 'supportWebsite'
    ]) {
      expect(en(key), isNot(equals(key)), reason: 'missing EN $key');
      expect(de(key), isNot(equals(key)), reason: 'missing DE $key');
    }
    // Genuinely translated, not the EN fallback.
    expect(de('supportBody'), isNot(equals(en('supportBody'))));
    expect(de('supportBody'), contains('unterstützen'));
    expect(de('supportPatreon'), isNot(equals(en('supportPatreon'))));
  });

  testWidgets('cookbook shows a saved variant', (tester) async {
    final state = (await tester.runAsync(onboardedState))!;
    final savedTitle = (await tester.runAsync(() async {
      final recipe = await state.corpus.recipeById('doener-vegan');
      return recipe!.title.of('en').toLowerCase();
    }))!;
    await state.toggleSaved('doener-vegan');
    await tester.pumpWidget(app(state, const RootShell()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('cookbook'));
    await tester.pumpAndSettle();
    expect(find.text(savedTitle), findsOneWidget);
  });
}
