import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/units.dart';
import 'package:morphcook/models/recipe.dart';

import 'helpers.dart';

/// Mechanical enforcement of the corpus authoring contract
/// (docs/corpus-brief.md). The pipeline's quality gates, app-side.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('corpus', () {
    test('all partitions load, dish↔recipe links are bidirectional',
        () async {
      final corpus = await loadRealCorpus();
      expect(corpus.dishes, isNotEmpty);
      expect(corpus.loadedRecipes.length, greaterThanOrEqualTo(40));

      final recipesById = {
        for (final r in corpus.loadedRecipes) r.id: r,
      };
      // Unique ids.
      expect(recipesById.length, corpus.loadedRecipes.length);

      for (final dish in corpus.dishes) {
        for (final id in dish.recipeIds) {
          final recipe = recipesById[id];
          expect(recipe, isNotNull,
              reason: 'dish ${dish.id} references missing recipe $id');
          expect(recipe!.dishId, dish.id,
              reason: 'recipe $id does not point back to dish ${dish.id}');
        }
      }
      for (final recipe in corpus.loadedRecipes) {
        final dish = corpus.dishById(recipe.dishId);
        expect(dish, isNotNull);
        expect(dish!.recipeIds, contains(recipe.id));
      }
    });

    test('every dish files under a declared category, none empty', () async {
      final corpus = await loadRealCorpus();
      expect(corpus.categories, isNotEmpty);

      final ids = corpus.categories.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length,
          reason: 'duplicate category ids');
      for (final category in corpus.categories) {
        expect(category.name.of('en'), isNotEmpty);
        expect(category.name.of('de'), isNotEmpty);
      }

      final counts = <String, int>{for (final id in ids) id: 0};
      for (final dish in corpus.dishes) {
        expect(ids, contains(dish.category),
            reason:
                'dish ${dish.id} files under unknown category ${dish.category}');
        counts[dish.category] = counts[dish.category]! + 1;
      }
      for (final entry in counts.entries) {
        expect(entry.value, greaterThan(0),
            reason: 'category ${entry.key} has no dishes');
      }
    });

    test('ingredients exist, units are known, contains ⊇ ingredient flags',
        () async {
      final corpus = await loadRealCorpus();
      for (final recipe in corpus.loadedRecipes) {
        for (final ing in recipe.ingredients) {
          final node = corpus.dictionary.byId(ing.ingredientId);
          expect(node, isNotNull,
              reason:
                  '${recipe.id}: unknown ingredient ${ing.ingredientId}');
          expect(units.containsKey(ing.unit), isTrue,
              reason: '${recipe.id}: unknown unit ${ing.unit}');
          expect(ing.qty, greaterThan(0));
          for (final flag in node!.flags) {
            expect(recipe.contains, contains(flag),
                reason:
                    '${recipe.id}: ingredient ${ing.ingredientId} implies '
                    'flag $flag missing from contains');
          }
        }
      }
    });

    test('contains flags and attributes exist in the ontology', () async {
      final corpus = await loadRealCorpus();
      final knownFlags = corpus.ontology.allContainsFlagIds;
      final knownAttributes = {
        ...corpus.ontology.dietLabels,
        for (final values in corpus.ontology.attributes.values) ...values,
      };
      for (final recipe in corpus.loadedRecipes) {
        for (final flag in recipe.contains) {
          expect(knownFlags, contains(flag),
              reason: '${recipe.id}: unknown contains flag $flag');
        }
        for (final attr in recipe.attributes) {
          expect(knownAttributes, contains(attr),
              reason: '${recipe.id}: unknown attribute $attr');
        }
      }
    });

    test('diet-label attributes are consistent with compound expansions',
        () async {
      final corpus = await loadRealCorpus();
      for (final recipe in corpus.loadedRecipes) {
        for (final compound in corpus.ontology.compoundFlags) {
          final applies =
              recipe.contains.intersection(compound.expandsTo).isEmpty;
          if (recipe.attributes.contains(compound.id)) {
            expect(applies, isTrue,
                reason:
                    '${recipe.id} claims ${compound.id} but contains '
                    '${recipe.contains.intersection(compound.expandsTo)}');
          } else if (applies && compound.id != 'lactose-free') {
            // lactose-free is a judgment subset of dairy; others are strict.
            fail(
                '${recipe.id} qualifies for ${compound.id} but does not '
                'declare it');
          }
        }
        final glutenFree = !recipe.contains.contains('gluten');
        expect(recipe.attributes.contains('gluten-free'), glutenFree,
            reason: '${recipe.id}: gluten-free attribute inconsistent');
      }
    });

    test('buckets, variant coords and macros are consistent', () async {
      final corpus = await loadRealCorpus();
      String timeBucket(int m) => m <= 15
          ? 'le15'
          : m <= 30
              ? 'le30'
              : m <= 60
                  ? 'le60'
                  : 'gt60';
      String calorieBucket(int c) => c <= 400
          ? 'le400'
          : c <= 600
              ? 'le600'
              : c <= 800
                  ? 'le800'
                  : 'gt800';

      for (final recipe in corpus.loadedRecipes) {
        expect(recipe.attributes, contains(timeBucket(recipe.timeMinutes)),
            reason: '${recipe.id}: time bucket');
        expect(recipe.variant.calorie,
            calorieBucket(recipe.caloriesPerServing),
            reason: '${recipe.id}: variant calorie bucket');
        expect(recipe.attributes, contains(recipe.variant.effort),
            reason: '${recipe.id}: effort attribute');
        expect(recipe.macros.calories, recipe.caloriesPerServing,
            reason: '${recipe.id}: macros.calories mismatch');
        final energy = 4 * recipe.macros.proteinG +
            4 * recipe.macros.carbsG +
            9 * recipe.macros.fatG;
        expect(
            (energy - recipe.macros.calories).abs() /
                recipe.macros.calories,
            lessThanOrEqualTo(0.16),
            reason: '${recipe.id}: macro energy off ($energy vs '
                '${recipe.macros.calories})');
      }
    });

    test('variant triples are unique within a dish (coverage variants '
        'share their base cell on purpose)', () async {
      // Coverage variants ("…-no-gluten-dairy") re-author a base cell free
      // of an allergen combination — same coordinates by design. The
      // matcher picks the visible one. Base cells stay unique.
      final coverageId = RegExp(r'-no-[a-z-]+$');
      final corpus = await loadRealCorpus();
      for (final dish in corpus.dishes) {
        final seen = <String>{};
        for (final recipe in await corpus.variantsOf(dish)) {
          final key =
              '${recipe.variant.diet}|${recipe.variant.effort}|${recipe.variant.calorie}';
          if (coverageId.hasMatch(recipe.id)) {
            expect(seen, contains(key),
                reason: 'dish ${dish.id}: coverage ${recipe.id} sits at '
                    '$key but no base cell exists there');
            continue;
          }
          expect(seen.add(key), isTrue,
              reason: 'dish ${dish.id}: duplicate variant combo $key');
        }
      }
    });

    // The wave-4 contract tests arm themselves when the regenerated corpus
    // lands: pipeline/wave4_lattice.py stamps corpus_wave 4 into the
    // partition manifest at merge time.
    final corpusWave =
        (readJsonFile('assets/partition-manifest.json')['corpus_wave']
                as int?) ??
            3;
    final waveSkip = corpusWave >= 4
        ? null
        : 'wave-4 corpus not merged yet — run pipeline/wave4_lattice.py';

    test('every dish is a complete lattice (wave 4 contract)', () async {
      // Core diet columns × the dish's two efforts × its two calorie levels
      // must ALL exist — combinations are the product. Extra diets
      // (coverage cells) are sparse by design but stay inside the pairs.
      const coreDiets = {'classic', 'vegetarian', 'vegan'};
      const extraDiets = {'gluten-free', 'low-fodmap'};
      final corpus = await loadRealCorpus();
      for (final dish in corpus.dishes) {
        final recipes = await corpus.variantsOf(dish);
        final core =
            recipes.where((r) => coreDiets.contains(r.variant.diet)).toList();
        final diets = core.map((r) => r.variant.diet).toSet();
        final efforts = core.map((r) => r.variant.effort).toSet();
        final calories = core.map((r) => r.variant.calorie).toSet();
        expect(diets, contains('classic'),
            reason: 'dish ${dish.id}: no classic column');
        expect(efforts.length, 2,
            reason: 'dish ${dish.id}: effort pair is $efforts');
        expect(calories.length, 2,
            reason: 'dish ${dish.id}: calorie pair is $calories');
        final triples =
            core.map((r) => '${r.variant.diet}|${r.variant.effort}|'
                '${r.variant.calorie}').toSet();
        for (final d in diets) {
          for (final e in efforts) {
            for (final c in calories) {
              expect(triples, contains('$d|$e|$c'),
                  reason: 'dish ${dish.id}: missing lattice cell $d|$e|$c');
            }
          }
        }
        for (final r in recipes.where(
            (r) => !coreDiets.contains(r.variant.diet))) {
          expect(extraDiets, contains(r.variant.diet),
              reason: 'dish ${dish.id}: ${r.id} uses retired diet '
                  '${r.variant.diet}');
          expect(efforts, contains(r.variant.effort),
              reason: 'dish ${dish.id}: extra ${r.id} outside effort pair');
          expect(calories, contains(r.variant.calorie),
              reason: 'dish ${dish.id}: extra ${r.id} outside calorie pair');
        }
      }
    }, skip: waveSkip);

    test('titles carry no diet words and are unique within a dish',
        () async {
      final banned = RegExp(
          r'\b(vegan\w*|vegetar\w*|veggie|classic\w*|klassi\w*|keto|halal|'
          r'kosher|koscher|gluten\w*|fodmap|sugar.?free|zucker.?frei\w*|'
          r'protein\w*|light|leicht\w*|lactose\w*|laktose\w*|pescatari\w*|'
          r'low.?carb|kalorien\w*|calorie\w*)\b',
          caseSensitive: false);
      final corpus = await loadRealCorpus();
      for (final dish in corpus.dishes) {
        final seen = <String>{};
        for (final recipe in await corpus.variantsOf(dish)) {
          for (final lang in ['en', 'de']) {
            final title = recipe.title.of(lang);
            expect(banned.hasMatch(title), isFalse,
                reason: '${recipe.id}: title[$lang] "$title" carries a '
                    'diet word — coordinates say that, titles sell food');
            expect(seen.add('$lang|${title.trim().toLowerCase()}'), isTrue,
                reason: '${recipe.id}: duplicate title[$lang] "$title" '
                    'within dish ${dish.id}');
          }
        }
      }
    }, skip: waveSkip);

    test('bilingual completeness (en + de) everywhere', () async {
      final corpus = await loadRealCorpus();
      void check(String owner, Map<String, String> values) {
        expect(values['en'], isNotEmpty, reason: '$owner: missing en');
        expect(values['de'], isNotEmpty, reason: '$owner: missing de');
      }

      for (final dish in corpus.dishes) {
        check('dish ${dish.id} name', dish.name.values);
        check('dish ${dish.id} hero', dish.hero.values);
        check('dish ${dish.id} caption', dish.caption.values);
      }
      for (final recipe in corpus.loadedRecipes) {
        check('recipe ${recipe.id} title', recipe.title.values);
        check('recipe ${recipe.id} caption', recipe.caption.values);
        check('recipe ${recipe.id} intro', recipe.intro.values);
        for (var i = 0; i < recipe.steps.length; i++) {
          check('recipe ${recipe.id} step $i', recipe.steps[i].text.values);
        }
        for (final ing in recipe.ingredients) {
          if (ing.note != null) {
            check('recipe ${recipe.id} note ${ing.ingredientId}',
                ing.note!.values);
          }
        }
      }
      for (final node in corpus.dictionary.all) {
        check('ingredient ${node.id}', node.name.values);
      }
      for (final entry in corpus.faqs.entries) {
        check('faq ${entry.id} q', entry.question.values);
        check('faq ${entry.id} a', entry.answer.values);
      }
      for (final entry in corpus.guide.values) {
        check('guide ${entry.ingredientId}', entry.description.values);
      }
    });

    test('steps carry usable cook-mode timers', () async {
      final corpus = await loadRealCorpus();
      for (final recipe in corpus.loadedRecipes) {
        final timed =
            recipe.steps.where((s) => (s.timerMinutes ?? 0) > 0).length;
        expect(timed, greaterThanOrEqualTo(2),
            reason: '${recipe.id}: needs ≥2 timed steps');
        expect(recipe.steps.length, inInclusiveRange(4, 8),
            reason: '${recipe.id}: step count');
        expect(recipe.ingredients.length, inInclusiveRange(5, 10),
            reason: '${recipe.id}: ingredient count');
      }
    });

    test('FAQ has required entries and categories', () async {
      final corpus = await loadRealCorpus();
      const required = [
        'how-matching-works', 'compound-diets', 'specific-avoidance',
        'halal-kosher-note', 'lactose-vs-dairy', 'why-recipe-hidden',
        'calorie-filter-override', 'time-budget', 'unreachable-combos',
        'variant-switching', 'cookbook-saving', 'shopping-aggregation',
        'meal-planning', 'cook-mode', 'backup-export', 'backup-encryption',
        'shopping-insights', 'ingredient-guide-feature', 'restore-failed',
        'wrong-password', 'search-no-results', 'reset-profile',
      ];
      for (final id in required) {
        expect(corpus.faqs.byId(id), isNotNull, reason: 'missing FAQ $id');
      }
      final categoryIds = corpus.faqs.categories.map((c) => c.id).toSet();
      for (final entry in corpus.faqs.entries) {
        expect(categoryIds, contains(entry.category));
      }
      // The certification stance is non-negotiable copy.
      final halal = corpus.faqs.byId('halal-kosher-note')!;
      expect(halal.answer.of('en').toLowerCase(),
          isNot(contains('certified recipe')));
    });

    test('partition manifest matches dish routing', () async {
      final manifest = readJsonFile('assets/partition-manifest.json');
      final corpus = await loadRealCorpus();
      final partitionDishes = <String, Set<String>>{};
      for (final p in manifest['partitions'] as List) {
        partitionDishes[p['id'] as String] =
            Set<String>.from(p['dish_ids'] as List);
      }
      for (final dish in corpus.dishes) {
        expect(partitionDishes[dish.partitionId], contains(dish.id),
            reason:
                'dish ${dish.id} missing from partition ${dish.partitionId}');
      }
      // Corpus size must equal the dish routing — no orphans, no strays.
      final expectedTotal =
          corpus.dishes.fold<int>(0, (sum, d) => sum + d.recipeIds.length);
      expect(corpus.loadedRecipes.length, expectedTotal);
      expect(corpus.loadedRecipes.length, greaterThanOrEqualTo(100));
    });

    test('meal values are valid', () async {
      final corpus = await loadRealCorpus();
      for (final recipe in corpus.loadedRecipes) {
        expect(recipe.meal, isNotEmpty, reason: recipe.id);
        for (final m in recipe.meal) {
          expect(const ['breakfast', 'lunch', 'dinner'], contains(m),
              reason: '${recipe.id}: bad meal $m');
        }
      }
    });

    test('guide entries reference real ingredients', () async {
      final corpus = await loadRealCorpus();
      expect(corpus.guide.length, greaterThanOrEqualTo(16));
      for (final entry in corpus.guide.values) {
        expect(corpus.dictionary.byId(entry.ingredientId), isNotNull,
            reason: 'guide: unknown ingredient ${entry.ingredientId}');
      }
    });

    test('recipes parse into the model with full fidelity', () async {
      final corpus = await loadRealCorpus();
      for (final recipe in corpus.loadedRecipes) {
        expect(recipe, isA<Recipe>());
        expect(recipe.servings, greaterThan(0));
        expect(recipe.timeMinutes, greaterThan(0));
      }
    });
  });
}
