import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:morphcook/main.dart';
import 'package:morphcook/services/app_state.dart';
import 'package:morphcook/models/localized_string.dart';
import 'package:morphcook/models/dish.dart';
import 'package:morphcook/models/recipe.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/ontology.dart';
import 'package:morphcook/models/ingredient_node.dart';
import 'package:morphcook/screens/dish_detail_screen.dart';
import 'package:morphcook/screens/cook_mode_screen.dart';
import 'package:morphcook/screens/shopping_screen.dart';
import 'package:morphcook/screens/meal_planner_screen.dart';
import 'package:morphcook/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState mockAppState;
  late Dish testDish;
  late Recipe classicRecipe;
  late Recipe veganRecipe;

  setUp(() {
    mockAppState = AppState();

    testDish = Dish(
      id: 'doener',
      name: const LocalizedString({'en': 'Döner Kebab', 'de': 'Döner Kebab'}),
      heroText: const LocalizedString({'en': 'Street Food Icon', 'de': 'Streetfood Ikone'}),
      capCaption: const LocalizedString({'en': 'Berlin Street Style', 'de': 'Berliner Art'}),
      stripeColor: '#D48B68',
      partitionId: 'core',
      secondaryPartitions: [],
      cuisineTags: ['street-food'],
      frequencyTier: 'daily',
      variantRecipeIds: ['doener-classic', 'doener-vegan'],
    );

    classicRecipe = Recipe(
      id: 'doener-classic',
      dishId: 'doener',
      title: const LocalizedString({'en': 'Classic Street Döner', 'de': 'Klassischer Döner'}),
      description: const LocalizedString({'en': 'With spiced beef', 'de': 'Mit Rindfleisch'}),
      variantDimensionValues: {'diet': 'classic', 'effort': 'medium'},
      servings: 2,
      prepTimeMinutes: 10,
      cookTimeMinutes: 15,
      totalTimeMinutes: 25,
      caloriesPerServing: 620,
      macros: const RecipeMacros(calories: 620, protein: 35, carbs: 55, fat: 22),
      contains: ['gluten', 'dairy', 'beef'],
      ingredientIds: ['beef', 'pita-bread', 'garlic'],
      attributes: ['medium'],
      ingredients: [
        RecipeIngredient(
          id: 'beef',
          name: const LocalizedString({'en': 'Beef', 'de': 'Rindfleisch'}),
          amount: 250,
          unit: 'g',
          aisle: 'Meat & Seafood',
        ),
        RecipeIngredient(
          id: 'garlic',
          name: const LocalizedString({'en': 'Garlic', 'de': 'Knoblauch'}),
          amount: 2,
          unit: 'cloves',
          aisle: 'Produce',
        ),
      ],
      steps: [
        RecipeStep(
          stepNumber: 1,
          instruction: const LocalizedString({'en': 'Sear beef in pan', 'de': 'Rind anbraten'}),
          timerMinutes: 5,
        ),
      ],
    );

    veganRecipe = Recipe(
      id: 'doener-vegan',
      dishId: 'doener',
      title: const LocalizedString({'en': 'Vegan Seitan Döner', 'de': 'Veganer Döner'}),
      description: const LocalizedString({'en': 'With seitan strips', 'de': 'Mit Seitan'}),
      variantDimensionValues: {'diet': 'vegan', 'effort': 'easy'},
      servings: 2,
      prepTimeMinutes: 5,
      cookTimeMinutes: 10,
      totalTimeMinutes: 15,
      caloriesPerServing: 480,
      macros: const RecipeMacros(calories: 480, protein: 30, carbs: 60, fat: 12),
      contains: ['gluten', 'soy'],
      ingredientIds: ['seitan', 'pita-bread'],
      attributes: ['easy'],
      ingredients: [
        RecipeIngredient(
          id: 'seitan',
          name: const LocalizedString({'en': 'Seitan', 'de': 'Seitan'}),
          amount: 200,
          unit: 'g',
          aisle: 'Plant Proteins',
        ),
      ],
      steps: [
        RecipeStep(
          stepNumber: 1,
          instruction: const LocalizedString({'en': 'Pan fry seitan', 'de': 'Seitan anbraten'}),
        ),
      ],
    );

    mockAppState.corpus.dishes = [testDish];
    mockAppState.corpus.dishMap = {testDish.id: testDish};
    mockAppState.corpus.recipes = [classicRecipe, veganRecipe];
    mockAppState.corpus.recipeMap = {
      classicRecipe.id: classicRecipe,
      veganRecipe.id: veganRecipe,
    };
    mockAppState.corpus.ontology = Ontology.fromJson({
      'contains_flags': [],
      'compound_avoid_flags': {},
      'attributes': {'effort': [], 'time_bucket': [], 'calorie_bucket': [], 'techniques': []},
    });
    mockAppState.corpus.ingredientDictionary = IngredientDictionary.fromJsonList([]);
    mockAppState.profile = UserProfile(
      name: 'Test Chef',
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

  testWidgets('RootScreen renders Feed, Navigation and Masthead', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget(const RootScreen()));
    await tester.pumpAndSettle();

    expect(find.text('MorphCook'), findsOneWidget);
    expect(find.text('Feed'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Notebook'), findsOneWidget);
  });

  testWidgets('DishDetailScreen renders hero, servings scaler, and dimensions', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget(DishDetailScreen(dish: testDish)));
    await tester.pumpAndSettle();

    expect(find.text('Classic Street Döner'), findsWidgets);
    expect(find.text('2 servings'), findsOneWidget);

    // Tap '+' to scale servings to 3
    final addIcon = find.byIcon(Icons.add);
    expect(addIcon, findsOneWidget);
    await tester.tap(addIcon);
    await tester.pumpAndSettle();

    expect(find.text('3 servings'), findsOneWidget);
  });

  testWidgets('CookModeScreen renders dark layout, steps, and advance button', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget(CookModeScreen(recipe: classicRecipe)));
    await tester.pumpAndSettle();

    expect(find.text('STEP 1 OF 1'), findsOneWidget);
    expect(find.text('Sear beef in pan'), findsOneWidget);
    expect(find.text('FINISH COOKING'), findsOneWidget);

    // Tap finish
    await tester.tap(find.text('FINISH COOKING'));
    await tester.pumpAndSettle();

    expect(find.text('Bon Appétit!'), findsOneWidget);
  });

  testWidgets('ShoppingScreen renders empty state and custom add item button', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget(const ShoppingScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Market List'), findsOneWidget);
    expect(find.text('Your Market Basket is Empty'), findsOneWidget);
  });

  testWidgets('MealPlannerScreen renders days and slots', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget(const MealPlannerScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Weekly Meal Plan'), findsOneWidget);
    expect(find.text('Breakfast'), findsWidgets);
    expect(find.text('Lunch'), findsWidgets);
    expect(find.text('Dinner'), findsWidgets);
  });

  testWidgets('SettingsScreen renders profile editor and language toggles', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget(const SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Settings & Profile'), findsOneWidget);
    expect(find.text('Test Chef'), findsOneWidget);
    expect(find.text('Export File'), findsOneWidget);
    expect(find.text('Restore File'), findsOneWidget);
  });
}
