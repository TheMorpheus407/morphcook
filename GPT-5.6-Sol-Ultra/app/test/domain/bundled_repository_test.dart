import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/data.dart';
import 'package:morphcook/domain/domain.dart';

void main() {
  late Map<String, String> assets;
  late BundledRecipeRepository repository;

  setUp(() {
    assets = _fixtureAssets();
    repository = BundledRecipeRepository(
      assetLoader: (path) async {
        final value = assets[path];
        if (value == null) throw StateError('missing $path');
        return value;
      },
    );
  });

  test('initialization loads metadata and only launch partitions', () async {
    await repository.initialize();

    expect(repository.dishes, hasLength(1));
    expect(repository.recipes.map((recipe) => recipe.id), ['toast-core']);
    expect(repository.loadedPartitionIds, {'core'});
    expect(repository.ingredients['bread'], isNotNull);
    expect(repository.ingredientGuideFor('bread'), isNotNull);
    expect(repository.faqs.single.question.resolve('de'), contains('Rezepte'));
  });

  test('dish loading follows secondary partition routing', () async {
    await repository.initialize();

    final variants = await repository.loadRecipesForDish('toast');

    expect(variants.map((recipe) => recipe.id).toSet(), {
      'toast-core',
      'toast-extended',
    });
    expect(repository.loadedPartitionIds, {'core', 'extended'});
    expect((await repository.variantsForDish('toast')).recipes, hasLength(2));
  });

  test(
    'coalesces concurrent requests for the same deferred partition',
    () async {
      await repository.initialize();

      await Future.wait([
        repository.ensurePartitionLoaded('extended'),
        repository.ensurePartitionLoaded('extended'),
        repository.ensurePartitionLoaded('extended'),
      ]);

      expect(
        repository.recipes.where((recipe) => recipe.id == 'toast-extended'),
        hasLength(1),
      );
      expect(
        repository.validateIntegrity().issues.where(
          (issue) => issue.code == 'duplicate-recipe',
        ),
        isEmpty,
      );
    },
  );

  test('search loads deferred content on demand and tracks gaps', () async {
    await repository.initialize();
    final profile = UserProfile(
      name: 'Tess',
      maxTimeMinutes: 90,
      calorieTarget: 500,
      calorieTolerance: 500,
    );

    final found = await repository.search(
      SearchQuery(text: 'weekend'),
      profile,
    );
    final missing = await repository.search(
      SearchQuery(text: 'sushi'),
      profile,
    );

    expect(found.items.single.recipe.id, 'toast-extended');
    expect(repository.loadedPartitionIds, {'core', 'extended'});
    expect(missing.items, isEmpty);
    expect(repository.contentGapTracker.requests.single.query, 'sushi');
  });

  test('FAQ search respects category and German tokens', () async {
    await repository.initialize();

    expect(
      repository.searchFaqs('unsichtbar', languageCode: 'de').single.id,
      'visibility',
    );
    expect(
      repository.searchFaqs(
        'unsichtbar',
        languageCode: 'de',
        category: 'troubleshooting',
      ),
      isEmpty,
    );
  });

  test(
    'integrity validator catches unknown flags and ingredient links',
    () async {
      final core = jsonDecode(assets['assets/core-recipes.json']!) as Map;
      final recipe = (core['recipes'] as List).single as Map;
      recipe['contains'] = ['mystery-allergen'];
      (recipe['ingredients'] as List).add({
        'ingredient_id': 'moon-dust',
        'quantity': 1,
        'unit': 'g',
      });
      assets['assets/core-recipes.json'] = jsonEncode(core);

      await repository.initialize(loadExtended: true);
      final report = repository.validateIntegrity();

      expect(report.isValid, isFalse);
      expect(
        report.issues.map((issue) => issue.code),
        containsAll({'unknown-contains-flag', 'missing-ingredient'}),
      );
    },
  );

  test('malformed assets fail with an actionable path', () async {
    assets['assets/ontology.json'] = '{nope';

    await expectLater(
      repository.initialize(),
      throwsA(
        isA<CorpusLoadException>()
            .having(
              (error) => error.assetPath,
              'assetPath',
              'assets/ontology.json',
            )
            .having((error) => error.message, 'message', 'Invalid JSON.'),
      ),
    );
  });
}

