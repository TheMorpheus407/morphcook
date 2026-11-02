import 'package:morphcook/src/models/ingredient.dart';
import 'package:morphcook/src/models/localized_text.dart';
import 'package:morphcook/src/models/ontology.dart';
import 'package:morphcook/src/models/profile.dart';
import 'package:morphcook/src/models/recipe.dart';

/// Hand-built fixtures for the domain tests.
///
/// The domain layer is deliberately free of Flutter, so it can be tested
/// without a widget binding.

L10nText en(String value) => L10nText(<String, String>{'en': value});

/// A minimal ontology with the flags the tests care about.
Ontology buildOntology() {
  return Ontology.fromJson(<String, dynamic>{
    'contains_flags': <Map<String, dynamic>>[
      for (final entry in <(String, String)>[
        ('pork', 'meat'),
        ('beef', 'meat'),
        ('poultry', 'meat'),
        ('fish', 'meat'),
        ('shellfish', 'meat'),
        ('egg', 'animal'),
        ('dairy', 'animal'),
        ('dairy-lactose', 'animal'),
        ('gluten', 'allergen'),
        ('soy', 'allergen'),
        ('tree-nuts', 'allergen'),
        ('peanuts', 'allergen'),
        ('sesame', 'allergen'),
        ('honey', 'animal'),
        ('alcohol', 'other'),
        ('gelatin-non-halal', 'animal'),
        ('added-sugar', 'other'),
      ])
        <String, dynamic>{
          'id': entry.$1,
          'label': <String, String>{'en': entry.$1},
          'category': entry.$2,
        },
    ],
    'avoid_flags': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'vegan',
        'label': <String, String>{'en': 'vegan'},
        'category': 'diet',
        'expands': <String>[
          'pork',
          'beef',
          'poultry',
          'fish',
          'shellfish',
          'egg',
          'dairy',
          'dairy-lactose',
          'honey',
          'gelatin-non-halal',
        ],
      },
      <String, dynamic>{
        'id': 'vegetarian',
        'label': <String, String>{'en': 'vegetarian'},
        'category': 'diet',
        'expands': <String>['pork', 'beef', 'poultry', 'fish', 'shellfish'],
      },
      <String, dynamic>{
        'id': 'halal',
        'label': <String, String>{'en': 'halal'},
        'category': 'diet',
        'expands': <String>['pork', 'alcohol', 'gelatin-non-halal'],
      },
      <String, dynamic>{
        'id': 'dairy',
        'label': <String, String>{'en': 'dairy'},
        'category': 'class',
        'expands': <String>['dairy', 'dairy-lactose'],
      },
      <String, dynamic>{
        'id': 'nuts',
        'label': <String, String>{'en': 'nuts'},
        'category': 'class',
        'expands': <String>['tree-nuts', 'peanuts'],
      },
      <String, dynamic>{
        'id': 'gluten',
        'label': <String, String>{'en': 'gluten'},
        'category': 'class',
        'expands': <String>['gluten'],
      },
    ],
    'certifications': <String>['vegan', 'vegetarian', 'halal'],
    'attributes': <String, dynamic>{
      'effort': <String, dynamic>{
        'label': <String, String>{'en': 'Effort'},
        'values': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'easy',
            'label': <String, String>{'en': 'easy'},
          },
          <String, dynamic>{
            'id': 'medium',
            'label': <String, String>{'en': 'medium'},
          },
          <String, dynamic>{
            'id': 'hard',
            'label': <String, String>{'en': 'hard'},
          },
        ],
      },
    },
  });
}

