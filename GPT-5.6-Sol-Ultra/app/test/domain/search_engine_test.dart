import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/domain/domain.dart';

import 'test_fixtures.dart';

void main() {
  late RecipeSearchEngine engine;
  late List<Recipe> recipes;

  setUp(() {
    recipes = [
      testRecipe(
        id: 'pasta',
        dishId: 'alfredo',
        enName: 'Parmesan Alfredo',
        deName: 'Alfredo mit Käse',
        contains: const {'dairy'},
        ingredients: const [
          RecipeIngredient(ingredientId: 'parmesan', quantity: 30, unit: 'g'),
        ],
      ),
      testRecipe(
        id: 'apple',
        dishId: 'oats',
        enName: 'Apple oats',
        deName: 'Apfel-Porridge',
        mealTypes: const {'breakfast'},
        tags: const {'quick', 'breakfast'},
        cuisines: const {'northern-european'},
        ingredients: const [
          RecipeIngredient(ingredientId: 'apple', quantity: 1, unit: 'piece'),
        ],
      ),
      testRecipe(
        id: 'herbs',
        dishId: 'herb-rice',
        enName: 'Green herb rice',
        deName: 'Grüner Kräuterreis',
        ingredients: const [
          RecipeIngredient(
            ingredientId: 'cilantro',
            quantity: 1,
            unit: 'bunch',
          ),
        ],
      ),
    ];
    engine = RecipeSearchEngine(
      recipes: recipes,
      dishes: [
        Dish(
          id: 'alfredo',
          name: LocalizedText(const {'en': 'Alfredo', 'de': 'Alfredo'}),
          heroText: LocalizedText(const {'en': 'Pasta', 'de': 'Pasta'}),
          caption: LocalizedText(const {'en': 'soft', 'de': 'sanft'}),
          stripeColor: '#fff',
          variantRecipeIds: const ['pasta'],
          partitionId: 'core',
        ),
      ],
      ingredients: testIngredients,
      matcher: RecipeMatcher(
        ontology: testOntology,
        ingredients: testIngredients,
      ),
    );
  });

  test('tokenizes German diacritics and indexes ingredient names', () {
    final page = engine.search(
      SearchQuery(text: 'Käse', languageCode: 'de'),
      testProfile(),
    );

    expect(page.items.single.recipe.id, 'pasta');
    expect(page.items.single.matchedTokens, contains('kase'));

    final asciiSpelling = engine.search(
      SearchQuery(text: 'Kaese', languageCode: 'de'),
      testProfile(),
    );
    expect(asciiSpelling.items.single.recipe.id, 'pasta');
  });

  test('aliases make cross-vocabulary ingredient searches useful', () {
    final page = engine.search(
      SearchQuery(text: 'coriander leaves', languageCode: 'en'),
      testProfile(),
    );

    expect(page.items.single.recipe.id, 'herbs');
  });

  test('profile visibility is applied after text matching', () {
    final page = engine.search(
      SearchQuery(text: 'Alfredo'),
      testProfile(avoidFlags: const {'dairy'}),
    );

    expect(page.items, isEmpty);
  });

  test('tag, cuisine, and meal filters combine', () {
    final page = engine.search(
      SearchQuery(
        tags: const {'quick'},
        cuisineTags: const {'northern-european'},
        mealTypes: const {'breakfast'},
      ),
      testProfile(),
    );

    expect(page.items.single.recipe.id, 'apple');
  });

  test('opaque cursor pagination is stable and rejects stale cursors', () {
    final first = engine.search(SearchQuery(pageSize: 2), testProfile());
    final second = engine.search(
      SearchQuery(pageSize: 2, cursor: first.nextCursor),
      testProfile(),
    );
    final stale = engine.search(
      SearchQuery(text: 'apple', pageSize: 2, cursor: first.nextCursor),
      testProfile(),
    );

    expect(first.items, hasLength(2));
    expect(first.hasMore, isTrue);
    expect(second.items, hasLength(1));
    expect(
      first.items
          .map((item) => item.recipe.id)
          .toSet()
          .intersection(second.items.map((item) => item.recipe.id).toSet()),
      isEmpty,
    );
    expect(stale.items.single.recipe.id, 'apple');
  });

  test('content gaps count only first-page meaningful zero results', () {
    final tracker = ContentGapTracker();
    final query = SearchQuery(text: 'Sushi', languageCode: 'de');
    final empty = engine.search(query, testProfile());

    expect(
      tracker.recordIfGap(query, empty, searchedAt: DateTime.utc(2026, 7, 1)),
      isTrue,
    );
    tracker.recordIfGap(query, empty, searchedAt: DateTime.utc(2026, 7, 2));
    expect(tracker.requests.single.count, 2);
    expect(tracker.toJson(), ['Sushi']);
    expect(tracker.recordIfGap(SearchQuery(text: 'x'), empty), isFalse);
  });
}