Map<String, String> _fixtureAssets() {
  final recipeBase = {
    'dish_id': 'toast',
    'description': {'en': 'Warm and crisp.', 'de': 'Warm und knusprig.'},
    'contains': ['gluten'],
    'attributes': <String>[],
    'time_minutes': 15,
    'calories_per_serving': 430,
    'servings': 2,
    'nutrition': {'calories': 430, 'protein_g': 12, 'carbs_g': 55, 'fat_g': 16},
    'ingredients': [
      {'ingredient_id': 'bread', 'quantity': 2, 'unit': 'slice'},
    ],
    'steps': [
      {
        'id': 'toast',
        'text': {'en': 'Toast.', 'de': 'Toasten.'},
      },
    ],
    'meal_types': ['breakfast'],
    'cuisine_tags': ['european'],
  };

  return {
    'assets/search-index.json': jsonEncode({
      'schema_version': 1,
      'content_version': 'test-1',
      'partitions': [
        {
          'partition_id': 'core',
          'tags': ['quick'],
          'cuisine_tags': ['european'],
          'meal_types': ['breakfast'],
          'text': {'en': 'weekday toast bread', 'de': 'alltagstoast brot'},
        },
        {
          'partition_id': 'extended',
          'tags': ['weekend'],
          'cuisine_tags': ['european'],
          'meal_types': ['breakfast'],
          'text': {'en': 'weekend toast bread', 'de': 'wochenendtoast brot'},
        },
      ],
    }),
    'assets/partition-manifest.json': jsonEncode({
      'schema_version': 1,
      'content_version': 'test-1',
      'core_partition_id': 'core',
      'partitions': [
        {
          'id': 'core',
          'asset': 'core-recipes.json',
          'kind': 'core',
          'load_at_launch': true,
          'priority': 0,
        },
        {
          'id': 'extended',
          'asset': 'extended-recipes.json',
          'kind': 'extended',
          'priority': 10,
        },
      ],
    }),
    'assets/dishes.json': jsonEncode({
      'schema_version': 1,
      'dishes': [
        {
          'id': 'toast',
          'canonical_name': {'en': 'Toast', 'de': 'Toast'},
          'hero_text': {'en': 'Good toast.', 'de': 'Guter Toast.'},
          'caption': {'en': 'crisp mornings', 'de': 'knusprige Morgen'},
          'stripe_color': '#D6A85F',
          'variant_recipe_ids': ['toast-core', 'toast-extended'],
          'partition_id': 'core',
          'secondary_partitions': ['extended'],
          'cuisine_tags': ['european'],
          'frequency_tier': 'core',
        },
      ],
    }),
    'assets/ontology.json': jsonEncode({
      'schema_version': 1,
      'contains_flags': [
        {
          'id': 'gluten',
          'names': {'en': 'Gluten', 'de': 'Gluten'},
        },
      ],
      'compound_avoid_flags': <Object>[],
      'variant_dimensions': {
        'diet': [
          {
            'id': 'classic',
            'names': {'en': 'Classic', 'de': 'Klassisch'},
          },
        ],
      },
    }),
    'assets/ingredients.json': jsonEncode({
      'schema_version': 1,
      'ingredients': [
        {
          'id': 'bread',
          'names': {'en': 'Bread', 'de': 'Brot'},
          'contains_flags': ['gluten'],
          'aisle': 'bakery',
        },
      ],
    }),
    'assets/ingredient-guide.json': jsonEncode({
      'entries': [
        {
          'ingredient_id': 'bread',
          'description': {'en': 'A good loaf.', 'de': 'Ein gutes Brot.'},
          'usage_tips': {'en': 'Toast it.', 'de': 'Toasten.'},
          'storage': {'en': 'Keep cool.', 'de': 'Kühl lagern.'},
          'where_to_find': {'en': 'Bakery.', 'de': 'Bäckerei.'},
        },
      ],
    }),
    'assets/faqs.json': jsonEncode({
      'faqs': [
        {
          'id': 'visibility',
          'category': 'matching',
          'question': {
            'en': 'Why are recipes hidden?',
            'de': 'Warum sind Rezepte unsichtbar?',
          },
          'answer': {
            'en': 'Your hard preferences are respected.',
            'de': 'Deine festen Wünsche werden beachtet.',
          },
          'keywords': {
            'en': ['hidden'],
            'de': ['unsichtbar'],
          },
        },
      ],
    }),
    'assets/core-recipes.json': jsonEncode({
      'schema_version': 1,
      'partition_id': 'core',
      'recipes': [
        {
          ...recipeBase,
          'id': 'toast-core',
          'name': {'en': 'Weekday toast', 'de': 'Alltagstoast'},
          'variant_dimensions': {
            'diet': 'classic',
            'effort': 'easy',
            'calorie_level': 'balanced',
          },
          'tags': ['quick'],
          'partition_id': 'core',
        },
      ],
    }),
    'assets/extended-recipes.json': jsonEncode({
      'schema_version': 1,
      'partition_id': 'extended',
      'recipes': [
        {
          ...recipeBase,
          'id': 'toast-extended',
          'name': {'en': 'Weekend toast', 'de': 'Wochenendtoast'},
          'variant_dimensions': {
            'diet': 'classic',
            'effort': 'medium',
            'calorie_level': 'balanced',
          },
          'tags': ['weekend'],
          'partition_id': 'extended',
        },
      ],
    }),
  };
}
