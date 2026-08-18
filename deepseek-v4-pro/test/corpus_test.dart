import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/corpus.dart';
import 'package:morphcook/logic/matching.dart' as engine;
import 'package:morphcook/models/profile.dart';

/// Loads the real bundled corpus and validates integrity:
/// partition loading, cross-references, search, ontology, bilingual data.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Corpus corpus;

  setUpAll(() async {
    corpus = await Corpus.load(bundle: rootBundle);
    await corpus.loadPartition('extended');
  });

  test('corpus loads 46 recipes and 16 dishes', () {
    expect(corpus.recipeCount, 46);
    expect(corpus.dishCount, 16);
  });

  test('every dish has at least one variant and every recipe belongs to a dish', () {
    for (final dish in corpus.allDishes) {
      expect(dish.variantRecipeIds, isNotEmpty, reason: dish.id);
      for (final rid in dish.variantRecipeIds) {
        expect(corpus.recipe(rid), isNotNull, reason: rid);
      }
    }
    for (final r in corpus.allRecipes) {
      expect(corpus.dish(r.dishId), isNotNull, reason: r.id);
    }
  });

  test('every recipe name is bilingual (en + de)', () {
    for (final r in corpus.allRecipes) {
      expect(r.name['en'], isNotEmpty, reason: '${r.id} en');
      expect(r.name['de'], isNotEmpty, reason: '${r.id} de');
      for (final step in r.steps) {
        expect(step.text['en'], isNotEmpty, reason: '${r.id} step en');
        expect(step.text['de'], isNotEmpty, reason: '${r.id} step de');
      }
    }
  });

  test('every ingredient id resolves in the dictionary', () {
    for (final r in corpus.allRecipes) {
      for (final id in r.ingredientIds) {
        expect(corpus.ingredientTree.byId(id), isNotNull, reason: '${r.id}: $id');
      }
    }
  });

  test('every contains-flag exists in the ontology', () {
    for (final r in corpus.allRecipes) {
      for (final f in r.contains) {
        expect(corpus.ontology.containsFlags, contains(f), reason: '${r.id}: $f');
      }
    }
  });

  test('compound flags expand to valid contains-flags', () {
    for (final entry in corpus.ontology.compoundAvoidFlags.entries) {
      for (final f in entry.value) {
        expect(corpus.ontology.containsFlags, contains(f),
            reason: '${entry.key}: $f');
      }
    }
    expect(corpus.ontology.expand('vegan'), contains('dairy'));
    expect(corpus.ontology.expand('halal'), {'pork', 'alcohol', 'gelatin-non-halal'});
  });

  test('cuisine partitions resolve recipes on demand', () async {
    await corpus.ensureDishesOfPartition('cuisine-italian');
    final dishes = corpus.dishesOfPartition('cuisine-italian');
    expect(dishes, isNotEmpty);
    for (final d in dishes) {
      for (final rid in d.variantRecipeIds) {
        expect(corpus.recipe(rid), isNotNull, reason: rid);
      }
    }
  });

  test('cuisine partitions resolve their recipes on demand', () async {
    await corpus.ensureDishesOfPartition('cuisine-asian');
    for (final d in corpus.dishesOfPartition('cuisine-asian')) {
      for (final rid in d.variantRecipeIds) {
        expect(corpus.recipe(rid), isNotNull, reason: rid);
      }
    }
  });

  test('search index finds recipes by title, tag, and ingredient', () {
    expect(corpus.searchIds('döner'), contains('doener.classic'));
    expect(corpus.searchIds('doener'), contains('doener.vegan'));
    expect(corpus.searchIds('tiramisu'), contains('tiramisu.classic'));
    expect(corpus.searchIds('garlic'), isNotEmpty);
    // ingredient-driven: peanuts finds pad-thai variants
    expect(corpus.searchIds('peanuts'), contains('pad-thai.classic'));
    // multi-token AND search
    final ids = corpus.searchIds('vegan döner');
    expect(ids, contains('doener.vegan'));
  });

  test('search index is bilingual', () {
    expect(corpus.searchIds('haferbrei'), contains('oatmeal.classic'));
    expect(corpus.searchIds('käse'), isNotEmpty);
  });

  test('faqs are bilingual and categorized', () {
    expect(corpus.faqs, isNotEmpty);
    for (final f in corpus.faqs) {
      expect(f.question['en'], isNotEmpty);
      expect(f.question['de'], isNotEmpty);
      expect(f.answer['en'], isNotEmpty);
      expect(f.answer['de'], isNotEmpty);
    }
    expect(corpus.faqs.map((f) => f.category).toSet(),
        containsAll(['dietary', 'features', 'general', 'troubleshooting']));
  });

  test('ingredient guides map to real ingredient ids', () {
    for (final entry in corpus.guides.entries) {
      expect(corpus.ingredientTree.byId(entry.key), isNotNull);
    }
  });

  test('matching on the real corpus: vegan profile hides the classic döner', () {
    final matcher = engine.Matcher(ingredientTree: corpus.ingredientTree);
    final profile = Profile(
      avoidFlags: corpus.ontology.expand('vegan'),
      maxTimeMinutes: 120,
      calorieTarget: 600,
      calorieTolerance: 400,
    );
    final classic = corpus.recipe('doener.classic')!;
    final vegan = corpus.recipe('doener.vegan')!;
    expect(matcher.evaluate(classic, profile).visible, isFalse);
    expect(matcher.evaluate(vegan, profile).visible, isTrue);
  });

  test('every dish offers a visible variant for a vegan profile', () {
    final matcher = engine.Matcher(ingredientTree: corpus.ingredientTree);
    final profile = Profile(
      avoidFlags: corpus.ontology.expand('vegan'),
      maxTimeMinutes: 999,
      calorieTarget: 600,
      calorieTolerance: 400,
    );
    for (final dish in corpus.allDishes) {
      final variants = corpus.variantsOf(dish.id);
      final visible =
          matcher.filter(variants, profile, overrideCalories: true);
      expect(visible, isNotEmpty,
          reason: '${dish.id} has no vegan-visible variant');
    }
  });
}
