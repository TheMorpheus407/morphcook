import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/repository.dart';

class FixtureBundle extends CachingAssetBundle {
  final Map<String, dynamic> assets;
  final Map<String, int> reads = {};
  FixtureBundle(this.assets);
  @override
  Future<ByteData> load(String key) async {
    reads[key] = (reads[key] ?? 0) + 1;
    if (!assets.containsKey(key)) throw FlutterError('Missing fixture $key');
    return ByteData.sublistView(
      Uint8List.fromList(utf8.encode(jsonEncode(assets[key]))),
    );
  }
}

Map<String, dynamic> fixtureRecipe(String id) => {
  'id': id,
  'dish_id': 'dish',
  'title': {'en': 'Recipe $id', 'de': 'Rezept $id'},
  'ingredients': [],
  'steps': [],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'search normalization matches the corpus casefold and diacritic rules',
    () {
      expect(
        normalizeSearch('DÖNER, Kräuter & STRAẞE'),
        'doner krauter strasse',
      );
      expect(normalizeSearch('Crème brûlée'), 'creme brulee');
      expect(normalizeSearch('Do\u0308ner'), 'doner');
      expect(normalizeSearch('ＦＩＳＨ'), 'fish');
    },
  );

  test(
    'launch loads core and route loading deduplicates overlapping partitions',
    () async {
      final bundle = FixtureBundle({
        'assets/partition-manifest.json': {
          'partitions': [
            {
              'id': 'core',
              'file': 'core-recipes.json',
              'recipe_ids': ['a'],
            },
            {
              'id': 'extra',
              'file': 'extended-recipes.json',
              'recipe_ids': ['a', 'b'],
            },
          ],
        },
        'assets/dishes.json': [
          {
            'id': 'dish',
            'name': {'en': 'Dish'},
            'partition_id': 'extra',
            'variants': ['a', 'b'],
          },
        ],
        'assets/ingredients.json': [],
        'assets/ontology.json': {},
        'assets/faqs.json': [],
        'assets/ingredient-guide.json': [],
        'assets/core-recipes.json': [fixtureRecipe('a')],
        'assets/extended-recipes.json': [
          fixtureRecipe('a'),
          fixtureRecipe('b'),
        ],
        'assets/search-index.json': {
          'recipes': [
            {
              'id': 'b',
              'tokens': {
                'en': ['hidden', 'term'],
                'de': ['suchbegriff'],
              },
            },
          ],
        },
        'assets/ui-strings.json': {
          'Hello': {'en': 'Hello', 'de': 'Hallo', 'fr': 'Bonjour'},
        },
      });
      final repo = Repository(bundle: bundle);
      await repo.load();
      expect(repo.recipes.map((r) => r.id), ['a']);
      expect(repo.loadedPartitions, {'core'});
      expect(repo.uiStrings['Hello']!['fr'], 'Bonjour');
      expect(await repo.search('absent'), isEmpty);
      expect(bundle.reads['assets/extended-recipes.json'], isNull);
      await Future.wait([
        repo.search('hidden term'),
        repo.loadForDish(repo.dishes.single),
      ]);
      expect(repo.recipes.map((r) => r.id), ['a', 'b']);
      expect(bundle.reads['assets/extended-recipes.json'], 1);
      await repo.loadAll();
      expect(repo.recipes.length, 2);
      expect((await repo.search('hidden term')).single.id, 'b');
      expect((await repo.search('suchbegriff', lang: 'de')).single.id, 'b');
    },
  );

  test(
    'bundled corpus parses, resolves every reference and retains both languages',
    () async {
      final repo = Repository();
      await repo.load();
      final launchCount = repo.recipes.length;
      expect(launchCount, greaterThan(0));
      await repo.loadAll();
      expect(repo.recipes.length, greaterThanOrEqualTo(launchCount));
      expect(repo.recipes.map((r) => r.id).toSet().length, repo.recipes.length);
      expect(repo.dishes, isNotEmpty);
      expect(repo.faqs, isNotEmpty);
      expect(repo.guides, isNotEmpty);
      expect(
        (await repo.search('Döner', lang: 'de')).map((recipe) => recipe.dishId),
        everyElement('doener'),
      );
      expect(await repo.search('DÖNER', lang: 'de'), isNotEmpty);
      expect(await repo.search('KNOBLAUCH', lang: 'de'), isNotEmpty);
      for (final dish in repo.dishes) {
        expect(dish.name.keys, containsAll(['en', 'de']), reason: dish.id);
        for (final id in dish.variants) {
          expect(
            repo.byId(id)?.dishId,
            dish.id,
            reason: '$id linked from ${dish.id}',
          );
        }
      }
      for (final recipe in repo.recipes) {
        expect(recipe.title.keys, containsAll(['en', 'de']), reason: recipe.id);
        expect(
          recipe.description.keys,
          containsAll(['en', 'de']),
          reason: recipe.id,
        );
        expect(repo.dishById(recipe.dishId), isNotNull, reason: recipe.id);
        expect(recipe.ingredients, isNotEmpty, reason: recipe.id);
        expect(recipe.steps, isNotEmpty, reason: recipe.id);
        for (final ingredient in recipe.ingredients) {
          expect(
            repo.ingredientById(ingredient.id),
            isNotNull,
            reason: '${recipe.id}: ${ingredient.id}',
          );
          expect(ingredient.quantity, greaterThan(0));
        }
        for (final step in recipe.steps) {
          expect(step.text.keys, containsAll(['en', 'de']), reason: recipe.id);
        }
      }
    },
  );
}
