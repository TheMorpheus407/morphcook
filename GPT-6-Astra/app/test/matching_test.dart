import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/matching.dart';
import 'package:morphcook/core/models.dart';

Recipe recipe({
  String id = 'test',
  Set<String> contains = const {},
  Set<String> attributes = const {},
  List<RecipeIngredient> ingredients = const [],
  int minutes = 30,
  int calories = 600,
  String effort = 'easy',
  List<String> tags = const [],
}) => Recipe(
  id: id,
  dishId: 'dish',
  title: const {'en': 'Recipe'},
  contains: contains,
  attributes: attributes,
  ingredients: ingredients,
  timeMinutes: minutes,
  calories: calories,
  effort: effort,
  tags: tags,
);

const dictionary = [
  Ingredient(id: 'dairy', name: {'en': 'Dairy'}, flags: {'dairy'}),
  Ingredient(id: 'cow-milk', name: {'en': 'Cow milk'}, parentId: 'dairy'),
  Ingredient(
    id: 'whole-milk',
    name: {'en': 'Whole milk'},
    parentId: 'cow-milk',
  ),
  Ingredient(id: 'oat-milk', name: {'en': 'Oat milk'}),
];

void main() {
  group('dietary visibility', () {
    test('default profile accepts ordinary recipes', () {
      expect(visible(recipe(), Profile(), ingredients: dictionary), isTrue);
    });
    test('contains intersections reject, unrelated avoidance accepts', () {
      expect(
        visible(
          recipe(contains: {'dairy'}),
          Profile(avoidFlags: {'dairy'}),
          ingredients: dictionary,
        ),
        isFalse,
      );
      expect(
        visible(
          recipe(contains: {'dairy'}),
          Profile(avoidFlags: {'nuts'}),
          ingredients: dictionary,
        ),
        isTrue,
      );
    });
    test('vegan expands to all animal flags and includes honey', () {
      for (final flag in [
        'pork',
        'fish',
        'dairy',
        'egg',
        'honey',
        'shellfish',
      ]) {
        expect(
          visible(
            recipe(contains: {flag}),
            Profile(avoidFlags: {'vegan'}),
            ingredients: dictionary,
          ),
          isFalse,
          reason: flag,
        );
      }
    });
    test('pescatarian permits fish and excludes meat', () {
      expect(
        visible(
          recipe(contains: {'fish'}),
          Profile(avoidFlags: {'pescatarian'}),
          ingredients: dictionary,
        ),
        isTrue,
      );
      expect(
        visible(
          recipe(contains: {'beef'}),
          Profile(avoidFlags: {'pescatarian'}),
          ingredients: dictionary,
        ),
        isFalse,
      );
    });
    test('ontology additions and recursive compounds need no code change', () {
      final expanded = expandedAvoidFlags(
        {'new-diet'},
        {
          'compounds': {
            'new-diet': ['custom-class', 'vegan'],
            'custom-class': ['new-flag', 'new-diet'],
          },
        },
      );
      expect(expanded, containsAll(['new-flag', 'dairy', 'honey']));
    });
    test('parent avoidance propagates through multiple generations', () {
      final milk = recipe(
        ingredients: [
          const RecipeIngredient(id: 'whole-milk', quantity: 50, unit: 'ml'),
        ],
      );
      expect(
        visible(
          milk,
          Profile(avoidIngredients: {'dairy'}),
          ingredients: dictionary,
        ),
        isFalse,
      );
      expect(
        visible(
          milk,
          Profile(avoidIngredients: {'cow-milk'}),
          ingredients: dictionary,
        ),
        isFalse,
      );
      expect(
        visible(
          milk,
          Profile(avoidIngredients: {'oat-milk'}),
          ingredients: dictionary,
        ),
        isTrue,
      );
    });
    test(
      'ingredient class flags are inherited even when recipe flag is missing',
      () {
        expect(
          visible(
            recipe(
              ingredients: [
                const RecipeIngredient(
                  id: 'whole-milk',
                  quantity: 50,
                  unit: 'ml',
                ),
              ],
            ),
            Profile(avoidFlags: {'dairy'}),
            ingredients: dictionary,
          ),
          isFalse,
        );
      },
    );
    test('hierarchy cycles terminate', () {
      expect(
        ingredientAncestors('a', const [
          Ingredient(id: 'a', name: {}, parentId: 'b'),
          Ingredient(id: 'b', name: {}, parentId: 'a'),
        ]),
        {'a', 'b'},
      );
    });
    test('all required positive attributes must be present', () {
      final profile = Profile(requiredAttributes: {'halal', 'bake'});
      expect(
        visible(recipe(attributes: {'halal'}), profile, ingredients: []),
        isFalse,
      );
      expect(
        visible(
          recipe(attributes: {'halal', 'bake', 'easy'}),
          profile,
          ingredients: [],
        ),
        isTrue,
      );
    });
    test('time and calorie boundaries are inclusive', () {
      final profile = Profile(
        maxTimeMinutes: 30,
        calorieTarget: 500,
        calorieTolerance: 100,
      );
      expect(
        visible(recipe(minutes: 30, calories: 600), profile, ingredients: []),
        isTrue,
      );
      expect(
        visible(recipe(minutes: 31, calories: 500), profile, ingredients: []),
        isFalse,
      );
      expect(visible(recipe(calories: 601), profile, ingredients: []), isFalse);
      expect(visible(recipe(calories: 399), profile, ingredients: []), isFalse);
    });
    test('dish calorie override preserves allergy and time filters', () {
      final profile = Profile(avoidFlags: {'nuts'}, maxTimeMinutes: 30);
      expect(
        visible(
          recipe(calories: 1500),
          profile,
          ingredients: [],
          ignoreCalories: true,
        ),
        isTrue,
      );
      expect(
        visible(
          recipe(calories: 1500, contains: {'peanuts'}),
          profile,
          ingredients: [],
          ignoreCalories: true,
        ),
        isFalse,
      );
      expect(
        visible(
          recipe(calories: 1500, minutes: 31),
          profile,
          ingredients: [],
          ignoreCalories: true,
        ),
        isFalse,
      );
    });
  });

  group('ranking', () {
    final profile = Profile();
    final monday = DateTime(2026, 9, 7, 12);
    test('effort preference dominates time then calories break ties', () {
      expect(
        rankRecipe(recipe(effort: 'easy', minutes: 10), profile, now: monday),
        greaterThan(
          rankRecipe(recipe(effort: 'hard', minutes: 60), profile, now: monday),
        ),
      );
      expect(
        rankRecipe(recipe(minutes: 60, calories: 500), profile, now: monday),
        greaterThan(
          rankRecipe(recipe(minutes: 59, calories: 600), profile, now: monday),
        ),
      );
    });
    test('breakfast bonus only applies from 05:00 through 10:59', () {
      final breakfast = recipe(tags: ['breakfast']);
      final baseline = rankRecipe(breakfast, profile, now: monday);
      expect(
        rankRecipe(breakfast, profile, now: DateTime(2026, 9, 7, 5)) - baseline,
        200,
      );
      expect(
        rankRecipe(breakfast, profile, now: DateTime(2026, 9, 7, 10, 59)) -
            baseline,
        200,
      );
      expect(
        rankRecipe(breakfast, profile, now: DateTime(2026, 9, 7, 11)),
        baseline,
      );
    });
    test('dinner bonus applies in evening', () {
      final dinner = recipe(tags: ['dinner']);
      expect(
        rankRecipe(dinner, profile, now: DateTime(2026, 9, 7, 17)) -
            rankRecipe(dinner, profile, now: monday),
        90,
      );
      expect(
        rankRecipe(dinner, profile, now: DateTime(2026, 9, 7, 21)),
        rankRecipe(dinner, profile, now: monday),
      );
    });
    test('weekend bonus applies only to medium and hard effort', () {
      for (final effort in ['easy', 'medium', 'hard']) {
        expect(
          rankRecipe(
                recipe(effort: effort),
                profile,
                now: DateTime(2026, 9, 12, 12),
              ) -
              rankRecipe(recipe(effort: effort), profile, now: monday),
          effort == 'easy' ? 0 : 90,
        );
      }
    });
    test('staleness uses latest cook and never-cooked gets no bonus', () {
      final r = recipe();
      final baseline = rankRecipe(r, profile, now: monday);
      final old = {
        'recipe_id': r.id,
        'cooked_at': monday
            .subtract(const Duration(days: 30))
            .toIso8601String(),
      };
      final recent = {
        'recipe_id': r.id,
        'cooked_at': monday.subtract(const Duration(days: 2)).toIso8601String(),
      };
      expect(
        rankRecipe(r, profile, now: monday, history: [old]),
        baseline + 50,
      );
      expect(
        rankRecipe(r, profile, now: monday, history: [old, recent]),
        baseline,
      );
    });
    test('best variant is stable and never returns an excluded recipe', () {
      final selected = bestVariant(
        [
          recipe(id: 'a', contains: {'dairy'}),
          recipe(id: 'b'),
        ],
        Profile(avoidFlags: {'dairy'}),
        ingredients: [],
        now: monday,
      );
      expect(selected?.id, 'b');
      expect(
        bestVariant(
          [
            recipe(contains: {'dairy'}),
          ],
          Profile(avoidFlags: {'dairy'}),
          ingredients: [],
        ),
        isNull,
      );
    });
  });
}
