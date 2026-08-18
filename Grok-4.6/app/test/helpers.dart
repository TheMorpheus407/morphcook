import 'package:morphcook/models/collections.dart';
import 'package:morphcook/models/ingredient.dart';
import 'package:morphcook/models/localized.dart';
import 'package:morphcook/models/ontology.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/recipe.dart';

Ontology testOntology() => Ontology(
      containsFlags: const [
        FlagDef(id: 'dairy', name: LocalizedText({'en': 'dairy', 'de': 'Milch'})),
        FlagDef(id: 'pork', name: LocalizedText({'en': 'pork', 'de': 'Schwein'})),
        FlagDef(id: 'gluten', name: LocalizedText({'en': 'gluten', 'de': 'Gluten'})),
        FlagDef(id: 'honey', name: LocalizedText({'en': 'honey', 'de': 'Honig'})),
        FlagDef(id: 'egg', name: LocalizedText({'en': 'egg', 'de': 'Ei'})),
      ],
      compoundFlags: const [
        CompoundFlag(
          id: 'vegan',
          name: LocalizedText({'en': 'vegan', 'de': 'vegan'}),
          expandsTo: {'pork', 'dairy', 'honey', 'egg'},
        ),
        CompoundFlag(
          id: 'halal',
          name: LocalizedText({'en': 'halal-compatible', 'de': 'halal-kompatibel'}),
          expandsTo: {'pork'},
        ),
      ],
      attributes: const {
        'effort': ['easy', 'medium', 'hard'],
      },
      dietLabels: const ['classic', 'vegan'],
      dietLabelNames: const {
        'classic': LocalizedText({'en': 'classic', 'de': 'klassisch'}),
        'vegan': LocalizedText({'en': 'vegan', 'de': 'vegan'}),
      },
      attributeNames: const {
        'easy': LocalizedText({'en': 'easy', 'de': 'einfach'}),
        'medium': LocalizedText({'en': 'medium', 'de': 'mittel'}),
        'hard': LocalizedText({'en': 'involved', 'de': 'aufwendig'}),
        'halal': LocalizedText({'en': 'halal', 'de': 'halal'}),
      },
    );

IngredientDictionary testDictionary() => IngredientDictionary(
      aisleNames: const {
        'produce': LocalizedText({'en': 'produce', 'de': 'Obst'}),
        'dairy': LocalizedText({'en': 'dairy', 'de': 'Milch'}),
      },
      roots: const [
        IngredientNode(
          id: 'dairy',
          name: LocalizedText({'en': 'dairy', 'de': 'Milchprodukte'}),
          aisle: 'dairy',
          children: [
            IngredientNode(
              id: 'cow-milk',
              name: LocalizedText({'en': 'cow milk', 'de': 'Kuhmilch'}),
              children: [
                IngredientNode(
                  id: 'whole-milk',
                  name: LocalizedText({'en': 'whole milk', 'de': 'Vollmilch'}),
                ),
              ],
            ),
          ],
        ),
        IngredientNode(
          id: 'garlic',
          name: LocalizedText({'en': 'garlic', 'de': 'Knoblauch'}),
          aisle: 'produce',
        ),
        IngredientNode(
          id: 'apple',
          name: LocalizedText({'en': 'apple', 'de': 'Apfel'}),
          aisle: 'produce',
        ),
      ],
    );

Recipe testRecipe({
  String id = 'doener-classic',
  String dishId = 'doener',
  String diet = 'classic',
  String effort = 'easy',
  String calorie = 'le600',
  Set<String> contains = const {},
  Set<String> attributes = const {'easy'},
  List<String> meal = const ['dinner'],
  int timeMinutes = 30,
  int calories = 520,
  List<RecipeIngredient> ingredients = const [
    RecipeIngredient(ingredientId: 'garlic', qty: 2, unit: 'clove'),
  ],
  int? timerMinutes,
}) {
  return Recipe(
    id: id,
    dishId: dishId,
    title: LocalizedText({'en': id, 'de': id}),
    caption: LocalizedText.empty,
    intro: LocalizedText.empty,
    variant: VariantCoords(diet: diet, effort: effort, calorie: calorie),
    contains: contains,
    attributes: attributes,
    meal: meal,
    timeMinutes: timeMinutes,
    servings: 2,
    caloriesPerServing: calories,
    macros: Macros(calories: calories, proteinG: 20, carbsG: 30, fatG: 10),
    ingredients: ingredients,
    steps: [
      RecipeStep(
        text: const LocalizedText({'en': 'cook it', 'de': 'kochen'}),
        timerMinutes: timerMinutes,
      ),
      const RecipeStep(text: LocalizedText({'en': 'eat', 'de': 'essen'})),
    ],
    tags: const LocalizedList({
      'en': ['street'],
      'de': ['Straße'],
    }),
  );
}

Profile veganProfile() => const Profile(
      name: 'ada',
      lang: 'en',
      avoidFlags: {'vegan'},
      preferredEffort: 'easy',
    );

HistoryEntry cooked(String id, DateTime at) =>
    HistoryEntry(recipeId: id, cookedAt: at);
