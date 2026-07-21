import 'package:morphcook/core/models/ingredient_node.dart';
import 'package:morphcook/core/models/ontology.dart';
import 'package:morphcook/core/models/recipe.dart';

Ontology testOntology() => Ontology.fromJson({
      'version': 1,
      'contains_flags': [
        for (final f in ['pork', 'dairy', 'gluten', 'egg', 'honey', 'alcohol'])
          {
            'id': f,
            'label': {'en': f, 'de': f}
          }
      ],
      'compound_flags': [
        {
          'id': 'vegan',
          'label': {'en': 'vegan', 'de': 'vegan'},
          'expands_to': ['pork', 'dairy', 'egg', 'honey']
        },
        {
          'id': 'halal',
          'label': {'en': 'halal', 'de': 'halal'},
          'expands_to': ['pork', 'alcohol']
        }
      ],
      'effort_levels': [
        {'id': 'easy', 'label': {'en': 'easy', 'de': 'einfach'}}
      ],
      'time_buckets': ['≤15', '≤30'],
      'calorie_buckets': ['≤400', '≤600'],
      'techniques': ['bake'],
      'calorie_tolerance': 150,
    });

IngredientDictionary testDictionary() => IngredientDictionary([
      IngredientNode.fromJson({
        'id': 'dairy',
        'name': {'en': 'dairy', 'de': 'Milchprodukte'},
        'children': [
          {
            'id': 'cow-milk',
            'name': {'en': 'cow milk', 'de': 'Kuhmilch'},
            'children': [
              {
                'id': 'whole-milk',
                'name': {'en': 'whole milk', 'de': 'Vollmilch'}
              }
            ]
          },
          {
            'id': 'cheese',
            'name': {'en': 'cheese', 'de': 'Käse'}
          }
        ]
      }),
      IngredientNode.fromJson({
        'id': 'produce',
        'name': {'en': 'produce', 'de': 'Obst & Gemüse'},
        'children': [
          {
            'id': 'apple',
            'name': {'en': 'apple', 'de': 'Apfel'}
          },
          {
            'id': 'cilantro',
            'name': {'en': 'cilantro', 'de': 'Koriander'}
          }
        ]
      })
    ]);

Recipe testRecipe({
  String id = 'r1',
  String dishId = 'd1',
  Set<String> contains = const {},
  Set<String> attributes = const {'easy'},
  List<String> ingredientIds = const ['apple'],
  int timeMinutes = 30,
  int calories = 500,
  String effort = 'easy',
  List<String> mealTypes = const ['dinner'],
}) =>
    Recipe(
      id: id,
      dishId: dishId,
      title: {'en': id, 'de': id},
      dimensions: {'diet': 'classic', 'effort': effort, 'calorie_level': 'light'},
      contains: contains,
      attributes: attributes,
      timeMinutes: timeMinutes,
      caloriesPerServing: calories,
      servings: 2,
      ingredients: [
        for (final iid in ingredientIds)
          Ingredient(id: iid, name: {'en': iid}, amount: 1, unit: 'pcs')
      ],
      steps: const [],
      macros: const Macros(proteinG: 10, carbsG: 10, fatG: 10),
      mealTypes: mealTypes,
    );
