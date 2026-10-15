import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/main.dart';
import 'package:morphcook/models/dish.dart';
import 'package:morphcook/models/faq.dart';
import 'package:morphcook/models/ingredient_dictionary.dart';
import 'package:morphcook/models/ingredient_guide.dart';
import 'package:morphcook/models/ontology.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/recipe.dart';
import 'package:morphcook/services/corpus_repository.dart';
import 'package:morphcook/state/app_state.dart';

MorphCookAppState _createTestAppState({UserProfile? profile}) {
  final assetPrefix =
      Directory('assets').existsSync() ? 'assets' : 'app/assets';
  final ontology = Ontology.fromJson(
    jsonDecode(File('$assetPrefix/ontology.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final ingredients = IngredientDictionary.fromJson(
    jsonDecode(File('$assetPrefix/ingredients.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final guide = IngredientGuide.fromJson(
    jsonDecode(File('$assetPrefix/ingredient-guide.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final faqs = FaqCatalog.fromJson(
    jsonDecode(File('$assetPrefix/faqs.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final dishesJson =
      jsonDecode(File('$assetPrefix/dishes.json').readAsStringSync())
          as Map<String, dynamic>;
  final dishes = (dishesJson['dishes'] as List<dynamic>)
      .map((e) => Dish.fromJson(e as Map<String, dynamic>))
      .toList();
  final recipesJson =
      jsonDecode(File('$assetPrefix/recipes.json').readAsStringSync())
          as Map<String, dynamic>;
  final recipes = (recipesJson['recipes'] as List<dynamic>)
      .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
      .toList();

  final corpus = CorpusRepository()
    ..initializeInMemory(
      ontology: ontology,
      ingredients: ingredients,
      ingredientGuide: guide,
      faqs: faqs,
      dishes: dishes,
      recipes: recipes,
    );

  final state = MorphCookAppState(
    corpus: corpus,
    clock: () => DateTime(2026, 10, 14, 18, 30),
  );
  state.initializeForTesting(initialProfile: profile);
  return state;
}

void main() {
  testWidgets('Completes 5-step Onboarding flow into Home feed', (tester) async {
    final appState = _createTestAppState(
      profile: const UserProfile(onboardingCompleted: false),
    );

    await tester.pumpWidget(MorphCookApp(appState: appState));
    await tester.pumpAndSettle();

    // Step 1: Language
    expect(find.textContaining('Which language'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding_next_btn')));
    await tester.pumpAndSettle();

    // Step 2: Name
    await tester.enterText(
      find.byKey(const ValueKey('onboarding_name_input')),
      'Clara',
    );
    await tester.tap(find.byKey(const ValueKey('onboarding_next_btn')));
    await tester.pumpAndSettle();

    // Step 3: Diet & Allergies
    await tester.tap(find.byKey(const ValueKey('diet_preset_vegan')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding_next_btn')));
    await tester.pumpAndSettle();

    // Step 4: Calorie Target + Time Budget
    await tester.tap(find.byKey(const ValueKey('onboarding_next_btn')));
    await tester.pumpAndSettle();

    // Step 5: Confirm
    expect(find.textContaining('clara'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('onboarding_next_btn')));
    await tester.pumpAndSettle();

    // Now on Home Screen with newspaper masthead
    expect(find.text('morphcook'), findsOneWidget);
    expect(appState.profile.onboardingCompleted, isTrue);
    expect(appState.profile.avoidFlags, contains('vegan'));
  });

  testWidgets('Dish Detail per-dimension variant switcher, Learn More sheet, and Cook Mode', (tester) async {
    final appState = _createTestAppState(
      profile: const UserProfile(
        name: 'Clara',
        lang: 'en',
        avoidFlags: {'vegan'},
        onboardingCompleted: true,
      ),
    );

    await tester.pumpWidget(MorphCookApp(appState: appState));
    await tester.pumpAndSettle();

    // Tap Featured Dish card to open DishDetailScreen
    await tester.tap(find.textContaining('Vegan').first);
    await tester.pumpAndSettle();

    // Expand 'diet' dimension row
    await tester.tap(find.byKey(const ValueKey('dimension_row_diet')));
    await tester.pumpAndSettle();

    // Verify Learn More button opens Kitchen Reference sheet
    final learnMoreFinder = find.text('Learn more');
    if (learnMoreFinder.evaluate().isNotEmpty) {
      await tester.ensureVisible(learnMoreFinder.first);
      await tester.pumpAndSettle();
      await tester.tap(learnMoreFinder.first);
      await tester.pumpAndSettle();
      expect(find.textContaining('kitchen reference'), findsOneWidget);
      Navigator.of(tester.element(find.textContaining('kitchen reference'))).pop();
      await tester.pumpAndSettle();
    }

    // Save variant to Cookbook
    await tester.tap(find.byKey(const ValueKey('dish_detail_save_btn')));
    await tester.pumpAndSettle();
    expect(appState.savedRecipeIds, isNotEmpty);

    // Start Cook Mode
    final startCookBtn = find.byKey(const ValueKey('start_cook_mode_btn'));
    await tester.ensureVisible(startCookBtn);
    await tester.pumpAndSettle();
    await tester.tap(startCookBtn);
    await tester.pumpAndSettle();

    // Trigger timer visual flash alert (Coral/Teal)
    await tester.tap(find.byKey(const ValueKey('cook_mode_timer_complete_now_btn')));
    await tester.pump();
    expect(find.byKey(const ValueKey('visual_flash_alert_banner')), findsOneWidget);

    // Pause Cook Mode and verify resume banner on Home
    await tester.tap(find.byKey(const ValueKey('cook_mode_pause_exit_btn')));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(Scaffold).first)).pop();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('resume_cook_session_banner')), findsOneWidget);
  });

  testWidgets('Navigation across Search, Cookbook, Meal Plan & Settings (including Halal/Kosher note)', (tester) async {
    final appState = _createTestAppState(
      profile: const UserProfile(
        name: 'Clara',
        lang: 'en',
        onboardingCompleted: true,
      ),
    );

    await tester.pumpWidget(MorphCookApp(appState: appState));
    await tester.pumpAndSettle();

    // Navigate to Search
    await tester.tap(find.byKey(const ValueKey('nav_search')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search_query_field')), findsOneWidget);

    // Navigate to Cookbook
    await tester.tap(find.byKey(const ValueKey('nav_cookbook')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cookbook_tab_saved')), findsOneWidget);

    // Navigate to Plan & Shop
    await tester.tap(find.byKey(const ValueKey('nav_plan')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('export_meal_plan_to_shopping_btn')), findsOneWidget);

    // Navigate to Settings & verify Halal/Kosher disclaimer note
    await tester.tap(find.byKey(const ValueKey('nav_settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('halal_kosher_sourcing_note')), findsOneWidget);
    expect(find.textContaining('halal-compatible ingredients'), findsWidgets);
  });
}
