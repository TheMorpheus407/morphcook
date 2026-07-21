import 'package:morphcook/models/recipe.dart';

Recipe testRecipe({
  String id = 'recipe',
  String dishId = 'dish',
  Set<String> contains = const {},
  Set<String> attributes = const {'easy'},
  List<IngredientAmount> ingredients = const [],
  int timeMinutes = 30,
  int calories = 600,
  String effort = 'easy',
  String diet = 'classic',
  String calorieLevel = 'balanced',
  Set<String> mealTypes = const {'dinner'},
}) => Recipe(
  id: id,
  dishId: dishId,
  title: {'en': id, 'de': id},
  subtitle: const {'en': 'subtitle', 'de': 'untertitel'},
  diet: diet,
  effort: effort,
  calorieLevel: calorieLevel,
  contains: contains,
  attributes: attributes,
  timeMinutes: timeMinutes,
  servings: 2,
  nutrition: Nutrition(calories: calories, protein: 20, carbs: 50, fat: 15),
  ingredients: ingredients,
  steps: const [
    RecipeStep(text: {'en': 'Cook it.', 'de': 'Koche es.'}),
  ],
  tags: const {},
  mealTypes: mealTypes,
  cuisine: 'test',
  season: 'all',
);

IngredientAmount testIngredient({
  required String id,
  double quantity = 1,
  String unit = 'piece',
  bool volumeConvertible = false,
}) => IngredientAmount(
  id: id,
  name: {'en': id, 'de': id},
  quantity: quantity,
  unit: unit,
  aisle: 'pantry',
  volumeConvertible: volumeConvertible,
);
