import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:morphcook/data/app_state.dart';
import 'package:morphcook/data/corpus.dart';
import 'package:morphcook/main.dart';
import 'package:morphcook/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A tiny stand-in corpus so the app can boot without assets.
Corpus _corpus() {
  final corpus = Corpus();
  corpus.ontology = Ontology(
    containsFlags: const ['gluten', 'dairy', 'nuts'],
    compoundAvoids: const {},
    attributes: const {},
    dietOrder: const ['classic', 'veggie', 'vegan'],
  );
  corpus.ingredientRoots.add(IngredientNode(
    id: 'produce',
    label: const {'en': 'produce', 'de': 'obst & gemüse'},
    children: [
      IngredientNode(
          id: 'garlic',
          label: const {'en': 'garlic', 'de': 'knoblauch'},
          children: const [],
          parentId: 'produce',
          rootId: 'produce'),
    ],
  ));
  corpus.ingredientsById['produce'] = corpus.ingredientRoots.first;
  corpus.ingredientsById['garlic'] =
      corpus.ingredientRoots.first.children.first;

  final dish = Dish(
    id: 'd1',
    canonicalName: const {'en': 'Zucchini fritters', 'de': 'Zucchinipuffer'},
    heroText: const {'en': 'Crispy, golden, gone.'},
    capCaption: const {'en': 'midweek hero'},
    stripeColor: const Color(0xFFc9703e),
    variantIds: const ['r1'],
    partitionId: 'core',
    secondaryPartitions: const [],
    cuisineTags: const [],
  );
  final recipe = Recipe(
    id: 'r1',
    dishId: 'd1',
    title: const {'en': 'Classic zucchini fritters', 'de': 'Zucchinipuffer'},
    summary: const {'en': 'Simple and quick'},
    diet: 'classic',
    contains: const {},
    attributes: const [],
    timeMinutes: 20,
    calories: 300,
    protein: 5,
    carbs: 20,
    fat: 10,
    servings: 2,
    mealTypes: const ['dinner'],
    tags: const ['summer'],
    ingredients: [
      IngredientRef(id: 'garlic', amount: 2, unit: 'clove'),
    ],
    steps: [
      StepData(text: const {'en': 'Grate the zucchini.'}, timerSeconds: 0),
      StepData(text: const {'en': 'Fry until golden.'}, timerSeconds: 300),
    ],
  );
  corpus.dishesById['d1'] = dish;
  corpus.recipesById['r1'] = recipe;
  corpus.recipesInPartition['core'] = [recipe];
  corpus.allTags.add('summer');
  corpus.ready = true;
  return corpus;
}

void main() {
  late AppState state;
  late List<Box> boxes;

  // All async storage setup runs OUTSIDE the FakeAsync widget-test zone,
  // otherwise Hive's real IO deadlocks.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final dir = await Directory.systemTemp.createTemp('morphcook_widget');
    Hive.init(dir.path);
    boxes = [
      await Hive.openBox('cookbook'),
      await Hive.openBox('history'),
      await Hive.openBox('meal_plan'),
      await Hive.openBox('shopping'),
      await Hive.openBox('shopping_checked'),
      await Hive.openBox('events'),
    ];
    state = AppState.instance;
    await state.init(
      prefs: prefs,
      cookbookBox: Hive.box('cookbook'),
      historyBox: Hive.box('history'),
      mealPlanBox: Hive.box('meal_plan'),
      shoppingBox: Hive.box('shopping'),
      checkedBox: Hive.box('shopping_checked'),
      eventsBox: Hive.box('events'),
    );
  });

  setUp(() async {
    for (final b in boxes) {
      await b.clear();
    }
    state.patchProfile((p) {
      p
        ..name = ''
        ..lang = 'en'
        ..avoidFlags.clear()
        ..avoidIngredients.clear()
        ..requiredAttributes.clear()
        ..completedOnboarding = false;
    });
  });

  testWidgets('onboarding flow completes and reveals the app shell',
      (WidgetTester tester) async {
    await tester.pumpWidget(MorphCookApp(state: state, corpus: _corpus()));
    await tester.pump(const Duration(milliseconds: 300));

    // fresh profile lands on onboarding, not the shell
    expect(state.profile.completedOnboarding, isFalse);
    expect(find.byType(NavigationBar), findsNothing);

    // page 0 asks for a name; without one Next stays disabled
    await tester.enterText(find.byType(TextField).first, 'Ada');
    await tester.pump(const Duration(milliseconds: 100));

    // pages 0-3 advance with "next"; page 4 confirms with "confirm"
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('next'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.tap(find.text('everything in order?').last);
    await tester.pump(const Duration(milliseconds: 400));

    // the app shell should now be visible
    expect(state.profile.completedOnboarding, isTrue);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('completed onboarding boots straight into the shell',
      (WidgetTester tester) async {
    state.patchProfile((p) => p.completedOnboarding = true);
    await tester.pumpWidget(MorphCookApp(state: state, corpus: _corpus()));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(NavigationBar), findsOneWidget);
    // five tabs: home, cookbook, calendar, shopping, settings
    expect(find.byType(NavigationDestination), findsNWidgets(5));
  });
}
