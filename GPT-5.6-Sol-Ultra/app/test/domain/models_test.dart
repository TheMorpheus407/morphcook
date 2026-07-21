import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/domain/domain.dart';

void main() {
  group('LocalizedText', () {
    test('normalizes regional locale and falls back predictably', () {
      final text = LocalizedText(const {'EN': 'hello', 'de': 'hallo'});

      expect(text.resolve('de-DE'), 'hallo');
      expect(text.resolve('fr-FR'), 'hello');
      expect(() => text.values['en'] = 'changed', throwsUnsupportedError);
    });

    test('accepts a legacy string without losing copy', () {
      expect(LocalizedText.fromJson('hello').resolve('de'), 'hello');
    });
  });

  test('UserProfile round-trips every matching and accessibility field', () {
    final profile = UserProfile(
      name: 'Mina',
      languageCode: 'de-DE',
      avoidFlags: const {'vegan', 'gluten'},
      avoidIngredientIds: const {'apple'},
      requiredAttributes: const {'halal'},
      maxTimeMinutes: 35,
      calorieTarget: 520,
      calorieTolerance: 90,
      preferredEffort: 'medium',
      showVariantTags: true,
      reduceMotion: false,
      visualAlertEnabled: false,
    );

    final restored = UserProfile.fromJson(profile.toJson());
    expect(restored, profile);
    expect(restored.languageCode, 'de');
    expect(() => restored.avoidFlags.add('pork'), throwsUnsupportedError);
    expect(restored.copyWith(reduceMotion: null).reduceMotion, isNull);
  });

  test('Recipe parses permissive JSON and scales ingredients', () {
    final recipe = Recipe.fromJson({
      'id': 'alfredo-vegan',
      'dish_id': 'alfredo',
      'names': {'en': 'Vegan Alfredo', 'de': 'Vegane Alfredo'},
      'descriptions': {'en': 'Silky', 'de': 'Seidig'},
      'variant_dimensions': {
        'diet': 'vegan',
        'effort': 'easy',
        'calorie_level': 'light',
      },
      'contains_flags': ['gluten'],
      'attributes': ['vegan'],
      'time_minutes': 25,
      'nutrition': {
        'calories': 480,
        'protein_g': 16,
        'carbs_g': 63,
        'fat_g': 19,
      },
      'servings': 2,
      'ingredients': [
        {'ingredient_id': 'parmesan', 'quantity': 40, 'unit': 'g'},
      ],
      'method': [
        {
          'instruction': {'en': 'Stir.', 'de': 'Rühren.'},
          'timer_seconds': 30,
        },
      ],
      'tags': ['pasta'],
      'partition_id': 'core',
    });

    expect(recipe.name.resolve('de'), 'Vegane Alfredo');
    expect(recipe.caloriesPerServing, 480);
    expect(recipe.steps.single.id, 'step-1');
    expect(recipe.ingredientsForServings(3).single.quantity, 60);
    expect(Recipe.fromJson(recipe.toJson()), recipe);
  });

  test('flat ingredient dictionaries become a traversable hierarchy', () {
    final dictionary = IngredientDictionary.fromJson({
      'ingredients': [
        {
          'id': 'dairy',
          'names': {'en': 'Dairy', 'de': 'Milch'},
        },
        {
          'id': 'cheese',
          'parent_id': 'dairy',
          'names': {'en': 'Cheese', 'de': 'Käse'},
        },
        {
          'id': 'feta',
          'parent_id': 'cheese',
          'names': {'en': 'Feta', 'de': 'Feta'},
        },
      ],
    });

    expect(dictionary.expandAvoidance(const ['dairy']), {
      'dairy',
      'cheese',
      'feta',
    });
    expect(dictionary.search('kä', languageCode: 'de').single.id, 'cheese');
  });

  test(
    'ontology retains additive dimensions, units, and category metadata',
    () {
      final ontology = Ontology.fromJson({
        'contains_flags': [
          {
            'id': 'dairy',
            'names': {'en': 'Dairy', 'de': 'Milch'},
            'category': 'allergen',
          },
        ],
        'attributes': {
          'time_bucket': [
            {
              'id': 'under-30',
              'names': {'en': 'Up to 30', 'de': 'Bis 30'},
              'max_minutes': 30,
            },
          ],
        },
        'variant_dimensions': {
          'effort': [
            {
              'id': 'easy',
              'names': {'en': 'Easy', 'de': 'Einfach'},
            },
          ],
        },
        'units': [
          {
            'id': 'tbsp',
            'symbol': {'en': 'tbsp', 'de': 'EL'},
            'kind': 'volume',
            'to_base': 15,
          },
        ],
        'ingredient_categories': [
          {
            'id': 'produce',
            'names': {'en': 'Produce', 'de': 'Obst & Gemüse'},
          },
        ],
      });

      expect(ontology.containsFlags['dairy']!.category, 'allergen');
      expect(ontology.dimensions['time_bucket']!.values.single.maxMinutes, 30);
      expect(
        ontology.dimensions['effort']!.values.single.name.resolve('de'),
        'Einfach',
      );
      expect(ontology.units['tbsp']!.toBase, 15);
      expect(ontology.ingredientCategories, contains('produce'));
    },
  );

  test('ingredient guide preserves multiple bilingual usage tips', () {
    final guide = IngredientGuideEntry.fromJson({
      'ingredient_id': 'miso',
      'names': {'en': 'Miso', 'de': 'Miso'},
      'description': {'en': 'Fermented paste.', 'de': 'Fermentierte Paste.'},
      'usage_tips': [
        {'en': 'Whisk gently.', 'de': 'Sanft einrühren.'},
        {'en': 'Do not boil.', 'de': 'Nicht kochen.'},
      ],
      'storage': {'en': 'Refrigerate.', 'de': 'Kühl lagern.'},
      'where_to_find': {'en': 'Asian aisle.', 'de': 'Asia-Regal.'},
    });

    expect(guide.usageTipItems, hasLength(2));
    expect(guide.usageTips.resolve('de'), contains('Nicht kochen'));
    expect(guide.toJson()['usage_tips'], isA<List<dynamic>>());
  });

  test('MealPlan reads and writes the human-readable backup week shape', () {
    final plan = MealPlan.fromJson({
      '2026-W16': {'mon.dinner': 'alfredo-vegan', 'sun.lunch': 'doener'},
    });

    expect(plan.entries, hasLength(2));
    expect(plan.entries.first.date.weekday, DateTime.monday);
    expect(plan.toBackupJson()['2026-W16']!['sun.lunch'], 'doener');

    final moved = plan.move(
      fromDate: plan.entries.first.date,
      fromSlot: MealSlot.dinner,
      toDate: plan.entries.first.date.add(const Duration(days: 1)),
      toSlot: MealSlot.lunch,
    );
    expect(moved.entries, hasLength(2));
    expect(
      moved.at(
        plan.entries.first.date.add(const Duration(days: 1)),
        MealSlot.lunch,
      ),
      isNotNull,
    );
  });
}