/// A small ingredient tree with the hierarchy the tests need.
IngredientTree buildIngredients() {
  return IngredientTree.fromJson(<String, dynamic>{
    'nodes': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'dairy',
        'label': <String, String>{'en': 'Dairy'},
        'parent': null,
        'aisle': 'dairy',
        'unit_system': 'any',
      },
      <String, dynamic>{
        'id': 'dairy.milk',
        'label': <String, String>{'en': 'Milk'},
        'parent': 'dairy',
        'aisle': 'dairy',
        'unit_system': 'volume',
      },
      <String, dynamic>{
        'id': 'dairy.milk.whole',
        'label': <String, String>{'en': 'Whole milk'},
        'parent': 'dairy.milk',
        'aisle': 'dairy',
        'unit_system': 'volume',
      },
      <String, dynamic>{
        'id': 'produce',
        'label': <String, String>{'en': 'Produce'},
        'parent': null,
        'aisle': 'produce',
        'unit_system': 'any',
      },
      <String, dynamic>{
        'id': 'produce.garlic',
        'label': <String, String>{'en': 'Garlic'},
        'parent': 'produce',
        'aisle': 'produce',
        'unit_system': 'count',
      },
      <String, dynamic>{
        'id': 'produce.herbs',
        'label': <String, String>{'en': 'Herbs'},
        'parent': 'produce',
        'aisle': 'produce',
        'unit_system': 'count',
      },
      <String, dynamic>{
        'id': 'produce.herbs.cilantro',
        'label': <String, String>{'en': 'Coriander'},
        'parent': 'produce.herbs',
        'aisle': 'produce',
        'unit_system': 'count',
      },
      <String, dynamic>{
        'id': 'pantry',
        'label': <String, String>{'en': 'Pantry'},
        'parent': null,
        'aisle': 'pantry',
        'unit_system': 'any',
      },
      <String, dynamic>{
        'id': 'pantry.flour',
        'label': <String, String>{'en': 'Flour'},
        'parent': 'pantry',
        'aisle': 'pantry',
        'unit_system': 'mass',
      },
      <String, dynamic>{
        'id': 'pantry.oil',
        'label': <String, String>{'en': 'Oil'},
        'parent': 'pantry',
        'aisle': 'pantry',
        'unit_system': 'volume',
      },
    ],
  });
}

/// Builds a recipe for the tests.
Recipe buildRecipe({
  String id = 'test-recipe',
  String dishId = 'test-dish',
  String diet = 'classic',
  Set<String> contains = const <String>{},
  List<String> ingredientIds = const <String>[],
  String effort = 'easy',
  int timeMinutes = 20,
  int calories = 500,
  int servings = 2,
  Set<String> certifications = const <String>{},
  List<String> techniques = const <String>['sauté'],
  List<String> mealSlots = const <String>['dinner'],
}) {
  return Recipe(
    id: id,
    dishId: dishId,
    title: en(id),
    heroText: en('hero'),
    capCaption: en('caption'),
    stripeColor: '#C4694D',
    ingredients: <RecipeIngredient>[
      for (final ingredientId in ingredientIds)
        RecipeIngredient(
          ingredientId: ingredientId,
          name: en(ingredientId),
          quantity: 1,
          unit: 'g',
        ),
    ],
    steps: const <RecipeStep>[RecipeStep(instruction: L10nText(<String, String>{'en': 'do it'}))],
    contains: contains,
    attributes: <String, List<String>>{
      'effort': <String>[effort],
      'time_bucket': <String>['≤30'],
      'calorie_bucket': <String>['≤600'],
      'technique': techniques,
      'certifications': certifications.toList(),
    },
    diet: diet,
    timeMinutes: timeMinutes,
    calories: calories,
    macros: const Nutrition(calories: 500, protein: 20, carbs: 50, fat: 15),
    servings: servings,
    tags: en('tag'),
    mealSlots: mealSlots,
    partitionId: 'core',
  );
}

/// A profile with generous defaults, so each test can tighten one field.
Profile buildProfile({
  String name = 'Sam',
  String lang = 'en',
  Set<String> avoidFlags = const <String>{},
  Set<String> avoidIngredients = const <String>{},
  Set<String> requiredAttributes = const <String>{},
  int maxTimeMinutes = 60,
  int calorieTarget = 600,
  int calorieTolerance = 120,
  String preferredEffort = 'easy',
}) {
  return Profile(
    name: name,
    lang: lang,
    avoidFlags: avoidFlags,
    avoidIngredients: avoidIngredients,
    requiredAttributes: requiredAttributes,
    maxTimeMinutes: maxTimeMinutes,
    calorieTarget: calorieTarget,
    calorieTolerance: calorieTolerance,
    preferredEffort: preferredEffort,
    showVariantTags: true,
    reduceMotion: null,
    visualAlertEnabled: true,
    quickNextTapEnabled: false,
    onboardingComplete: true,
    dishesOutsideCalorieTarget: const <String>{},
  );
}
