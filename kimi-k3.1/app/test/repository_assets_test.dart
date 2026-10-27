import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/services/recipe_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecipeRepository repository;

  setUpAll(() async {
    repository = RecipeRepository();
    await repository.load();
  });

  test('bundled corpus loads core first with every supporting collection', () {
    expect(repository.dishes, hasLength(12));
    expect(repository.recipes, hasLength(50));
    expect(repository.searchEntries, hasLength(60));
    expect(repository.loadedPartitions, contains('core'));
    expect(repository.loadedPartitions, isNot(contains('extended')));
    expect(repository.faqs.length, greaterThanOrEqualTo(18));
    expect(repository.ingredientGuide.length, greaterThanOrEqualTo(18));
    expect(repository.ingredients.entries.length, greaterThan(100));
  });

  test('on-demand extended partition loads through real search', () async {
    final page = await repository.search(
      'ramen',
      {},
      const Profile(onboardingComplete: true),
      now: DateTime(2026, 4, 13, 7),
    );
    expect(page.recipes, isNotEmpty);
    expect(page.recipes.every((recipe) => recipe.dishId == 'ramen'), isTrue);
    expect(repository.loadedPartitions, contains('extended'));
    expect(repository.recipes, hasLength(60));
  });

  test(
    'empty search uses stable 20-item cursors and dimension tag filters',
    () async {
      final profile = const Profile(
        onboardingComplete: true,
        maxTimeMinutes: 120,
        calorieTolerance: 400,
      );
      final first = await repository.search(
        '',
        {'vegan'},
        profile,
        now: DateTime(2026, 4, 13),
      );
      expect(first.recipes, hasLength(20));
      expect(first.recipes.every((recipe) => recipe.diet == 'vegan'), isTrue);
      expect(first.nextCursor, isNotNull);
      final second = await repository.search(
        '',
        {'vegan'},
        profile,
        after: first.nextCursor,
        now: DateTime(2026, 4, 13),
      );
      expect(second.recipes, hasLength(16));
      expect(second.recipes.every((recipe) => recipe.diet == 'vegan'), isTrue);
      final ids = {
        ...first.recipes.map((recipe) => recipe.id),
        ...second.recipes.map((recipe) => recipe.id),
      };
      expect(ids, hasLength(36));
    },
  );

  test(
    'profile matching removes animal products and honors required attributes',
    () async {
      final profile = const Profile(
        avoidFlags: {'vegan'},
        requiredAttributes: {'halal'},
        onboardingComplete: true,
      );
      final page = await repository.search(
        'döner',
        {},
        profile,
        now: DateTime(2026, 4, 13),
      );
      expect(page.recipes, isNotEmpty);
      for (final recipe in page.recipes) {
        expect(repository.matcher.visible(recipe, profile), isTrue);
        expect(recipe.contains, isNot(contains('poultry')));
        expect(recipe.attributes, contains('halal'));
      }
    },
  );

  test(
    'every dish has five standalone variants and guide/FAQ content is bilingual',
    () async {
      for (final dish in repository.dishes.values) {
        final variants = await repository.recipesForDish(dish);
        expect(variants, hasLength(5), reason: dish.id);
        for (final recipe in variants) {
          expect(recipe.steps, hasLength(5), reason: recipe.id);
          expect(recipe.title.values.keys, containsAll(['en', 'de']));
          expect(
            recipe.ingredientIds,
            recipe.ingredients.map((item) => item.id).toSet(),
          );
        }
      }
      for (final faq in repository.faqs) {
        expect(faq.question.values['en'], isNotEmpty);
        expect(faq.question.values['de'], isNotEmpty);
        expect(faq.answer.values['en'], isNotEmpty);
        expect(faq.answer.values['de'], isNotEmpty);
      }
    },
  );
}
