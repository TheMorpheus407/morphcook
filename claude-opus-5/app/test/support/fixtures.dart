import 'dart:convert';
import 'dart:io';

import 'package:morphcook/data/corpus_repository.dart';
import 'package:morphcook/data/local_store.dart';
import 'package:morphcook/domain/models.dart';
import 'package:morphcook/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads the real bundled corpus straight off disk. Tests that assert on the
/// shipped data should use this rather than a hand-rolled fake — the point is
/// to catch a bad corpus, not to prove a fixture parses.
Future<CorpusRepository> loadRealCorpus() async {
  final dir = Directory('assets/data');
  final files = <String, String>{};
  for (final entity in dir.listSync()) {
    if (entity is File && entity.path.endsWith('.json')) {
      files[entity.uri.pathSegments.last] = entity.readAsStringSync();
    }
  }
  final repo = CorpusRepository(source: MapAssetSource(files));
  await repo.initialise();
  await repo.loadAllPartitions();
  return repo;
}

Future<AppState> buildAppState({DateTime? now}) async {
  SharedPreferences.setMockInitialValues({});
  final repo = await loadRealCorpus();
  final state = AppState(
    repository: repo,
    profileStore: await ProfileStore.open(),
    collections: CollectionsStore(MemoryJsonStore()),
    clock: () => now ?? DateTime(2026, 7, 26, 12),
  );
  await state.initialise();
  return state;
}

/// A synthetic recipe for the algorithm tests, where a real one would drag in
/// irrelevant detail.
Recipe makeRecipe({
  required String id,
  String dishId = 'test-dish',
  Set<String> contains = const {},
  Set<String> attributes = const {},
  Set<String> ingredientIds = const {},
  String effort = 'medium',
  int timeMinutes = 30,
  int calories = 500,
  List<String> mealSlots = const ['dinner'],
  Map<String, String> axes = const {'diet': 'classic'},
  bool isDefault = false,
}) {
  return Recipe.fromJson({
    'id': id,
    'dish_id': dishId,
    'title': {'en': id, 'de': id},
    'blurb': {'en': '', 'de': ''},
    'handwritten': {'en': '', 'de': ''},
    'axes': {'effort': effort, ...axes},
    'contains': contains.toList(),
    'attributes': attributes.toList(),
    'techniques': <String>[],
    'effort': effort,
    'time_minutes': timeMinutes,
    'time_bucket': 't60',
    'servings': 2,
    'calories_per_serving': calories,
    'macros': {'protein_g': 10, 'carbs_g': 10, 'fat_g': 10},
    'meal_slots': mealSlots,
    'ingredients': [
      for (final i in ingredientIds)
        {'ingredient_id': i, 'qty': 1, 'unit': 'piece'},
    ],
    'ingredient_ids': ingredientIds.toList(),
    'steps': [
      {
        'text': {'en': 'a', 'de': 'a'},
      },
      {
        'text': {'en': 'b', 'de': 'b'},
      },
      {
        'text': {'en': 'c', 'de': 'c'},
      },
    ],
    'tips': <Object>[],
    'tags': <String>[],
    'stripe_color': '#C2703F',
    'is_dish_default': isDefault,
  });
}

