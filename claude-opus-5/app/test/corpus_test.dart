import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/corpus_repository.dart';
import 'package:morphcook/domain/matching.dart';
import 'package:morphcook/domain/profile.dart';

import 'support/fixtures.dart';

/// Integrity checks against the corpus that actually ships. These are the same
/// gates the build script enforces, re-run on the emitted JSON so a hand-edit
/// cannot slip past.
void main() {
  late CorpusRepository repo;

  setUpAll(() async => repo = await loadRealCorpus());

  group('shape', () {
    test('the corpus is not trivially small', () {
      expect(repo.dishes.length, greaterThanOrEqualTo(20));
      expect(repo.loadedRecipes.length, greaterThanOrEqualTo(80));
    });

    test('every dish resolves every recipe it claims', () {
      for (final dish in repo.dishes) {
        expect(
          dish.recipeIds,
          isNotEmpty,
          reason: '${dish.id} has no variants',
        );
        for (final id in dish.recipeIds) {
          expect(
            repo.recipe(id),
            isNotNull,
            reason: '$id missing from partitions',
          );
        }
      }
    });

    test('every recipe points back at a real dish', () {
      for (final recipe in repo.loadedRecipes) {
        expect(repo.dish(recipe.dishId), isNotNull, reason: recipe.id);
      }
    });

    test('every dish offers at least three variants', () {
      for (final dish in repo.dishes) {
        expect(dish.recipeIds.length, greaterThanOrEqualTo(3), reason: dish.id);
      }
    });

    test('exactly one authored default per dish', () {
      for (final dish in repo.dishes) {
        final defaults = repo
            .variantsOf(dish.id)
            .where((r) => r.isDishDefault)
            .length;
        expect(defaults, 1, reason: dish.id);
      }
    });
  });

  group('bilingual completeness', () {
    test('every dish carries German and English', () {
      for (final dish in repo.dishes) {
        for (final lang in ['en', 'de']) {
          expect(dish.name(lang), isNotEmpty, reason: '${dish.id} name/$lang');
          expect(dish.hero(lang), isNotEmpty, reason: '${dish.id} hero/$lang');
          expect(
            dish.capCaption(lang),
            isNotEmpty,
            reason: '${dish.id} cap/$lang',
          );
        }
        expect(dish.name('en'), isNot(dish.hero('en')));
      }
    });

    test('every recipe carries German and English throughout', () {
      for (final recipe in repo.loadedRecipes) {
        for (final lang in ['en', 'de']) {
          expect(recipe.title(lang), isNotEmpty, reason: '${recipe.id}/$lang');
          expect(recipe.blurb(lang), isNotEmpty, reason: '${recipe.id}/$lang');
          expect(
            recipe.handwritten(lang),
            isNotEmpty,
            reason: '${recipe.id}/$lang',
          );
          for (var i = 0; i < recipe.steps.length; i++) {
            expect(
              recipe.steps[i].text(lang),
              isNotEmpty,
              reason: '${recipe.id} step $i/$lang',
            );
          }
        }
      }
    });

    test('German text is genuinely different from English', () {
      // A copy-paste fallback would make the two identical everywhere.
      var identical = 0;
      for (final recipe in repo.loadedRecipes) {
        if (recipe.blurb('en') == recipe.blurb('de')) identical++;
      }
      expect(identical, 0);
    });

    test('every ingredient and flag is labelled in both languages', () {
      for (final node in repo.ingredients.nodes.values) {
        for (final lang in ['en', 'de']) {
          expect(node.label(lang), isNotEmpty, reason: '${node.id}/$lang');
        }
      }
      for (final flag in repo.ontology.containsFlags.values) {
        for (final lang in ['en', 'de']) {
          expect(flag.label(lang), isNotEmpty, reason: '${flag.id}/$lang');
        }
      }
    });
  });

  group('referential integrity', () {
    test('every ingredient id in every recipe resolves', () {
      for (final recipe in repo.loadedRecipes) {
        for (final item in recipe.ingredients) {
          expect(
            repo.ingredients[item.ingredientId],
            isNotNull,
            reason: '${recipe.id} → ${item.ingredientId}',
          );
        }
      }
    });

    test('every contains-flag exists in the ontology', () {
      for (final recipe in repo.loadedRecipes) {
        for (final flag in recipe.contains) {
          expect(
            repo.ontology.containsFlags.containsKey(flag),
            isTrue,
            reason: '${recipe.id} → $flag',
          );
        }
      }
    });

    test('every ingredient parent resolves', () {
      for (final node in repo.ingredients.nodes.values) {
        final parent = node.parent;
        if (parent != null) {
          expect(repo.ingredients[parent], isNotNull, reason: node.id);
        }
      }
    });

    test('every compound flag expands only to real contains-flags', () {
      for (final compound in repo.ontology.compoundFlags.values) {
        for (final flag in compound.expandsTo) {
          expect(
            repo.ontology.containsFlags.containsKey(flag),
            isTrue,
            reason: '${compound.id} → $flag',
          );
        }
      }
    });

    test('the ingredient guide only references real ingredients', () {
      final guide = readAsset('ingredient-guide.json');
      for (final raw in (guide['entries'] as List)) {
        final id = (raw as Map)['ingredient_id'] as String;
        expect(repo.ingredients[id], isNotNull, reason: id);
      }
    });

    test('every FAQ relation points at a real entry', () {
      for (final entry in repo.faqs.entries) {
        for (final id in entry.related) {
          expect(repo.faqs.byId(id), isNotNull, reason: '${entry.id} → $id');
        }
        expect(
          repo.faqs.categories.any((c) => c.id == entry.category),
          isTrue,
          reason: '${entry.id} category ${entry.category}',
        );
      }
    });

    test('FAQ anchors are unique so contextual links are unambiguous', () {
      final anchors = repo.faqs.entries.map((e) => e.anchor).toList();
      expect(anchors.toSet().length, anchors.length);
    });
  });

  group('flag correctness', () {
    test('contains ⊇ the flags derivable from the ingredients', () {
      for (final recipe in repo.loadedRecipes) {
        final derived = <String>{};
        for (final item in recipe.ingredients) {
          derived.addAll(
            repo.ingredients[item.ingredientId]?.flags ?? const {},
          );
        }
        expect(
          derived.difference(recipe.contains),
          isEmpty,
          reason: '${recipe.id} under-declares its contains',
        );
      }
    });

    test('a recipe on a diet axis satisfies that diet', () {
      for (final recipe in repo.loadedRecipes) {
        final diet = recipe.axes['diet'];
        final compound = repo.ontology.compoundFlags[diet];
        if (compound == null) continue;
        expect(
          compound.expandsTo.intersection(recipe.contains),
          isEmpty,
          reason: '${recipe.id} claims $diet but contradicts it',
        );
      }
    });

    test('a vegan recipe never carries an animal flag', () {
      const animal = {
        'pork',
        'beef',
        'lamb',
        'poultry',
        'fish',
        'dairy',
        'egg',
        'honey',
      };
      for (final recipe in repo.loadedRecipes) {
        if (recipe.axes['diet'] != 'vegan') continue;
        expect(
          recipe.contains.intersection(animal),
          isEmpty,
          reason: recipe.id,
        );
      }
    });

    test('a gluten-free recipe never carries gluten', () {
      for (final recipe in repo.loadedRecipes) {
        if (recipe.axes['diet'] != 'gluten-free') continue;
        expect(recipe.contains, isNot(contains('gluten')), reason: recipe.id);
      }
    });

    test('the derived attributes agree with the contains set', () {
      for (final recipe in repo.loadedRecipes) {
        for (final compound in repo.ontology.compoundFlags.values) {
          final claimed = recipe.attributes.contains(compound.id);
          final actual = compound.expandsTo
              .intersection(recipe.contains)
              .isEmpty;
          expect(
            claimed,
            actual,
            reason:
                '${recipe.id}: ${compound.id} claimed=$claimed actual=$actual',
          );
        }
      }
    });
  });

  group('per-recipe sanity', () {
    test('nothing has zero steps, zero time or zero calories', () {
      for (final recipe in repo.loadedRecipes) {
        expect(recipe.steps.length, greaterThanOrEqualTo(3), reason: recipe.id);
        expect(recipe.timeMinutes, greaterThan(0), reason: recipe.id);
        expect(recipe.caloriesPerServing, greaterThan(0), reason: recipe.id);
        expect(recipe.servings, greaterThan(0), reason: recipe.id);
        expect(recipe.ingredients, isNotEmpty, reason: recipe.id);
      }
    });

    test('the calorie bucket matches the calorie count', () {
      final buckets = repo.ontology.calorieBuckets.map((b) => b.id).toList();
      for (final recipe in repo.loadedRecipes) {
        final level = recipe.axes['calorie_level'];
        expect(buckets, contains(level), reason: recipe.id);
        final expected = switch (recipe.caloriesPerServing) {
          <= 400 => 'light',
          <= 600 => 'balanced',
          <= 800 => 'hearty',
          _ => 'feast',
        };
        expect(level, expected, reason: recipe.id);
      }
    });

    test('effort and axes agree', () {
      for (final recipe in repo.loadedRecipes) {
        expect(recipe.axes['effort'], recipe.effort, reason: recipe.id);
      }
    });

    test('no two variants of a dish occupy the same axis cell', () {
      for (final dish in repo.dishes) {
        final cells = <String>{};
        for (final r in repo.variantsOf(dish.id)) {
          final key =
              (r.axes.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
                  .map((e) => '${e.key}=${e.value}')
                  .join('|');
          expect(cells.add(key), isTrue, reason: '${dish.id} duplicates $key');
        }
      }
    });

    test('recipe ids are unique across the whole corpus', () {
      final ids = repo.loadedRecipes.map((r) => r.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('partitioning', () {
    test('the manifest routes every dish to a partition that contains it', () {
      for (final dish in repo.dishes) {
        final partitions = repo.manifest.partitionsFor(dish.id);
        expect(partitions, isNotEmpty, reason: dish.id);
        for (final id in partitions) {
          final info = repo.manifest.byId(id);
          expect(info, isNotNull, reason: '$id from ${dish.id}');
          expect(info!.dishIds, contains(dish.id));
        }
      }
    });

    test('the core partition is the only eager one', () {
      final eager = repo.manifest.partitions.where((p) => p.isEager).toList();
      expect(eager, hasLength(1));
      expect(eager.single.id, 'core');
    });

    test('core and extended together hold every recipe exactly once', () {
      final counted = <String>{};
      for (final id in ['core', 'extended']) {
        for (final dishId in repo.manifest.byId(id)!.dishIds) {
          for (final recipeId in repo.dish(dishId)!.recipeIds) {
            expect(counted.add(recipeId), isTrue, reason: recipeId);
          }
        }
      }
      expect(counted.length, repo.loadedRecipes.length);
    });

    test('a lazy load pulls in the dish it was asked for', () async {
      final lazyRepo = await _freshRepo();
      final extended = lazyRepo.manifest.byId('extended')!;
      final dishId = extended.dishIds.first;
      expect(lazyRepo.variantsOf(dishId), isEmpty);
      await lazyRepo.ensureDishLoaded(dishId);
      expect(lazyRepo.variantsOf(dishId), isNotEmpty);
    });

    test('the core partition is resident straight after initialise', () async {
      final lazyRepo = await _freshRepo();
      expect(lazyRepo.loadedPartitions, contains('core'));
      final coreDish = lazyRepo.manifest.byId('core')!.dishIds.first;
      expect(lazyRepo.variantsOf(coreDish), isNotEmpty);
    });
  });

  group('search index', () {
    test('every indexed id resolves to a real recipe', () async {
      final tokens = await repo.searchTokens('en');
      expect(tokens, isNotEmpty);
      for (final entry in tokens.entries.take(200)) {
        for (final id in entry.value) {
          expect(repo.recipe(id), isNotNull, reason: '${entry.key} → $id');
        }
      }
    });

    test('both languages are indexed', () async {
      expect(await repo.searchTokens('en'), isNotEmpty);
      expect(await repo.searchTokens('de'), isNotEmpty);
    });

    test('a dish name finds its own recipes', () async {
      final tokens = await repo.searchTokens('en');
      expect(tokens['doner'] ?? tokens['döner'], isNotNull);
    });
  });

  group('the product promise', () {
    test('a vegan profile still sees most dishes', () async {
      final matcher = RecipeMatcher(
        ontology: repo.ontology,
        ingredients: repo.ingredients,
      );
      final ctx = matcher.contextFor(const Profile(avoidFlags: {'vegan'}));
      var covered = 0;
      for (final dish in repo.dishes) {
        if (repo.variantsOf(dish.id).any((r) => matcher.isVisible(r, ctx))) {
          covered++;
        }
      }
      // The whole point of the product: going vegan must not empty the book.
      expect(
        covered / repo.dishes.length,
        greaterThan(0.75),
        reason: 'only $covered of ${repo.dishes.length} dishes survive vegan',
      );
    });

    test('a gluten-free profile still sees most dishes', () async {
      final matcher = RecipeMatcher(
        ontology: repo.ontology,
        ingredients: repo.ingredients,
      );
      final ctx = matcher.contextFor(
        const Profile(avoidFlags: {'gluten-free'}),
      );
      var covered = 0;
      for (final dish in repo.dishes) {
        if (repo.variantsOf(dish.id).any((r) => matcher.isVisible(r, ctx))) {
          covered++;
        }
      }
      expect(covered / repo.dishes.length, greaterThan(0.6));
    });

    test('every dish has at least one variant an empty profile can see', () {
      final matcher = RecipeMatcher(
        ontology: repo.ontology,
        ingredients: repo.ingredients,
      );
      final ctx = matcher.contextFor(const Profile());
      for (final dish in repo.dishes) {
        expect(
          repo.variantsOf(dish.id).any((r) => matcher.isVisible(r, ctx)),
          isTrue,
          reason: dish.id,
        );
      }
    });
  });
}

Future<CorpusRepository> _freshRepo() async {
  final full = await loadRealCorpus();
  // loadRealCorpus reads everything; build a second one that only initialises.
  final files = <String, String>{};
  for (final name in [
    'partition-manifest.json',
    'ontology.json',
    'ingredients.json',
    'dishes.json',
    'faqs.json',
    'ingredient-guide.json',
    'search-index.json',
    ...full.manifest.partitions.map((p) => p.file),
  ]) {
    files[name] = readAssetRaw(name);
  }
  final repo = CorpusRepository(source: MapAssetSource(files));
  await repo.initialise();
  return repo;
}
