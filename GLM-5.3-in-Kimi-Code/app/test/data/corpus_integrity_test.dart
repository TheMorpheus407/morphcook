import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/corpus.dart';

/// Integrity checks over the shipped corpus — mirrors the build-time
/// validator so regressions in the JSON get caught in CI too.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Corpus corpus;

  setUpAll(() async {
    corpus = await Corpus.load();
  });

  group('partitions', () {
    test('manifest counts match loaded recipes', () {
      expect(corpus.recipes.length, corpus.manifest.totalRecipes);
      expect(corpus.dishes.length, corpus.manifest.totalDishes);
      expect(corpus.recipes.length, greaterThanOrEqualTo(40));
    });

    test('core + extended partitions cover every recipe', () {
      final core = corpus.manifest.partitions['core']!;
      final extended = corpus.manifest.partitions['extended']!;
      final coreDishes = core.dishIds.toSet();
      final extDishes = extended.dishIds.toSet();
      expect(coreDishes.union(extDishes), corpus.dishes.keys.toSet());
      expect(coreDishes.intersection(extDishes), isEmpty,
          reason: 'a dish must live in exactly one primary partition');
    });
  });

  group('referential integrity', () {
    test('every dish variant resolves to a recipe', () {
      for (final dish in corpus.dishes.values) {
        for (final vid in dish.variants) {
          expect(corpus.recipes.containsKey(vid), isTrue,
              reason: '${dish.id} → $vid missing');
        }
      }
    });

    test('every recipe belongs to its dish and is listed', () {
      for (final r in corpus.recipes.values) {
        final dish = corpus.dishes[r.dishId];
        expect(dish, isNotNull, reason: '${r.id} has no dish');
        expect(dish!.variants, contains(r.id));
      }
    });

    test('one variant per (dish, diet)', () {
      final seen = <String>{};
      for (final r in corpus.recipes.values) {
        final key = '${r.dishId}:${r.diet}';
        expect(seen.add(key), isTrue, reason: 'duplicate variant $key');
      }
    });

    test('all ingredient ids exist in the dictionary', () {
      for (final r in corpus.recipes.values) {
        for (final ing in r.ingredients) {
          expect(corpus.ingredients.nodes.containsKey(ing.id), isTrue,
              reason: '${r.id} uses unknown ${ing.id}');
        }
      }
    });

    test('all contains flags exist in the ontology', () {
      for (final r in corpus.recipes.values) {
        for (final f in r.contains) {
          expect(corpus.ontology.containsFlags.containsKey(f), isTrue,
              reason: '${r.id} uses unknown flag $f');
        }
      }
    });

    test('all diets exist in the ontology', () {
      for (final r in corpus.recipes.values) {
        expect(corpus.ontology.dietLabels.containsKey(r.diet), isTrue,
            reason: '${r.id} uses unknown diet ${r.diet}');
      }
    });
  });

  group('diet consistency (the soul of the app)', () {
    test('vegan variants contain no animal-derived flags', () {
      const animal = [
        'pork', 'beef', 'lamb', 'poultry', 'fish', 'shellfish', 'molluscs',
        'egg', 'dairy', 'lactose-dairy', 'honey', 'gelatin-non-halal',
        'gelatin-non-kosher',
      ];
      for (final r in corpus.recipes.values.where((r) => r.diet == 'vegan')) {
        expect(r.contains.toSet().intersection(animal.toSet()), isEmpty,
            reason: '${r.id} claims vegan but contains ${r.contains}');
      }
    });

    test('halal variants contain no pork/alcohol/non-halal gelatin', () {
      const banned = ['pork', 'alcohol', 'gelatin-non-halal'];
      for (final r in corpus.recipes.values.where((r) => r.diet == 'halal')) {
        expect(r.contains.toSet().intersection(banned.toSet()), isEmpty,
            reason: '${r.id} claims halal but contains ${r.contains}');
      }
    });

    test('gluten-free variants contain no gluten flag', () {
      for (final r
          in corpus.recipes.values.where((r) => r.diet == 'gluten-free')) {
        expect(r.contains, isNot(contains('gluten')),
            reason: '${r.id} claims gluten-free');
      }
    });

    test('low-fodmap variants contain no high-fodmap flag', () {
      for (final r
          in corpus.recipes.values.where((r) => r.diet == 'low-fodmap')) {
        expect(r.contains, isNot(contains('high-fodmap')),
            reason: '${r.id} claims low-fodmap');
      }
    });
  });

  group('bilingual completeness', () {
    test('every user-visible string has en and de', () {
      for (final r in corpus.recipes.values) {
        expect(r.title.map.keys, containsAll(['en', 'de']), reason: r.id);
        expect(r.subtitle.map.keys, containsAll(['en', 'de']), reason: r.id);
        for (final s in r.steps) {
          expect(s.text.map.keys, containsAll(['en', 'de']), reason: r.id);
        }
      }
      for (final d in corpus.dishes.values) {
        expect(d.canonicalName.map.keys, containsAll(['en', 'de']));
        expect(d.hero.map.keys, containsAll(['en', 'de']));
      }
      for (final f in corpus.faqs) {
        expect(f.question.map.keys, containsAll(['en', 'de']));
        expect(f.answer.map.keys, containsAll(['en', 'de']));
      }
    });

    test('faq related ids resolve', () {
      final ids = corpus.faqs.map((f) => f.id).toSet();
      for (final f in corpus.faqs) {
        for (final rid in f.relatedIds) {
          expect(ids.contains(rid), isTrue, reason: '${f.id} → $rid');
        }
      }
    });
  });

  group('derived-flag coverage', () {
    test('contains covers flags derivable from ingredients', () {
      for (final r in corpus.recipes.values) {
        final derived = <String>{};
        for (final ing in r.ingredients) {
          derived.addAll(corpus.ingredients.flagsOf(ing.id));
        }
        final missing = derived.difference(r.contains.toSet());
        expect(missing, isEmpty,
            reason: '${r.id} misses derived flags $missing');
      }
    });
  });
}
