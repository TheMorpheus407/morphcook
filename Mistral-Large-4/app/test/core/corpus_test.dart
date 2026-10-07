import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart' hide Matcher;
import 'package:morphcook/core/corpus.dart';
import 'package:morphcook/core/matching.dart';
import 'package:morphcook/core/model/profile.dart';

/// Integration tests against the real bundled corpus in assets/. These mirror
/// the pipeline quality gate (pipeline/tests/validate_corpus.py) from the app
/// side: partition routing, search chunks, contains-flags consistency, diet
/// consistency, guide and FAQ integrity.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Corpus corpus;
  late Matcher matcher;

  setUpAll(() async {
    corpus = Corpus();
    await corpus.init();
    matcher = Matcher(ontology: corpus.ontology, ingredients: corpus.ingredients);
  });

  Future<Map<String, dynamic>> loadAssetJson(String path) async =>
      jsonDecode(await rootBundle.loadString(path)) as Map<String, dynamic>;

  group('partition manifest', () {
    test('declares version, strategy and five partitions', () {
      final m = corpus.manifest;
      expect(m.corpusVersion, 1);
      expect(m.loadingStrategy, 'launch-core-then-on-demand');
      expect(m.partitions.map((p) => p.id), [
        'core',
        'extended',
        'cuisine-italian',
        'cuisine-asian',
        'cuisine-middle-eastern',
      ]);
    });

    test('exactly the core partition loads at launch, and first', () {
      final m = corpus.manifest;
      expect(m.partitions.where((p) => p.loadsAtLaunch).map((p) => p.id), ['core']);
      expect(m.orderedPartitions.first.id, 'core');
      expect(m.orderedPartitions.first.type, 'core');
    });

    test('cross-references are symmetric', () {
      final refs = corpus.manifest.crossReferences;
      for (final entry in refs.entries) {
        for (final target in entry.value) {
          expect(refs[target], contains(entry.key),
              reason: '${entry.key} → $target must be symmetric');
        }
      }
    });

    test('core loads at launch; other partitions load on demand', () async {
      expect(corpus.loadedRecipesOfPartition('core'), isNotEmpty);
      expect(corpus.loadedRecipesOfPartition('extended'), isEmpty);
      final extended = await corpus.ensurePartition('extended');
      expect(extended, isNotEmpty);
      expect(corpus.loadedRecipesOfPartition('extended'), extended);
      // concurrent callers share one load
      final again = await corpus.ensurePartition('extended');
      expect(identical(again, extended), true);
    });

    test('unknown partitions throw', () {
      expect(() => corpus.ensurePartition('nope'), throwsStateError);
    });
  });

  group('partition routing', () {
    test('every dish routes to a known partition', () {
      final ids = corpus.manifest.partitions.map((p) => p.id).toSet();
      for (final dish in corpus.dishes) {
        expect(ids, contains(dish.partitionId), reason: dish.id);
        for (final sec in dish.secondaryPartitions) {
          expect(ids, contains(sec), reason: '${dish.id} → $sec');
        }
        expect(dish.frequencyTier, anyOf('core', 'extended'));
      }
    });

    test('manifest dish_ids match the dishes routed to each partition', () {
      for (final partition in corpus.manifest.partitions) {
        final routed = corpus.dishes
            .where((d) =>
                d.partitionId == partition.id || d.secondaryPartitions.contains(partition.id))
            .map((d) => d.id)
            .toSet();
        expect(partition.dishIds.toSet(), routed,
            reason: 'partition ${partition.id}');
      }
    });

    test('manifest recipe_ids are non-empty and unique per partition', () {
      for (final partition in corpus.manifest.partitions) {
        expect(partition.recipeIds, isNotEmpty, reason: partition.id);
        expect(partition.recipeIds.toSet().length, partition.recipeIds.length,
            reason: 'partition ${partition.id} has duplicate recipe ids');
      }
    });

    test('dishesInPartition includes secondary (cuisine) routing', () {
      final italian = corpus.dishesInPartition('cuisine-italian');
      expect(italian.map((d) => d.id), containsAll(['carbonara', 'fettuccine-alfredo', 'lasagne']));
    });
  });

  group('dish ↔ variant integrity', () {
    test('every dish’s variants resolve and match variant_ids', () async {
      for (final dish in corpus.dishes) {
        final recipes = await corpus.recipesOfDish(dish.id);
        expect(recipes.map((r) => r.id).toSet(), dish.variantIds.toSet(),
            reason: dish.id);
        for (final r in recipes) {
          expect(r.dishId, dish.id);
        }
      }
    });

    test('loadRecipe resolves every recipe id in the manifest', () async {
      for (final id in corpus.allRecipeIds) {
        final recipe = await corpus.loadRecipe(id);
        expect(recipe, isNotNull, reason: id);
        expect(corpus.dishIdOfRecipe(id), isNotNull, reason: id);
      }
    });

    test('unknown recipe ids resolve to null', () async {
      expect(await corpus.loadRecipe('ghost-recipe'), isNull);
      expect(corpus.loadedRecipe('ghost-recipe'), isNull);
    });
  });

  group('search chunks', () {
    final tokenPattern = RegExp(r'^[a-zäöüßà-ÿ0-9]+$');

    test('every partition has a chunk covering exactly its recipes', () async {
      for (final partition in corpus.manifest.partitions) {
        final doc = await loadAssetJson('assets/search/${partition.id}.json');
        final entries = (doc['entries'] as List).cast<Map<String, dynamic>>();
        final ids = entries.map((e) => e['recipe_id'] as String).toSet();
        expect(ids, partition.recipeIds.toSet(), reason: 'chunk ${partition.id}');
        for (final entry in entries) {
          final tokens = (entry['tokens'] as Map<String, dynamic>)
              .map((lang, value) => MapEntry(lang, (value as List).cast<String>()));
          expect(tokens.keys, containsAll(['en', 'de']));
          for (final langTokens in tokens.values) {
            expect(langTokens, isNotEmpty);
            for (final token in langTokens) {
              expect(token.length >= 2, true, reason: 'token "$token" too short');
              expect(tokenPattern.hasMatch(token), true,
                  reason: 'token "$token" not lowercase/word chars');
            }
          }
        }
      }
    });
  });

  group('corpus content consistency (raw JSON cross-check)', () {
    late Map<String, Set<String>> flagsById;
    late Map<String, Map<String, dynamic>> partitionDocs;

    setUpAll(() async {
      // Flatten the ingredient tree from raw JSON, keeping flags.
      final ingDoc =
          jsonDecode(await rootBundle.loadString('assets/ingredients.json'))
              as Map<String, dynamic>;
      flagsById = {};
      void walk(Map<String, dynamic> node) {
        flagsById[node['id'] as String] =
            (node['flags'] as List? ?? const []).cast<String>().toSet();
        for (final child in node['children'] as List? ?? const []) {
          walk(child as Map<String, dynamic>);
        }
      }

      for (final root in ingDoc['roots'] as List) {
        walk(root as Map<String, dynamic>);
      }

      partitionDocs = {};
      for (final partition in corpus.manifest.partitions) {
        partitionDocs[partition.id] = jsonDecode(
          await rootBundle.loadString('assets/${partition.file}'),
        ) as Map<String, dynamic>;
      }
    });

    test('recipe.contains equals the union of its ingredients’ flags', () {
      for (final entry in partitionDocs.entries) {
        for (final raw in entry.value['recipes'] as List) {
          final r = raw as Map<String, dynamic>;
          final derived = <String>{};
          for (final line in r['ingredients'] as List) {
            final id = (line as Map<String, dynamic>)['ingredient_id'] as String;
            derived.addAll(flagsById[id] ?? const {});
          }
          expect((r['contains'] as List).cast<String>().toSet(), derived,
              reason: '${r['id']} in ${entry.key}');
        }
      }
    });

    test('diet declarations agree with contains-flags', () {
      final veganFlags = corpus.ontology.expandAvoidFlags({'vegan'});
      final vegetarianFlags = corpus.ontology.expandAvoidFlags({'vegetarian'});
      for (final entry in partitionDocs.entries) {
        for (final raw in entry.value['recipes'] as List) {
          final r = raw as Map<String, dynamic>;
          final containsFlags = (r['contains'] as List).cast<String>().toSet();
          final diet = r['diet'] as String;
          if (diet == 'vegan') {
            expect(containsFlags.intersection(veganFlags), isEmpty,
                reason: '${r['id']} is vegan but contains animal flags');
          }
          if (diet == 'vegetarian') {
            expect(containsFlags.intersection(vegetarianFlags), isEmpty,
                reason: '${r['id']} is vegetarian but contains meat/fish');
          }
          if (diet == 'gluten-free') {
            expect(containsFlags.contains('gluten'), false,
                reason: '${r['id']} is gluten-free but contains gluten');
          }
          if (diet == 'vegan' || diet == 'vegetarian') {
            expect((r['attributes'] as List).cast<String>(), contains(diet),
                reason: '${r['id']} diet chip attribute missing');
          }
        }
      }
    });

    test('every recipe uses known ingredients, units and positive amounts', () {
      const units = {
        'g', 'kg', 'ml', 'l', 'tbsp', 'tsp',
        'clove', 'cloves', 'piece', 'pieces', 'slice', 'slices',
        'pinch', 'bunch', 'can', 'cans', 'pack', 'packs',
      };
      for (final entry in partitionDocs.entries) {
        for (final raw in entry.value['recipes'] as List) {
          final r = raw as Map<String, dynamic>;
          for (final line in r['ingredients'] as List) {
            final l = line as Map<String, dynamic>;
            expect(flagsById, contains(l['ingredient_id']),
                reason: '${r['id']} uses unknown ingredient ${l['ingredient_id']}');
            expect(units, contains(l['unit']),
                reason: '${r['id']} uses unknown unit ${l['unit']}');
            expect((l['amount'] as num).toDouble(), greaterThan(0));
          }
        }
      }
    });
  });

  group('ingredient guide (kitchen reference)', () {
    test('loads entries for known ingredients', () async {
      final guide = await corpus.loadIngredientGuide();
      expect(guide, isNotEmpty);
      for (final entry in guide.values) {
        expect(corpus.ingredients.find(entry.ingredientId), isNotNull,
            reason: 'guide entry ${entry.ingredientId} not in dictionary');
        expect(entry.name.resolve('en'), isNotEmpty);
        expect(entry.description.resolve('de'), isNotEmpty);
      }
    });

    test('entry lookup resolves exact ids and misses cleanly', () async {
      final nori = await corpus.loadIngredientGuideEntry('nori');
      expect(nori, isNotNull);
      expect(nori!.ingredientId, 'nori');
      expect(await corpus.loadIngredientGuideEntry('ghost-ingredient'), isNull);
    });
  });

  group('FAQ content', () {
    test('ships the deep-linked visibility entry and all five categories', () async {
      final doc = await loadAssetJson('assets/faqs.json');
      final entries = (doc['entries'] as List).cast<Map<String, dynamic>>();
      final ids = entries.map((e) => e['id'] as String).toSet();
      expect(ids, contains('visibility-why-hidden'));
      final categories = entries.map((e) => e['category'] as String).toSet();
      expect(categories,
          containsAll(['dietary', 'visibility', 'features', 'troubleshooting', 'privacy']));
      for (final entry in entries) {
        final question = entry['question'] as Map<String, dynamic>;
        final answer = entry['answer'] as Map<String, dynamic>;
        expect(question['en'], isNotEmpty);
        expect(question['de'], isNotEmpty);
        expect(answer['en'], isNotEmpty);
        expect(answer['de'], isNotEmpty);
      }
    });
  });

  group('matching over the real corpus', () {
    test('a vegan requirement picks the vegan variant of a dish', () async {
      final variants = await corpus.recipesOfDish('doener');
      final picked = matcher.pickBest(
        variants,
        const UserProfile(requiredAttributes: {'vegan'}),
      );
      expect(picked?.id, 'doener-vegan');
    });

    test('avoiding dairy hides the classic döner (yogurt sauce)', () async {
      final variants = await corpus.recipesOfDish('doener');
      final visible = matcher.visibleVariants(
        variants,
        const UserProfile(avoidFlags: {'dairy'}),
      );
      expect(visible.map((r) => r.id), isNot(contains('doener-classic')));
    });

    test('every dish has a pickable variant for a relaxed profile', () async {
      const relaxed = UserProfile(maxTimeMinutes: 999, calorieTarget: 600);
      for (final dish in corpus.dishes) {
        final variants = await corpus.recipesOfDish(dish.id);
        final picked = matcher.pickBest(variants, relaxed, ignoreCalorieTarget: true);
        expect(picked, isNotNull, reason: dish.id);
      }
    });
  });
}
