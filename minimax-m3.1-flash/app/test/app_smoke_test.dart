import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:morphcook/src/data/corpus.dart';
import 'package:morphcook/src/data/repositories.dart';
import 'package:morphcook/src/state/app_state.dart';
import 'package:morphcook/src/state/cookbook_controller.dart';
import 'package:morphcook/src/state/history_controller.dart';
import 'package:morphcook/src/state/local_store.dart';
import 'package:morphcook/src/state/meal_plan_controller.dart';
import 'package:morphcook/src/state/profile_controller.dart';
import 'package:morphcook/src/state/shopping_controller.dart';
import 'package:morphcook/src/ui/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A smoke test for the screens themselves.
///
/// The domain has its own tests; this one exists to prove that the design
/// system and the screens build and render without throwing — the kind of
/// thing a compile check cannot see.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Corpus corpus;
  late FaqRepository faqs;
  late IngredientGuideRepository guide;

  setUpAll(() async {
    // The app never fetches a typeface at runtime; the test must not either.
    GoogleFonts.config.allowRuntimeFetching = false;

    // Every asset is read here, in setUpAll. A second asset read inside a
    // test body never completes — the binding only flushes the asset
    // channel's completion once per test.
    corpus = await Corpus.load();
    await corpus.loadAll();
    faqs = await FaqRepository.load();
    guide = await IngredientGuideRepository.load();
  });

  /// Builds the real app state over an in-memory store.
  Future<AppState> buildState({
    Map<String, Object?> profile = const <String, Object?>{},
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'profile': jsonEncode(<String, Object?>{
        'name': 'Robin',
        'lang': 'en',
        'avoid_flags': <String>[],
        'avoid_ingredients': <String>[],
        'required_attributes': <String>[],
        'max_time_minutes': 60,
        'calorie_target': 600,
        'calorie_tolerance': 120,
        'preferred_effort': 'easy',
        'show_variant_tags': true,
        'reduce_motion': null,
        'visual_alert_enabled': true,
        'quick_next_tap_enabled': false,
        'onboarding_complete': false,
        'dishes_outside_calorie_target': <String>[],
        ...profile,
      }),
    });
    final prefs = await SharedPreferences.getInstance();
    final store = MemoryStore();
    return AppState(
      corpus: corpus,
      faqs: faqs,
      ingredientGuide: guide,
      profile: ProfileController(prefs),
      cookbook: CookbookController(store),
      mealPlan: MealPlanController(store),
      shopping: ShoppingController(store),
      history: HistoryController(store),
      store: store,
    );
  }

  /// The loading indicator breathes forever, so `pumpAndSettle` would never
  /// return. A fixed number of pumps is what a human sees instead.
  Future<void> pumpApp(WidgetTester tester, AppState state) async {
    await tester.pumpWidget(MorphCookApp(state: state));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('a new cook lands in the onboarding', (tester) async {
    final state = await buildState();

    await pumpApp(tester, state);

    expect(find.text('welcome to morphcook'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a finished cook lands in the home shell', (tester) async {
    final state = await buildState(
      profile: <String, Object?>{'onboarding_complete': true},
    );

    await pumpApp(tester, state);

    // The five bottom-navigation tabs.
    expect(find.text('home'), findsOneWidget);
    expect(find.text('cookbook'), findsOneWidget);
    expect(find.text('search'), findsOneWidget);
    expect(find.text('plan'), findsOneWidget);
    expect(find.text('list'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the home feed lists dishes from the corpus', (tester) async {
    final state = await buildState(
      profile: <String, Object?>{'onboarding_complete': true},
    );

    await pumpApp(tester, state);

    // The feed is made of real recipes out of the bundled corpus.
    final titles = corpus.allRecipes
        .map((recipe) => recipe.title.resolve('en'))
        .where((title) => title.isNotEmpty)
        .toSet();
    expect(titles, isNotEmpty);
    expect(
      titles.any((title) => find.text(title).evaluate().isNotEmpty),
      isTrue,
      reason: 'the feed should show at least one recipe from the corpus',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the language follows the profile', (tester) async {
    final state = await buildState(
      profile: <String, Object?>{
        'onboarding_complete': true,
        'lang': 'de',
      },
    );

    expect(state.profile.lang, 'de');
    expect(state.strings.lang, 'de');

    await pumpApp(tester, state);

    expect(find.text('start'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a cook who avoids everything still gets a home', (tester) async {
    final state = await buildState(
      profile: <String, Object?>{
        'onboarding_complete': true,
        'avoid_flags': <String>[
          'vegan',
          'gluten',
          'dairy',
          'nuts',
          'egg',
          'pork',
          'fish',
        ],
      },
    );

    await pumpApp(tester, state);

    expect(tester.takeException(), isNull);
    expect(find.byType(Scaffold), findsWidgets);
  });
}
