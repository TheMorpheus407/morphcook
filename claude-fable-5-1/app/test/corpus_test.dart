// Keeps the shipped assets honest: every link resolves, every flag is
// derivable, every partition loads lazily and dedups.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/corpus_builder.dart';
import 'package:morphcook/data/corpus_repository.dart';
import 'package:morphcook/data/models/ingredient.dart';

import 'helpers.dart';

void main() {
  late CorpusRepository repo;
  setUpAll(() async => repo = await loadRepo());

  test('launch loads only the eager partition; others load on demand and dedup', () async {
    expect(repo.loadedPartitions, {'core'});
    expect(repo.manifest.loadingStrategy.eager, ['core']);
    final tiramisu = repo.dish('tiramisu')!;
    expect(tiramisu.partitionId, 'extended');
    expect(repo.variantsIfLoaded('tiramisu'), isEmpty);
    final variants = await repo.variantsOf('tiramisu');
    expect(variants.length, tiramisu.variantIds.length);
    expect(repo.loadedPartitions, {'core', 'extended'});
    final before = repo.loadedRecipes.length;
    await repo.ensurePartition('cuisine-italian');
    expect(repo.loadedRecipes.length, before); // cuisine bundles only duplicate
    expect(repo.manifest.crossReferences['tiramisu-classic-easy'], ['extended', 'cuisine-italian']);
  });

  test('every dish variant resolves and belongs to its dish', () async {
    await repo.loadAll();
    for (final d in repo.dishes) {
      expect(d.variantIds, isNotEmpty, reason: d.id);
      for (final id in d.variantIds) {
        final r = repo.recipeIfLoaded(id);
        expect(r, isNotNull, reason: id);
        expect(r!.dishId, d.id);
        expect(r.partitionId, d.partitionId);
      }
    }
    expect(repo.dishes.length, greaterThanOrEqualTo(28));
    expect(repo.loadedRecipes.length, greaterThanOrEqualTo(130));
  });

  test('recipes only use leaf ingredients, valid units and derivable flags', () async {
    await repo.loadAll();
    final builder = CorpusBuilder(ontology: repo.ontology, dictionary: repo.ingredients);
    for (final r in repo.loadedRecipes) {
      for (final i in r.ingredients) {
        final node = repo.ingredients.byId[i.id];
        expect(node, isNotNull, reason: '${r.id}: ${i.id}');
        expect(node!.kind, IngredientKind.item, reason: '${r.id}: ${i.id}');
        expect(repo.ontology.unitById.containsKey(i.unit), isTrue, reason: '${r.id}: ${i.unit}');
      }
      final derived = builder.deriveContains(r.ingredientIds);
      expect(r.contains.containsAll(derived), isTrue, reason: '${r.id} missing ${derived.difference(r.contains)}');
      for (final f in r.contains) {
        expect(repo.ontology.containsById.containsKey(f), isTrue, reason: '${r.id}: $f');
      }
      expect(r.attributes, contains(r.effort));
      expect(r.attributes, contains(repo.ontology.timeBucketFor(r.timeMinutes)));
      expect(r.variant['calorie_level'], repo.ontology.calorieLevelFor(r.caloriesPerServing));
      expect(r.steps.length, inInclusiveRange(4, 9), reason: r.id);
      for (final lang in ['en', 'de']) {
        expect(r.title.of(lang), isNotEmpty, reason: '${r.id} $lang');
        expect(r.intro.of(lang), isNotEmpty, reason: '${r.id} $lang');
        for (final s in r.steps) {
          expect(s.text.of(lang), isNotEmpty, reason: '${r.id} $lang');
        }
      }
    }
  });

  test('diet identity holds on derived attributes', () async {
    await repo.loadAll();
    for (final r in repo.loadedRecipes) {
      switch (r.diet) {
        case 'vegan':
          expect(r.attributes, contains('vegan'), reason: r.id);
        case 'vegetarian':
          expect(r.attributes, contains('vegetarian'), reason: r.id);
        case 'pescatarian':
          expect(r.attributes, contains('pescatarian'), reason: r.id);
        case 'halal':
          expect(r.attributes, contains('halal'), reason: r.id);
        case 'gluten-free':
          expect(r.attributes, contains('gluten-free'), reason: r.id);
        case 'keto':
          expect(r.attributes, contains('keto'), reason: r.id);
          expect(r.macros.carbsG, lessThanOrEqualTo(20), reason: r.id);
      }
    }
  });

  test('search index covers every recipe with tokens in both languages', () async {
    await repo.loadAll();
    for (final r in repo.loadedRecipes) {
      final e = repo.searchIndex.byRecipe[r.id];
      expect(e, isNotNull, reason: r.id);
      expect(e!.tokens['en'], isNotEmpty);
      expect(e.tokens['de'], isNotEmpty);
      expect(e.partitionId, r.partitionId);
    }
  });

  test('faq entries the UI links to exist, and the guide has bilingual entries', () {
    for (final id in ['why-dish-missing', 'how-matching-works', 'halal-kosher-note', 'backup-password', 'quick-next-tap']) {
      expect(repo.faqs.byId(id), isNotNull, reason: id);
    }
    for (final e in repo.faqs.entries) {
      expect(e.question.of('de'), isNotEmpty, reason: e.id);
      expect(e.answer.of('en'), isNotEmpty, reason: e.id);
      expect(repo.faqs.categories.any((c) => c.id == e.category), isTrue, reason: e.id);
      for (final rel in e.related) {
        expect(repo.faqs.byId(rel), isNotNull, reason: '${e.id} → $rel');
      }
    }
    expect(repo.guide.byIngredient.length, greaterThan(30));
    for (final g in repo.guide.byIngredient.values) {
      expect(repo.ingredients.byId.containsKey(g.ingredientId), isTrue, reason: g.ingredientId);
      expect(g.description.of('de'), isNotEmpty);
    }
  });

  test('halal and kosher wording never claims certification', () async {
    await repo.loadAll();
    final blob = StringBuffer();
    for (final r in repo.loadedRecipes) {
      blob.write(r.intro.of('en'));
      blob.write(r.intro.of('de'));
    }
    for (final f in ['assets/faqs.json', 'lib/core/strings.dart']) {
      blob.write(File(f).readAsStringSync());
    }
    final text = blob.toString().toLowerCase();
    expect(text.contains('halal-certified'), isFalse);
    expect(text.contains('kosher-certified'), isFalse);
    expect(text.contains('halal-zertifiziert'), isFalse);
  });

  test('manifest matches the files on disk', () {
    for (final p in repo.manifest.partitions) {
      final doc = jsonDecode(File(p.file).readAsStringSync()) as Map;
      expect((doc['recipes'] as List).length, p.recipeCount, reason: p.id);
    }
  });
}
