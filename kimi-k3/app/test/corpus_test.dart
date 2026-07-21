import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/corpus_repository.dart';

/// Guards the bundled corpus against schema drift: every dish's variants
/// resolve, the lattice dimensions exist, and required assets parse.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled corpus loads and is internally consistent', () async {
    final corpus = CorpusRepository();
    await corpus.loadCore();

    expect(corpus.dishes, isNotEmpty);
    expect(corpus.recipes, isNotEmpty);
    expect(corpus.ontology.containsFlags, isNotEmpty);
    expect(corpus.faqs, isNotEmpty);
    expect(corpus.ingredientGuide, isNotEmpty);
    expect(corpus.searchIndex, isNotEmpty);

    // Core partition is eager; extended loads lazily.
    await corpus.ensureAllLoaded();

    for (final dish in corpus.dishes) {
      final variants = corpus.variantsOf(dish);
      expect(variants, isNotEmpty,
          reason: 'dish ${dish.id} has no resolvable variants');
      for (final v in variants) {
        expect(v.dishId, dish.id);
        expect(v.dimensions, contains('diet'));
        expect(v.dimensions, contains('effort'));
        expect(v.dimensions, contains('calorie_level'));
        expect(v.ingredients, isNotEmpty);
        expect(v.steps, isNotEmpty);
        for (final flag in v.contains) {
          expect(corpus.ontology.containsFlags, contains(flag),
              reason: '${v.id} carries unknown flag $flag');
        }
        for (final ing in v.ingredients) {
          expect(corpus.ingredientDictionary.byId(ing.id), isNotNull,
              reason: '${v.id} uses unknown ingredient ${ing.id}');
        }
      }
      // Every variant is in the search index.
      for (final id in dish.variantIds) {
        expect(corpus.searchIndex, contains(id));
      }
    }

    // Vegan variants carry no animal-derived flags.
    const animalFlags = {
      'pork', 'beef', 'lamb', 'poultry', 'fish', 'shellfish', 'molluscs',
      'egg', 'dairy', 'honey', 'gelatin-non-halal', 'gelatin-non-kosher',
    };
    for (final recipe in corpus.recipes.values) {
      if (recipe.diet == 'vegan') {
        expect(recipe.contains.intersection(animalFlags), isEmpty,
            reason: '${recipe.id} is vegan but contains animal flags');
      }
    }
  });
}
