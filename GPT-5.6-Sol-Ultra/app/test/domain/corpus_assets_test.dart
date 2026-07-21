import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/data.dart';
import 'package:morphcook/domain/domain.dart';

void main() {
  late BundledRecipeRepository repository;

  setUp(() {
    repository = BundledRecipeRepository(
      assetLoader: (path) => File(path).readAsString(),
    );
  });

  test(
    'the complete bundled corpus loads and passes referential integrity',
    () async {
      await repository.initialize();
      final launchRecipeIds = repository.recipes
          .map((recipe) => recipe.id)
          .toSet();
      final launchDishIds = repository.recipes
          .map((recipe) => recipe.dishId)
          .toSet();
      final defaultProfile = UserProfile(name: 'First run');
      final visibleLaunchDishes = repository
          .visibleRecipes(defaultProfile)
          .map((recipe) => recipe.dishId)
          .toSet();

      expect(launchRecipeIds.length, greaterThanOrEqualTo(16));
      expect(
        launchDishIds,
        containsAll(repository.dishes.map((dish) => dish.id)),
      );
      expect(
        visibleLaunchDishes.length,
        greaterThanOrEqualTo(3),
        reason: 'the default 600±150 feed must not collapse to one dish',
      );
      for (final partitionId in repository.manifest.partitions.keys) {
        await repository.ensurePartitionLoaded(partitionId);
      }

      final report = repository.validateIntegrity();
      final details = report.issues
          .map((issue) => '${issue.code} ${issue.entityId}: ${issue.message}')
          .join('\n');
      expect(report.isValid, isTrue, reason: details);
      expect(repository.dishes.length, greaterThanOrEqualTo(6));
      expect(repository.recipes.length, greaterThanOrEqualTo(20));
      expect(
        launchRecipeIds.length / repository.recipes.length,
        greaterThanOrEqualTo(.8),
      );
      expect(repository.loadedPartitionIds, hasLength(5));
      expect(repository.ingredientGuideEntries, isNotEmpty);
      expect(repository.faqs.length, greaterThanOrEqualTo(8));

      for (final guide in repository.ingredientGuideEntries) {
        expect(
          guide.usageTips.resolve('en').trim(),
          isNotEmpty,
          reason: '${guide.ingredientId} needs EN usage tips',
        );
        expect(
          guide.usageTips.resolve('de').trim(),
          isNotEmpty,
          reason: '${guide.ingredientId} needs DE usage tips',
        );
        expect(guide.usageTipItems, isNotEmpty);
      }
      for (final faq in repository.faqs) {
        expect(faq.keywords['en'], isNotEmpty, reason: faq.id);
        expect(faq.keywords['de'], isNotEmpty, reason: faq.id);
        expect(faq.relatedRoute, isNotNull, reason: faq.id);
        expect(faq.contextualLinks, contains(faq.relatedRoute));
      }
      final relatedFaq = repository.faqs.firstWhere(
        (faq) => faq.relatedFaqIds.isNotEmpty,
      );
      expect(relatedFaq.contextualLinks, containsAll(relatedFaq.relatedFaqIds));

      final cuisineIndexes = repository.manifest.partitions.values.where(
        (partition) => partition.kind == PartitionKind.cuisine,
      );
      expect(cuisineIndexes, hasLength(3));
      for (final partition in cuisineIndexes) {
        expect(partition.recipeCount, 0);
        expect(partition.recipeIds, isNotEmpty);
        expect(partition.indexedRecipeCount, partition.recipeIds.length);
        expect(
          partition.recipeIds,
          everyElement(isIn(repository.recipesById.keys)),
        );
      }
      expect(
        repository.manifest.dishRoutes.values.expand(
          (route) => route.discoveryPartitions,
        ),
        isNotEmpty,
      );

      for (final dish in repository.dishes) {
        final variants = repository.recipesForDish(dish.id);
        expect(variants.length, greaterThanOrEqualTo(3), reason: dish.id);
        expect(
          variants.any((recipe) => recipe.attributes.contains('halal')),
          isTrue,
          reason: '${dish.id} needs a halal-compatible recipe',
        );
        expect(
          variants.any((recipe) => recipe.attributes.contains('kosher')),
          isTrue,
          reason: '${dish.id} needs a kosher-compatible recipe',
        );
      }

      for (final requirement in const ['halal', 'kosher']) {
        final profile = UserProfile(
          name: requirement,
          requiredAttributes: {requirement},
          maxTimeMinutes: 180,
          calorieTarget: 0,
        );
        final coveredDishes = repository
            .visibleRecipes(profile)
            .map((recipe) => recipe.dishId)
            .toSet();
        expect(
          coveredDishes,
          containsAll(repository.dishes.map((dish) => dish.id)),
          reason: '$requirement compatibility should cover every dish',
        );
      }
    },
  );

  test('SPEC avoidance examples all resolve in bilingual typeahead', () async {
    await repository.initialize();

    expect(
      repository.ingredients.search('apples').map((item) => item.id),
      contains('apple'),
    );
    expect(
      repository.ingredients
          .search('Äpfel', languageCode: 'de')
          .map((item) => item.id),
      contains('apple'),
    );
    expect(
      repository.ingredients.search('cilantro').map((item) => item.id),
      contains('fresh-cilantro'),
    );
    expect(
      repository.ingredients.search('bell peppers').map((item) => item.id),
      contains('bell-peppers'),
    );
  });

  test('parent ingredient avoidance hides recipes using descendants', () async {
    await repository.initialize();
    await repository.loadRecipesForDish('shakshuka');
    final recipe = repository.recipes.firstWhere(
      (candidate) => candidate.ingredientIds.contains('red-bell-pepper'),
    );
    final profile = UserProfile(
      name: 'Pepper-free',
      avoidIngredientIds: const {'bell-peppers'},
      maxTimeMinutes: 180,
      calorieTarget: 0,
    );

    expect(repository.matcher.isVisible(recipe, profile), isFalse);
  });

  test('onboarding nuts alias expands to concrete nut flags', () async {
    await repository.initialize();
    await repository.loadRecipesForDish('fettuccine-alfredo');
    final nutRecipe = repository.recipes.firstWhere(
      (recipe) => recipe.contains.contains('tree-nuts'),
    );
    final profile = UserProfile(
      name: 'Nut-free',
      avoidFlags: const {'nuts'},
      maxTimeMinutes: 180,
      calorieTarget: 0,
    );

    expect(
      repository.ontology.expandAvoidFlags(const {'nuts'}),
      contains('tree-nuts'),
    );
    expect(repository.matcher.isVisible(nutRecipe, profile), isFalse);
  });

  test(
    'bilingual corpus search finds titles, synonyms, and FAQ copy',
    () async {
      await repository.initialize();
      final profile = UserProfile(
        name: 'Search',
        maxTimeMinutes: 180,
        calorieTarget: 0,
      );

      final doener = await repository.search(
        SearchQuery(text: 'Döner', languageCode: 'de'),
        profile,
      );
      final alfredo = await repository.search(
        SearchQuery(text: 'creamy pasta', languageCode: 'en'),
        profile,
      );

      expect(doener.items, isNotEmpty);
      expect(
        doener.items.every((item) => item.recipe.dishId == 'doener'),
        isTrue,
      );
      expect(
        alfredo.items.any((item) => item.recipe.dishId == 'fettuccine-alfredo'),
        isTrue,
      );
      expect(repository.searchFaqs('sichtbar', languageCode: 'de'), isNotEmpty);
    },
  );

  test(
    'bundled search index routes only matching content partitions',
    () async {
      final raw =
          jsonDecode(await File('assets/search-index.json').readAsString())
              as Map<String, dynamic>;
      final indexed = (raw['partitions'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(indexed.map((entry) => entry['partition_id']).toSet(), {
        'core',
        'extended',
      });
      for (final entry in indexed) {
        final text = entry['text'] as Map<String, dynamic>;
        expect((text['en'] as String).trim(), isNotEmpty);
        expect((text['de'] as String).trim(), isNotEmpty);
      }

      await repository.initialize();
      final profile = UserProfile(
        name: 'Index',
        maxTimeMinutes: 180,
        calorieTarget: 0,
      );
      await repository.search(SearchQuery(text: 'beef döner'), profile);
      expect(repository.loadedPartitionIds, {'core'});
      final extended = await repository.search(
        SearchQuery(text: 'green shakshuka'),
        profile,
      );
      expect(extended.items.single.recipe.id, 'shakshuka-keto-hard-hearty');
      expect(repository.loadedPartitionIds, {'core', 'extended'});
    },
  );
}
