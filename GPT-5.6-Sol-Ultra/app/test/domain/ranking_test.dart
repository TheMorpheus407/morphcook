import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/domain/domain.dart';

import 'test_fixtures.dart';

void main() {
  late RecipeRanker ranker;

  setUp(() {
    ranker = RecipeRanker(
      matcher: RecipeMatcher(
        ontology: testOntology,
        ingredients: testIngredients,
      ),
    );
  });

  test('morning breakfast receives exactly the specified +200', () {
    final breakfast = testRecipe(mealTypes: const {'breakfast'});
    final dinner = testRecipe(id: 'dinner', mealTypes: const {'dinner'});
    final now = DateTime(2026, 7, 6, 8); // Monday.

    expect(
      ranker.score(breakfast, testProfile(), now: now).timeOfDayBonus,
      200,
    );
    expect(ranker.score(dinner, testProfile(), now: now).timeOfDayBonus, 0);
  });

  test('evening dinner receives +90 and boundary hours do not', () {
    final dinner = testRecipe(mealTypes: const {'dinner'});

    expect(
      ranker
          .score(dinner, testProfile(), now: DateTime(2026, 7, 6, 17))
          .timeOfDayBonus,
      90,
    );
    expect(
      ranker
          .score(dinner, testProfile(), now: DateTime(2026, 7, 6, 21))
          .timeOfDayBonus,
      0,
    );
  });

  test('weekend medium/hard efforts get +90, easy stays neutral', () {
    final medium = testRecipe(effort: 'medium');
    final easy = testRecipe(id: 'easy', effort: 'easy');
    final saturday = DateTime(2026, 7, 11, 14);

    expect(ranker.score(medium, testProfile(), now: saturday).weekendBonus, 90);
    expect(ranker.score(easy, testProfile(), now: saturday).weekendBonus, 0);
  });

  test('staleness starts at 30 days; never-cooked is deliberately neutral', () {
    final recipe = testRecipe();
    final now = DateTime.utc(2026, 7, 10, 12);

    expect(
      ranker
          .score(
            recipe,
            testProfile(),
            now: now,
            lastCookedAt: now.subtract(const Duration(days: 30)),
          )
          .stalenessBonus,
      50,
    );
    expect(
      ranker
          .score(
            recipe,
            testProfile(),
            now: now,
            lastCookedAt: now.subtract(const Duration(days: 29)),
          )
          .stalenessBonus,
      0,
    );
    expect(ranker.score(recipe, testProfile(), now: now).stalenessBonus, 0);
  });

  test('rank uses latest history timestamp and stable ID tie-breaking', () {
    final a = testRecipe(id: 'a');
    final b = testRecipe(id: 'b');
    final now = DateTime.utc(2026, 7, 10, 12);
    final history = [
      CookHistoryEntry(
        id: 'old',
        recipeId: 'b',
        cookedAt: now.subtract(const Duration(days: 40)),
      ),
      CookHistoryEntry(
        id: 'new',
        recipeId: 'b',
        cookedAt: now.subtract(const Duration(days: 2)),
      ),
    ];

    final result = ranker.rank(
      [b, a],
      testProfile(),
      now: now,
      history: history,
    );
    expect(result.map((entry) => entry.recipe.id), ['a', 'b']);
  });
}
