import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/services/content_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the core first and all disjoint partitions on demand', () async {
    final repository = ContentRepository();
    await repository.loadCore();
    expect(repository.recipes, hasLength(6));
    expect(repository.dishes, hasLength(8));
    expect(repository.allLoaded, isFalse);
    await repository.ensureDish('doener');
    expect(repository.recipesForDish('doener'), hasLength(4));
    await repository.loadAll();
    expect(repository.allLoaded, isTrue);
    expect(repository.recipes, hasLength(21));
    expect(
      repository.recipes.map((recipe) => recipe.id).toSet(),
      hasLength(21),
    );
  });

  test('corpus has complete bilingual links and reviewed recipes', () async {
    final repository = ContentRepository();
    await repository.loadCore();
    await repository.loadAll();
    final recipeIds = repository.recipes.map((recipe) => recipe.id).toSet();
    final ingredientIds = repository.ingredientNodes
        .map((item) => item.id)
        .toSet();
    for (final dish in repository.dishes) {
      expect(dish.name.keys, containsAll(['en', 'de']), reason: dish.id);
      expect(dish.hero.keys, containsAll(['en', 'de']), reason: dish.id);
      expect(recipeIds, containsAll(dish.recipeIds), reason: dish.id);
    }
    for (final recipe in repository.recipes) {
      expect(recipe.reviewed, isTrue, reason: recipe.id);
      expect(recipe.title.keys, containsAll(['en', 'de']), reason: recipe.id);
      expect(
        recipe.subtitle.keys,
        containsAll(['en', 'de']),
        reason: recipe.id,
      );
      expect(recipe.steps, isNotEmpty, reason: recipe.id);
      expect(recipe.ingredients, isNotEmpty, reason: recipe.id);
      expect(
        ingredientIds,
        containsAll(recipe.ingredientIds),
        reason: '${recipe.id} dictionary coverage',
      );
      for (final ingredient in recipe.ingredients) {
        expect(
          ingredient.name.keys,
          containsAll(['en', 'de']),
          reason: '${recipe.id}/${ingredient.id}',
        );
      }
      for (final step in recipe.steps) {
        expect(step.text.keys, containsAll(['en', 'de']), reason: recipe.id);
      }
    }
    expect(repository.faqs.length, greaterThanOrEqualTo(8));
    expect(repository.guideFor('tahini'), isNotNull);
  });

  test('search tokenizes bilingual title, tags and ingredient names', () async {
    final repository = ContentRepository();
    await repository.loadCore();
    await repository.loadAll();
    expect(repository.search('Döner', 'en', {}).length, 4);
    expect(repository.search('apfel', 'de', {}).length, 3);
    expect(
      repository.search('tofu', 'en', {}).map((item) => item.id),
      contains('doener-vegan-easy'),
    );
    expect(
      repository.search('', 'en', {'breakfast'}).map((item) => item.dishId),
      contains('apple-pancakes'),
    );
    final multiTag = repository.search('', 'en', {'vegan', 'quick'});
    expect(multiTag, isNotEmpty);
    expect(
      multiTag.every((recipe) => recipe.tags.containsAll({'vegan', 'quick'})),
      isTrue,
    );
    expect(repository.ontology.label('high-protein', 'de'), 'proteinreich');
  });
}
