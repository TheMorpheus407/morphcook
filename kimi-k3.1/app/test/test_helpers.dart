import 'package:morphcook/models/content.dart';
import 'package:morphcook/models/localized_text.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/recipe.dart';
import 'package:morphcook/services/matching.dart';

LocalizedText text(String value) => LocalizedText({'en': value, 'de': value});

Ontology testOntology() => Ontology.fromJson({
  'contains_flags': [
    for (final id in [
      'dairy',
      'egg',
      'poultry',
      'fish',
      'shellfish',
      'honey',
      'gluten',
      'tree-nuts',
      'peanuts',
      'pork',
      'alcohol',
    ])
      {
        'id': id,
        'name': {'en': id, 'de': id},
      },
  ],
  'avoid_flags': [
    {
      'id': 'vegan',
      'name': {'en': 'Vegan', 'de': 'Vegan'},
      'expands_to': ['dairy', 'egg', 'poultry', 'fish', 'shellfish', 'honey'],
    },
    {
      'id': 'halal',
      'name': {'en': 'Halal', 'de': 'Halal'},
      'expands_to': ['pork', 'alcohol'],
    },
    {
      'id': 'gluten-free',
      'name': {'en': 'Gluten free', 'de': 'Glutenfrei'},
      'expands_to': ['gluten'],
    },
    {
      'id': 'nut-free',
      'name': {'en': 'Nut free', 'de': 'Nussfrei'},
      'expands_to': ['tree-nuts', 'peanuts'],
    },
  ],
  'attributes': [
    for (final id in ['easy', 'medium', 'hard', 'breakfast', 'dinner', 'halal'])
      {
        'id': id,
        'name': {'en': id, 'de': id},
        'kind': id,
      },
  ],
  'dimensions': {
    'diet': {
      'name': {'en': 'Diet', 'de': 'Ernährung'},
      'values': [
        {
          'id': 'classic',
          'name': {'en': 'Classic', 'de': 'Klassisch'},
        },
        {
          'id': 'vegan',
          'name': {'en': 'Vegan', 'de': 'Vegan'},
        },
        {
          'id': 'keto',
          'name': {'en': 'Keto', 'de': 'Keto'},
        },
      ],
    },
    'effort': {
      'name': {'en': 'Effort', 'de': 'Aufwand'},
      'values': [
        {
          'id': 'easy',
          'name': {'en': 'Easy', 'de': 'Einfach'},
        },
        {
          'id': 'medium',
          'name': {'en': 'Medium', 'de': 'Mittel'},
        },
      ],
    },
    'calorie': {
      'name': {'en': 'Calorie level', 'de': 'Kalorienlevel'},
      'values': [
        {
          'id': 'regular',
          'name': {'en': 'Regular', 'de': 'Klassisch'},
        },
        {
          'id': 'light',
          'name': {'en': 'Light', 'de': 'Leicht'},
        },
      ],
    },
  },
});

IngredientDictionary testIngredients() => IngredientDictionary.fromJson({
  'ingredients': [
    {
      'id': 'dairy',
      'name': {'en': 'Dairy', 'de': 'Milchprodukte'},
      'flags': ['dairy'],
      'aisle': 'dairy',
      'children': [
        {
          'id': 'cheese',
          'name': {'en': 'Cheese', 'de': 'Käse'},
          'flags': [],
          'aisle': 'dairy',
          'children': [
            {
              'id': 'parmesan',
              'name': {'en': 'Parmesan', 'de': 'Parmesan'},
              'flags': [],
              'aisle': 'dairy',
              'children': [],
            },
          ],
        },
      ],
    },
    {
      'id': 'nuts',
      'name': {'en': 'Nuts', 'de': 'Nüsse'},
      'flags': [],
      'aisle': 'pantry',
      'children': [
        {
          'id': 'tree-nuts',
          'name': {'en': 'Tree nuts', 'de': 'Schalenfrüchte'},
          'flags': ['tree-nuts'],
          'aisle': 'pantry',
          'children': [
            {
              'id': 'almonds',
              'name': {'en': 'Almonds', 'de': 'Mandeln'},
              'flags': ['almonds'],
              'aisle': 'pantry',
              'children': [],
            },
          ],
        },
      ],
    },
    {
      'id': 'garlic',
      'name': {'en': 'Garlic', 'de': 'Knoblauch'},
      'flags': [],
      'aisle': 'produce',
      'children': [],
    },
    {
      'id': 'cilantro',
      'name': {'en': 'Cilantro', 'de': 'Koriander'},
      'flags': [],
      'aisle': 'produce',
      'children': [],
    },
  ],
});

Recipe testRecipe({
  String id = 'r1',
  String dishId = 'dish',
  Set<String> contains = const {},
  Set<String> attributes = const {'easy'},
  Set<String> ingredientIds = const {},
  Map<String, String>? dimensions,
  int time = 30,
  int calories = 500,
  List<RecipeIngredient> ingredients = const [],
  Set<String> tags = const {},
  int servings = 2,
}) => Recipe(
  id: id,
  dishId: dishId,
  title: text(id),
  summary: text('summary'),
  contains: contains,
  attributes: attributes,
  dimensions:
      dimensions ?? {'diet': 'classic', 'effort': 'easy', 'calorie': 'regular'},
  timeMinutes: time,
  caloriesPerServing: calories,
  servings: servings,
  macros: const Macros(protein: 20, carbs: 50, fat: 15),
  ingredients: ingredients,
  ingredientIds: ingredientIds,
  steps: [RecipeStep(text: text('Cook'), timerSeconds: 60)],
  tags: tags,
);

RecipeIngredient ingredient(
  String id,
  double? amount,
  String unit, {
  String aisle = 'produce',
}) => RecipeIngredient(
  id: id,
  amount: amount,
  unit: unit,
  name: text(id),
  aisle: aisle,
  preparation: const LocalizedText({'en': '', 'de': ''}),
);

RecipeMatcher testMatcher() =>
    RecipeMatcher(ontology: testOntology(), ingredients: testIngredients());

Profile testProfile({
  Set<String> avoidFlags = const {},
  Set<String> avoidIngredients = const {},
  Set<String> requiredAttributes = const {},
  int maxTime = 45,
  int calories = 600,
  int tolerance = 100,
  String effort = 'easy',
}) => Profile(
  avoidFlags: avoidFlags,
  avoidIngredients: avoidIngredients,
  requiredAttributes: requiredAttributes,
  maxTimeMinutes: maxTime,
  calorieTarget: calories,
  calorieTolerance: tolerance,
  preferredEffort: effort,
  onboardingComplete: true,
);

Dish testDish(List<String> ids) => Dish(
  id: 'dish',
  canonicalName: text('Dish'),
  heroText: text('Hero'),
  capCaption: text('Caption'),
  stripeColor: '#3f756c',
  variantIds: ids,
  partitionId: 'core',
  secondaryPartitions: const [],
  cuisineTags: const [],
  frequencyTier: 'core',
  tags: const [],
);