Ontology testOntology() => Ontology.fromJson({
  'contains_flags': [
    {
      'id': 'dairy',
      'label': {'en': 'Dairy'},
      'category': 'animal',
      'eu_allergen': true,
    },
    {
      'id': 'gluten',
      'label': {'en': 'Gluten'},
      'category': 'grain',
      'eu_allergen': true,
    },
    {
      'id': 'pork',
      'label': {'en': 'Pork'},
      'category': 'meat',
      'eu_allergen': false,
    },
    {
      'id': 'alcohol',
      'label': {'en': 'Alcohol'},
      'category': 'other',
      'eu_allergen': false,
    },
    {
      'id': 'egg',
      'label': {'en': 'Egg'},
      'category': 'animal',
      'eu_allergen': true,
    },
  ],
  'compound_flags': [
    {
      'id': 'vegan',
      'label': {'en': 'Vegan'},
      'expands_to': ['dairy', 'egg', 'pork'],
      'note': {'en': ''},
    },
    {
      'id': 'halal',
      'label': {'en': 'Halal'},
      'expands_to': ['pork', 'alcohol'],
      'note': {'en': ''},
    },
  ],
  'attributes': {
    'effort': [
      {
        'id': 'easy',
        'label': {'en': 'easy'},
      },
      {
        'id': 'medium',
        'label': {'en': 'medium'},
      },
      {
        'id': 'hard',
        'label': {'en': 'hard'},
      },
    ],
    'time_bucket': [
      {
        'id': 't15',
        'max_minutes': 15,
        'label': {'en': '15'},
      },
      {
        'id': 't30',
        'max_minutes': 30,
        'label': {'en': '30'},
      },
      {
        'id': 't60',
        'max_minutes': 60,
        'label': {'en': '60'},
      },
      {
        'id': 't60plus',
        'max_minutes': 10000,
        'label': {'en': '60+'},
      },
    ],
    'calorie_bucket': [
      {
        'id': 'light',
        'max_kcal': 400,
        'label': {'en': 'light'},
      },
      {
        'id': 'balanced',
        'max_kcal': 600,
        'label': {'en': 'balanced'},
      },
      {
        'id': 'hearty',
        'max_kcal': 800,
        'label': {'en': 'hearty'},
      },
      {
        'id': 'feast',
        'max_kcal': 100000,
        'label': {'en': 'feast'},
      },
    ],
    'technique': <Object>[],
    'descriptor': [
      {
        'id': 'high-protein',
        'label': {'en': 'high protein'},
      },
      {
        'id': 'one-pot',
        'label': {'en': 'one pot'},
      },
    ],
  },
  'dimensions': [
    {
      'id': 'diet',
      'label': {'en': 'diet'},
      'note': {'en': ''},
    },
    {
      'id': 'effort',
      'label': {'en': 'effort'},
      'note': {'en': ''},
    },
  ],
  'axis_values': {
    'diet': [
      {
        'id': 'classic',
        'label': {'en': 'classic'},
      },
      {
        'id': 'vegan',
        'label': {'en': 'vegan'},
      },
    ],
  },
  'meal_slots': [
    {
      'id': 'breakfast',
      'label': {'en': 'breakfast'},
    },
    {
      'id': 'dinner',
      'label': {'en': 'dinner'},
    },
  ],
  'certification_note': {'en': ''},
});

IngredientDictionary testIngredients() => IngredientDictionary.fromJson({
  'nodes': [
    {
      'id': 'dairy',
      'parent': null,
      'label': {'en': 'Dairy'},
      'aisle': 'dairy',
      'unit_type': 'volume',
      'flags': ['dairy'],
    },
    {
      'id': 'cheese',
      'parent': 'dairy',
      'label': {'en': 'Cheese'},
      'aisle': 'dairy',
      'unit_type': 'mass',
      'flags': ['dairy'],
    },
    {
      'id': 'parmesan',
      'parent': 'cheese',
      'label': {'en': 'Parmesan'},
      'aisle': 'dairy',
      'unit_type': 'mass',
      'flags': ['dairy'],
    },
    {
      'id': 'feta',
      'parent': 'cheese',
      'label': {'en': 'Feta'},
      'aisle': 'dairy',
      'unit_type': 'mass',
      'flags': ['dairy'],
    },
    {
      'id': 'garlic',
      'parent': null,
      'label': {'en': 'Garlic'},
      'aisle': 'produce',
      'unit_type': 'count',
      'flags': <String>[],
    },
    {
      'id': 'olive-oil',
      'parent': null,
      'label': {'en': 'Olive oil'},
      'aisle': 'dry-goods',
      'unit_type': 'volume',
      'flags': <String>[],
    },
    {
      'id': 'apple',
      'parent': null,
      'label': {'en': 'Apple'},
      'aisle': 'produce',
      'unit_type': 'count',
      'flags': <String>[],
    },
  ],
  'aisles': [
    {
      'id': 'produce',
      'label': {'en': 'Fruit & veg'},
    },
    {
      'id': 'dairy',
      'label': {'en': 'Dairy'},
    },
    {
      'id': 'dry-goods',
      'label': {'en': 'Dry goods'},
    },
  ],
});

/// Reads a shipped asset directly, for the corpus-integrity checks.
Map<String, dynamic> readAsset(String name) =>
    (jsonDecode(readAssetRaw(name)) as Map).cast<String, dynamic>();

String readAssetRaw(String name) =>
    File('assets/data/$name').readAsStringSync();
