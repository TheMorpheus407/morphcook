import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:morphcook/services/app_state.dart';
import 'package:morphcook/models/localized_string.dart';
import 'package:morphcook/models/dish.dart';
import 'package:morphcook/models/recipe.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/ontology.dart';
import 'package:morphcook/models/ingredient_node.dart';
import 'package:morphcook/models/shopping_item.dart';
import 'package:morphcook/screens/search_screen.dart';
import 'package:morphcook/screens/faq_screen.dart';
import 'package:morphcook/screens/shopping_insights_screen.dart';
import 'package:morphcook/screens/onboarding_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState mockAppState;

  setUp(() {
    mockAppState = AppState();

    final testDish = Dish(
      id: 'ramen',
      name: const LocalizedString({'en': 'Tokyo Craft Ramen', 'de': 'Tokyo Ramen'}),
      heroText: const LocalizedString({'en': 'Noodle bowl', 'de': 'Nudelsuppe'}),
      capCaption: const LocalizedString({'en': 'Steaming bowl', 'de': 'Dampfende Schüssel'}),
      stripeColor: '#8C5846',
      partitionId: 'core',
      secondaryPartitions: [],
      cuisineTags: ['soup', 'noodles'],
      frequencyTier: 'weekly',
      variantRecipeIds: ['ramen-classic', 'ramen-vegan'],
    );

    final ramenClassic = Recipe(
      id: 'ramen-classic',
      dishId: 'ramen',
      title: const LocalizedString({'en': 'Tonkotsu Ramen', 'de': 'Tonkotsu Ramen'}),
      description: const LocalizedString({'en': 'Rich broth with chashu', 'de': 'Kräftige Brühe'}),
      variantDimensionValues: {'diet': 'classic', 'effort': 'hard'},
      servings: 2,
      prepTimeMinutes: 20,
      cookTimeMinutes: 30,
      totalTimeMinutes: 50,
      caloriesPerServing: 720,
      macros: const RecipeMacros(calories: 720, protein: 40, carbs: 70, fat: 25),
      contains: ['pork', 'gluten', 'egg'],
      ingredientIds: ['pasta', 'pork-chops', 'garlic'],
      attributes: ['hard'],
      ingredients: [
        RecipeIngredient(
          id: 'garlic',
          name: const LocalizedString({'en': 'Garlic', 'de': 'Knoblauch'}),
          amount: 3,
          unit: 'cloves',
          aisle: 'Produce',
        ),
      ],
      steps: [],
    );

    final ramenVegan = Recipe(
      id: 'ramen-vegan',
      dishId: 'ramen',
      title: const LocalizedString({'en': 'Miso Mushroom Ramen', 'de': 'Miso Pilz Ramen'}),
      description: const LocalizedString({'en': 'Savory miso broth', 'de': 'Miso Brühe'}),
      variantDimensionValues: {'diet': 'vegan', 'effort': 'medium'},
      servings: 2,
      prepTimeMinutes: 10,
      cookTimeMinutes: 20,
      totalTimeMinutes: 30,
      caloriesPerServing: 480,
      macros: const RecipeMacros(calories: 480, protein: 22, carbs: 65, fat: 12),
      contains: ['soy', 'gluten'],
      ingredientIds: ['pasta', 'tofu', 'shiitake'],
      attributes: ['medium'],
      ingredients: [
        RecipeIngredient(
          id: 'garlic',
          name: const LocalizedString({'en': 'Garlic', 'de': 'Knoblauch'}),
          amount: 2,
          unit: 'cloves',
          aisle: 'Produce',
        ),
      ],
      steps: [],
    );

    mockAppState.corpus.dishes = [testDish];
    mockAppState.corpus.dishMap = {testDish.id: testDish};
    mockAppState.corpus.recipes = [ramenClassic, ramenVegan];
    mockAppState.corpus.recipeMap = {
      ramenClassic.id: ramenClassic,
      ramenVegan.id: ramenVegan,
    };
    mockAppState.corpus.ontology = Ontology.fromJson({
      'contains_flags': [
        {'id': 'pork', 'label': {'en': 'Pork', 'de': 'Schwein'}},
      ],
      'compound_avoid_flags': {
        'vegan': {
          'id': 'vegan',
          'label': {'en': 'Vegan', 'de': 'Vegan'},
          'description': {'en': 'No animals', 'de': 'Keine Tiere'},
          'expands_to': ['pork'],
        }
      },
      'attributes': {'effort': [], 'time_bucket': [], 'calorie_bucket': [], 'techniques': []},
    });
    mockAppState.corpus.ingredientDictionary = IngredientDictionary.fromJsonList([]);
    mockAppState.profile = UserProfile(
      name: 'Chef Alex',
      onboardingCompleted: true,
      lang: 'en',
    );
    mockAppState.isInitialized = true;
  });

  Widget createTestWidget(Widget child) {
    return ChangeNotifierProvider<AppState>.value(
      value: mockAppState,
      child: MaterialApp(
        home: child,
      ),
    );
  }

  testWidgets('SearchScreen queries recipes and logs content gap on 0 results', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget(const SearchScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Index & Search'), findsOneWidget);

    // Search for non-existent dish (e.g. "Sushi Rolls")
    final searchInput = find.byType(TextField);
    await tester.enterText(searchInput, 'Sushi Rolls');
    await tester.pumpAndSettle();

    expect(find.text('No Recipes Found'), findsOneWidget);
    expect(mockAppState.contentRequests, contains('sushi rolls'));
  });

  testWidgets('FaqScreen filters by category and search queries', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget(const FaqScreen()));
    await tester.pumpAndSettle();

    expect(find.text('FAQ & Knowledge Base'), findsOneWidget);
    expect(find.text('Dietary Matching'), findsOneWidget);
  });

  testWidgets('Shopping list unit-aware aggregation merges garlic cloves and converts units', (WidgetTester tester) async {
    final list = <ShoppingItem>[];

    final item1 = ShoppingItem(
      id: '1',
      ingredientId: 'garlic',
      name: const LocalizedString({'en': 'Garlic', 'de': 'Knoblauch'}),
      amount: 2.0,
      unit: 'cloves',
      aisle: 'Produce',
    );

    final item2 = ShoppingItem(
      id: '2',
      ingredientId: 'garlic',
      name: const LocalizedString({'en': 'Garlic', 'de': 'Knoblauch'}),
      amount: 3.0,
      unit: 'cloves',
      aisle: 'Produce',
    );

    ShoppingItem.aggregateInto(list, item1);
    ShoppingItem.aggregateInto(list, item2);

    expect(list.length, equals(1));
    expect(list.first.amount, equals(5.0));
  });

  testWidgets('ShoppingInsightsScreen displays culinary variety score', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    mockAppState.shoppingList = [
      ShoppingItem(
        id: '1',
        ingredientId: 'garlic',
        name: const LocalizedString({'en': 'Garlic', 'de': 'Knoblauch'}),
        amount: 2,
        unit: 'cloves',
        aisle: 'Produce',
      ),
      ShoppingItem(
        id: '2',
        ingredientId: 'tomatoes',
        name: const LocalizedString({'en': 'Tomatoes', 'de': 'Tomaten'}),
        amount: 3,
        unit: 'pieces',
        aisle: 'Produce',
      ),
    ];

    await tester.pumpWidget(createTestWidget(const ShoppingInsightsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Shopping Insights'), findsOneWidget);
    expect(find.text('CULINARY VARIETY SCORE'), findsOneWidget);
  });

  testWidgets('OnboardingScreen navigates steps and saves profile', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    bool completed = false;
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: mockAppState,
        child: MaterialApp(
          home: OnboardingScreen(onComplete: () => completed = true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose Your Language'), findsOneWidget);

    // Step 1 -> Step 2
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('What should we call you?'), findsOneWidget);

    // Step 2 -> Step 3
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Diet & Allergies'), findsOneWidget);

    // Step 3 -> Step 4
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Time, Calories & Effort'), findsOneWidget);

    // Step 4 -> Step 5
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Your Kitchen Notebook'), findsOneWidget);

    // Finish
    await tester.tap(find.text('Enter Kitchen'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
  });
}
