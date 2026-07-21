import 'package:morphcook/domain/domain.dart';

final testOntology = Ontology(
  containsFlags: [
    for (final id in [
      'beef',
      'pork',
      'poultry',
      'fish',
      'shellfish',
      'egg',
      'dairy',
      'honey',
      'gluten',
      'alcohol',
      'gelatin-non-halal',
    ])
      OntologyFlag(id: id, name: LocalizedText({'en': id})),
  ],
  compoundAvoidFlags: [
    OntologyFlag(
      id: 'vegan',
      name: LocalizedText(const {'en': 'Vegan'}),
      expandsTo: const {
        'beef',
        'pork',
        'poultry',
        'fish',
        'shellfish',
        'egg',
        'dairy',
        'honey',
      },
    ),
    OntologyFlag(
      id: 'halal',
      name: LocalizedText(const {'en': 'Halal-compatible'}),
      expandsTo: const {'pork', 'alcohol', 'gelatin-non-halal'},
    ),
  ],
);

final testIngredients = IngredientDictionary([
  IngredientNode(
    id: 'dairy',
    name: LocalizedText(const {'en': 'Dairy', 'de': 'Milchprodukte'}),
    children: [
      IngredientNode(
        id: 'cheese',
        name: LocalizedText(const {'en': 'Cheese', 'de': 'Käse'}),
        parentId: 'dairy',
        children: [
          IngredientNode(
            id: 'parmesan',
            name: LocalizedText(const {'en': 'Parmesan', 'de': 'Parmesan'}),
            parentId: 'cheese',
            containsFlags: const {'dairy'},
          ),
        ],
        containsFlags: const {'dairy'},
      ),
    ],
    containsFlags: const {'dairy'},
  ),
  IngredientNode(
    id: 'produce',
    name: LocalizedText(const {'en': 'Produce', 'de': 'Obst & Gemüse'}),
    children: [
      IngredientNode(
        id: 'apple',
        name: LocalizedText(const {'en': 'Apple', 'de': 'Apfel'}),
        parentId: 'produce',
      ),
      IngredientNode(
        id: 'cilantro',
        name: LocalizedText(const {'en': 'Cilantro', 'de': 'Koriander'}),
        parentId: 'produce',
        aliases: const {
          'en': ['coriander leaves'],
          'de': ['Koriandergrün'],
        },
      ),
    ],
  ),
]);

Recipe testRecipe({
  String id = 'recipe-1',
  String dishId = 'dish-1',
  String enName = 'Quiet pasta',
  String deName = 'Leise Pasta',
  Set<String> contains = const {},
  Set<String> attributes = const {},
  int minutes = 30,
  int calories = 600,
  String effort = 'easy',
  String diet = 'vegan',
  String calorieLevel = 'balanced',
  Set<String> mealTypes = const {'dinner'},
  Set<String> tags = const {'comfort'},
  Set<String> cuisines = const {'italian'},
  List<RecipeIngredient> ingredients = const [],
  String partitionId = 'core',
}) => Recipe(
  id: id,
  dishId: dishId,
  name: LocalizedText({'en': enName, 'de': deName}),
  description: LocalizedText(const {
    'en': 'A gentle, useful recipe.',
    'de': 'Ein sanftes, gutes Rezept.',
  }),
  variantDimensions: {
    'diet': diet,
    'effort': effort,
    'calorie_level': calorieLevel,
  },
  contains: contains,
  attributes: attributes,
  timeMinutes: minutes,
  caloriesPerServing: calories,
  servings: 2,
  nutrition: Nutrition(
    calories: calories,
    proteinGrams: 20,
    carbohydrateGrams: 70,
    fatGrams: 18,
  ),
  ingredients: ingredients,
  steps: [
    RecipeStep(
      id: 'one',
      text: LocalizedText(const {'en': 'Cook it.', 'de': 'Garen.'}),
    ),
  ],
  tags: tags,
  searchTerms: const {
    'en': ['weeknight supper'],
    'de': ['Feierabendessen'],
  },
  mealTypes: mealTypes,
  cuisineTags: cuisines,
  partitionId: partitionId,
);

UserProfile testProfile({
  Set<String> avoidFlags = const {},
  Set<String> avoidIngredients = const {},
  Set<String> requiredAttributes = const {},
  int maxTime = 60,
  int calories = 600,
  int tolerance = 150,
  String effort = 'easy',
}) => UserProfile(
  name: 'Mara',
  avoidFlags: avoidFlags,
  avoidIngredientIds: avoidIngredients,
  requiredAttributes: requiredAttributes,
  maxTimeMinutes: maxTime,
  calorieTarget: calories,
  calorieTolerance: tolerance,
  preferredEffort: effort,
);
