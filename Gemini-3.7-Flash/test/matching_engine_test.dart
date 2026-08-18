import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/models/localized_string.dart';
import 'package:morphcook/models/ontology.dart';
import 'package:morphcook/models/ingredient_node.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/recipe.dart';
import 'package:morphcook/models/dish.dart';
import 'package:morphcook/models/cooking_history_item.dart';
import 'package:morphcook/services/matching_engine.dart';

void main() {
  group('MatchingEngine Algorithm Unit Tests', () {
    late Ontology ontology;
    late IngredientDictionary ingredientDict;

    setUp(() {
      final ontologyJson = {
        "contains_flags": [
          { "id": "pork", "label": { "en": "Pork", "de": "Schwein" } },
          { "id": "dairy", "label": { "en": "Dairy", "de": "Milch" } },
          { "id": "beef", "label": { "en": "Beef", "de": "Rind" } },
          { "id": "egg", "label": { "en": "Egg", "de": "Ei" } },
          { "id": "gluten", "label": { "en": "Gluten", "de": "Gluten" } },
          { "id": "peanuts", "label": { "en": "Peanuts", "de": "Erdnüsse" } },
          { "id": "tree-nuts", "label": { "en": "Tree Nuts", "de": "Baumnüsse" } },
          { "id": "alcohol", "label": { "en": "Alcohol", "de": "Alkohol" } },
          { "id": "gelatin-non-halal", "label": { "en": "Gelatin", "de": "Gelatine" } }
        ],
        "compound_avoid_flags": {
          "vegan": {
            "id": "vegan",
            "label": { "en": "Vegan", "de": "Vegan" },
            "description": { "en": "No animals", "de": "Keine Tiere" },
            "expands_to": ["pork", "beef", "dairy", "egg"]
          },
          "halal": {
            "id": "halal",
            "label": { "en": "Halal", "de": "Halal" },
            "description": { "en": "Halal compatible", "de": "Halal kompatibel" },
            "expands_to": ["pork", "alcohol", "gelatin-non-halal"]
          }
        },
        "attributes": {
          "effort": [
            { "id": "easy", "label": { "en": "Easy", "de": "Einfach" } },
            { "id": "medium", "label": { "en": "Medium", "de": "Mittel" } }
          ],
          "time_bucket": [],
          "calorie_bucket": [],
          "techniques": ["pan-fry", "bake"]
        }
      };
      ontology = Ontology.fromJson(ontologyJson);

      final ingredientTreeJson = [
        {
          "id": "dairy",
          "name": { "en": "Dairy", "de": "Milch" },
          "children": [
            {
              "id": "cow-milk",
              "name": { "en": "Cow Milk", "de": "Kuhmilch" },
              "children": [
                { "id": "whole-milk", "name": { "en": "Whole Milk", "de": "Vollmilch" } }
              ]
            },
            {
              "id": "cheese",
              "name": { "en": "Cheese", "de": "Käse" },
              "children": [
                { "id": "parmesan", "name": { "en": "Parmesan", "de": "Parmesan" } }
              ]
            }
          ]
        },
        {
          "id": "cilantro",
          "name": { "en": "Cilantro", "de": "Koriander" }
        }
      ];
      ingredientDict = IngredientDictionary.fromJsonList(ingredientTreeJson);
    });

    test('Vegan compound flag excludes meat and dairy recipes', () {
      final classicRecipe = Recipe(
        id: 'r1',
        dishId: 'd1',
        title: const LocalizedString({'en': 'Steak with Butter'}),
        description: const LocalizedString({'en': 'Delicious'}),
        variantDimensionValues: {'diet': 'classic'},
        servings: 2,
        prepTimeMinutes: 5,
        cookTimeMinutes: 10,
        totalTimeMinutes: 15,
        caloriesPerServing: 600,
        macros: const RecipeMacros(calories: 600, protein: 40, carbs: 10, fat: 30),
        contains: ['beef', 'dairy'],
        ingredientIds: ['beef', 'butter'],
        attributes: ['easy'],
        ingredients: [],
        steps: [],
      );

      final veganRecipe = Recipe(
        id: 'r2',
        dishId: 'd1',
        title: const LocalizedString({'en': 'Tofu Stir Fry'}),
        description: const LocalizedString({'en': 'Plant based'}),
        variantDimensionValues: {'diet': 'vegan'},
        servings: 2,
        prepTimeMinutes: 5,
        cookTimeMinutes: 10,
        totalTimeMinutes: 15,
        caloriesPerServing: 450,
        macros: const RecipeMacros(calories: 450, protein: 25, carbs: 40, fat: 12),
        contains: [],
        ingredientIds: ['tofu', 'vegetables'],
        attributes: ['easy'],
        ingredients: [],
        steps: [],
      );

      final veganProfile = UserProfile(
        avoidFlags: {'vegan'},
        maxTimeMinutes: 30,
        calorieTarget: 500,
      );

      final isClassicVisible = MatchingEngine.isRecipeVisible(
        recipe: classicRecipe,
        profile: veganProfile,
        ontology: ontology,
        ingredientDict: ingredientDict,
      );

      final isVeganVisible = MatchingEngine.isRecipeVisible(
        recipe: veganRecipe,
        profile: veganProfile,
        ontology: ontology,
        ingredientDict: ingredientDict,
      );

      expect(isClassicVisible, isFalse);
      expect(isVeganVisible, isTrue);
    });

    test('Ingredient tree propagation: avoiding parent excludes descendants', () {
      final parmesanRecipe = Recipe(
        id: 'r3',
        dishId: 'd2',
        title: const LocalizedString({'en': 'Pasta with Parmesan'}),
        description: const LocalizedString({'en': 'Cheese pasta'}),
        variantDimensionValues: {},
        servings: 2,
        prepTimeMinutes: 5,
        cookTimeMinutes: 10,
        totalTimeMinutes: 15,
        caloriesPerServing: 500,
        macros: const RecipeMacros(calories: 500, protein: 20, carbs: 60, fat: 15),
        contains: ['gluten'],
        ingredientIds: ['pasta', 'parmesan'],
        attributes: ['easy'],
        ingredients: [],
        steps: [],
      );

      // User avoids 'dairy' (parent of parmesan)
      final dairyFreeProfile = UserProfile(
        avoidIngredients: {'dairy'},
      );

      final isVisible = MatchingEngine.isRecipeVisible(
        recipe: parmesanRecipe,
        profile: dairyFreeProfile,
        ontology: ontology,
        ingredientDict: ingredientDict,
      );

      expect(isVisible, isFalse);
    });

    test('Time and calorie limits are respected strictly unless overridden', () {
      final longRecipe = Recipe(
        id: 'r4',
        dishId: 'd3',
        title: const LocalizedString({'en': 'Slow Roast'}),
        description: const LocalizedString({'en': 'Slow'}),
        variantDimensionValues: {},
        servings: 4,
        prepTimeMinutes: 20,
        cookTimeMinutes: 70,
        totalTimeMinutes: 90,
        caloriesPerServing: 950,
        macros: const RecipeMacros(calories: 950, protein: 50, carbs: 20, fat: 50),
        contains: [],
        ingredientIds: [],
        attributes: [],
        ingredients: [],
        steps: [],
      );

      final quickProfile = UserProfile(
        maxTimeMinutes: 45,
        calorieTarget: 500,
        calorieTolerance: 200, // Max allowed: 700 kcal
      );

      expect(
        MatchingEngine.isRecipeVisible(
          recipe: longRecipe,
          profile: quickProfile,
          ontology: ontology,
          ingredientDict: ingredientDict,
        ),
        isFalse,
      );

      // Even if calorie override is true, maxTimeMinutes still blocks it
      expect(
        MatchingEngine.isRecipeVisible(
          recipe: longRecipe,
          profile: quickProfile,
          ontology: ontology,
          ingredientDict: ingredientDict,
          overrideCalorieFilter: true,
        ),
        isFalse,
      );
    });

    test('Time-aware ranking bonuses (morning breakfast +200, evening dinner +90, weekend medium/hard +90)', () {
      final breakfastDish = Dish(
        id: 'd-pancakes',
        name: const LocalizedString({'en': 'Pancakes'}),
        heroText: const LocalizedString({'en': 'Fluffy'}),
        capCaption: const LocalizedString({'en': 'Stack'}),
        stripeColor: '#000',
        partitionId: 'core',
        secondaryPartitions: [],
        cuisineTags: ['breakfast'],
        frequencyTier: 'weekend',
        variantRecipeIds: ['r-pancakes'],
      );

      final breakfastRecipe = Recipe(
        id: 'r-pancakes',
        dishId: 'd-pancakes',
        title: const LocalizedString({'en': 'Classic Pancakes'}),
        description: const LocalizedString({'en': 'Pancakes'}),
        variantDimensionValues: {'effort': 'medium'},
        servings: 2,
        prepTimeMinutes: 5,
        cookTimeMinutes: 10,
        totalTimeMinutes: 15,
        caloriesPerServing: 400,
        macros: const RecipeMacros(calories: 400, protein: 10, carbs: 60, fat: 10),
        contains: [],
        ingredientIds: [],
        attributes: ['medium', 'breakfast'],
        ingredients: [],
        steps: [],
      );

      // Morning on a Saturday (8am, Saturday)
      final morningSaturday = DateTime(2026, 8, 15, 8, 30); // 8:30 AM, Saturday
      final bonusMorningSat = MatchingEngine.calculateTimeAwareBonus(
        recipe: breakfastRecipe,
        dish: breakfastDish,
        currentTime: morningSaturday,
      );

      // Should have breakfast bonus (+200) + weekend medium effort bonus (+90) = 290
      expect(bonusMorningSat, equals(290.0));
    });

    test('Staleness-aware ranking bonus (+50 for recipes not cooked in 30+ days)', () {
      final recipe = Recipe(
        id: 'r-dal',
        dishId: 'd-curry',
        title: const LocalizedString({'en': 'Lentil Dal'}),
        description: const LocalizedString({'en': 'Dal'}),
        variantDimensionValues: {},
        servings: 2,
        prepTimeMinutes: 5,
        cookTimeMinutes: 10,
        totalTimeMinutes: 15,
        caloriesPerServing: 350,
        macros: const RecipeMacros(calories: 350, protein: 20, carbs: 50, fat: 5),
        contains: [],
        ingredientIds: [],
        attributes: [],
        ingredients: [],
        steps: [],
      );

      final now = DateTime(2026, 8, 14);

      // Case 1: Cooked 40 days ago
      final oldHistory = [
        CookingHistoryItem(recipeId: 'r-dal', dishId: 'd-curry', cookedAt: DateTime(2026, 7, 1)),
      ];
      final bonusOld = MatchingEngine.calculateStalenessBonus(recipe: recipe, history: oldHistory, currentTime: now);
      expect(bonusOld, equals(50.0));

      // Case 2: Cooked 5 days ago
      final recentHistory = [
        CookingHistoryItem(recipeId: 'r-dal', dishId: 'd-curry', cookedAt: DateTime(2026, 8, 9)),
      ];
      final bonusRecent = MatchingEngine.calculateStalenessBonus(recipe: recipe, history: recentHistory, currentTime: now);
      expect(bonusRecent, equals(0.0));

      // Case 3: Never cooked
      final bonusNever = MatchingEngine.calculateStalenessBonus(recipe: recipe, history: [], currentTime: now);
      expect(bonusNever, equals(0.0));
    });
  });
}
