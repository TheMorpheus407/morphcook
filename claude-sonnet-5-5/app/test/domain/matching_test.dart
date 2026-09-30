import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/corpus.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/domain/matching.dart';

import '../support/fixtures.dart';

void main() {
  late Corpus corpus;

  setUpAll(() async => corpus = await loadCorpus());

  ProfileFilter filterFor(Profile profile) => ProfileFilter.compile(profile, corpus.ontology, corpus.ingredients);

  bool visible(MetaFixture recipe, Profile profile, {bool ignoreCalories = false}) =>
      filterFor(profile).isVisible(recipe, ignoreCalories: ignoreCalories);

  group('avoid-flags', () {
    test('an empty profile sees everything', () {
      expect(visible(const MetaFixture(contains: {'pork', 'dairy', 'gluten'}), const Profile()), isTrue);
    });

    test('a recipe is hidden when contains and avoid-flags intersect', () {
      const recipe = MetaFixture(contains: {'dairy', 'egg'});
      expect(visible(recipe, const Profile(avoidFlags: {'dairy'})), isFalse);
      expect(visible(recipe, const Profile(avoidFlags: {'gluten'})), isTrue);
    });

    test('an avoided flag with no overlap leaves the recipe visible', () {
      expect(visible(const MetaFixture(contains: {'gluten'}), const Profile(avoidFlags: {'pork', 'dairy'})), isTrue);
    });

    test('class avoidance reaches specific flags below it', () {
      // "tree-nuts" covers almonds, walnuts, ...
      const almond = MetaFixture(contains: {'almonds'});
      expect(visible(almond, const Profile(avoidFlags: {'tree-nuts'})), isFalse);
      expect(visible(almond, const Profile(avoidFlags: {'walnuts'})), isTrue);
    });

    test('a recipe that lists only a specific flag still trips the class avoidance', () {
      const walnut = MetaFixture(contains: {'walnuts'});
      final result = filterFor(const Profile(avoidFlags: {'tree-nuts'})).evaluate(walnut);
      expect(result.failures, {MatchFailure.avoidFlag});
      expect(result.blockingFlags, contains('tree-nuts'));
    });

    test('an unknown avoid-flag from a later corpus release still filters', () {
      expect(
        visible(const MetaFixture(contains: {'future-flag'}), const Profile(avoidFlags: {'future-flag'})),
        isFalse,
      );
    });
  });

  group('compound flags', () {
    test('vegan hides every animal-derived flag', () {
      const profile = Profile(avoidFlags: {'vegan'});
      for (final flag in [
        'pork',
        'beef',
        'lamb',
        'poultry',
        'fish',
        'shellfish',
        'egg',
        'dairy',
        'honey',
        'gelatin-non-halal',
      ]) {
        expect(visible(MetaFixture(contains: {flag}), profile), isFalse, reason: flag);
      }
      expect(visible(const MetaFixture(contains: {'gluten', 'soy', 'sesame'}), profile), isTrue);
    });

    test('vegetarian allows egg, dairy and honey but not meat, fish or shellfish', () {
      const profile = Profile(avoidFlags: {'vegetarian'});
      expect(visible(const MetaFixture(contains: {'egg', 'dairy', 'honey'}), profile), isTrue);
      for (final flag in ['pork', 'poultry', 'fish', 'shellfish', 'gelatin-non-halal', 'gelatin-non-kosher']) {
        expect(visible(MetaFixture(contains: {flag}), profile), isFalse, reason: flag);
      }
    });

    test('pescatarian allows fish but not meat', () {
      const profile = Profile(avoidFlags: {'pescatarian'});
      expect(visible(const MetaFixture(contains: {'fish', 'shellfish'}), profile), isTrue);
      expect(visible(const MetaFixture(contains: {'beef'}), profile), isFalse);
    });

    test('halal hides pork, alcohol and non-halal gelatin', () {
      const profile = Profile(avoidFlags: {'halal'});
      expect(visible(const MetaFixture(contains: {'pork'}), profile), isFalse);
      expect(visible(const MetaFixture(contains: {'alcohol'}), profile), isFalse);
      expect(visible(const MetaFixture(contains: {'gelatin-non-halal'}), profile), isFalse);
      expect(visible(const MetaFixture(contains: {'beef', 'lamb', 'dairy'}), profile), isTrue);
    });

    test('kosher hides pork, shellfish and the meat and dairy combination', () {
      const profile = Profile(avoidFlags: {'kosher'});
      expect(visible(const MetaFixture(contains: {'pork'}), profile), isFalse);
      expect(visible(const MetaFixture(contains: {'shellfish'}), profile), isFalse);
      expect(visible(const MetaFixture(contains: {'meat-dairy-combo'}), profile), isFalse);
      expect(visible(const MetaFixture(contains: {'beef'}), profile), isTrue);
    });

    test('low-fodmap, sugar-free and lactose-free map onto one flag each', () {
      expect(visible(const MetaFixture(contains: {'high-fodmap'}), const Profile(avoidFlags: {'low-fodmap'})), isFalse);
      expect(visible(const MetaFixture(contains: {'added-sugar'}), const Profile(avoidFlags: {'sugar-free'})), isFalse);
      expect(visible(const MetaFixture(contains: {'lactose'}), const Profile(avoidFlags: {'lactose-free'})), isFalse);
      // lactose-free is a subset of dairy: cheese-free of lactose is fine.
      expect(visible(const MetaFixture(contains: {'dairy'}), const Profile(avoidFlags: {'lactose-free'})), isTrue);
    });

    test('compounds and class flags combine', () {
      const profile = Profile(avoidFlags: {'halal', 'gluten'});
      expect(visible(const MetaFixture(contains: {'gluten'}), profile), isFalse);
      expect(visible(const MetaFixture(contains: {'pork'}), profile), isFalse);
      expect(visible(const MetaFixture(contains: {'dairy'}), profile), isTrue);
    });
  });

  group('specific ingredient avoidance', () {
    test('a recipe with the avoided ingredient is hidden', () {
      const recipe = MetaFixture(ingredientIds: {'cilantro', 'onion'});
      expect(visible(recipe, const Profile(avoidIngredients: {'cilantro'})), isFalse);
      expect(visible(recipe, const Profile(avoidIngredients: {'apple'})), isTrue);
    });

    test('avoiding a parent avoids all descendants', () {
      // dairy > cow-milk > whole-milk (see the dictionary in the spec)
      expect(corpus.ingredients.contains('whole-milk'), isTrue);
      const recipe = MetaFixture(ingredientIds: {'whole-milk'});
      final parents = corpus.ingredients.ancestorsOf('whole-milk');
      expect(parents, isNotEmpty);
      for (final parent in parents) {
        expect(visible(recipe, Profile(avoidIngredients: {parent})), isFalse, reason: parent);
      }
    });

    test('avoiding a child does not avoid its parent or siblings', () {
      const recipe = MetaFixture(ingredientIds: {'parmesan'});
      expect(visible(recipe, const Profile(avoidIngredients: {'feta'})), isTrue);
    });

    test('blocking ingredients are reported', () {
      final result = filterFor(
        const Profile(avoidIngredients: {'cilantro'}),
      ).evaluate(const MetaFixture(ingredientIds: {'cilantro', 'onion'}));
      expect(result.failures, {MatchFailure.avoidIngredient});
      expect(result.blockingIngredients, {'cilantro'});
    });

    test('class and specific avoidance combine: either one excludes', () {
      const profile = Profile(avoidFlags: {'gluten'}, avoidIngredients: {'cilantro'});
      expect(visible(const MetaFixture(contains: {'gluten'}), profile), isFalse);
      expect(visible(const MetaFixture(ingredientIds: {'cilantro'}), profile), isFalse);
      expect(visible(const MetaFixture(contains: {'dairy'}, ingredientIds: {'onion'}), profile), isTrue);
    });
  });

  group('required attributes', () {
    test('every required attribute must be present', () {
      const profile = Profile(requiredAttributes: {'keto', 'high-protein'});
      expect(visible(const MetaFixture(attributes: {'keto', 'high-protein', 'easy'}), profile), isTrue);
      expect(visible(const MetaFixture(attributes: {'keto'}), profile), isFalse);
      expect(visible(const MetaFixture(), profile), isFalse);
    });

    test('missing attributes are reported', () {
      final result = filterFor(
        const Profile(requiredAttributes: {'keto', 'halal'}),
      ).evaluate(const MetaFixture(attributes: {'halal'}));
      expect(result.missingAttributes, {'keto'});
      expect(result.failures, {MatchFailure.requiredAttribute});
    });
  });

  group('time budget', () {
    test('a recipe within the budget is visible, one over it is not', () {
      const profile = Profile(maxTimeMinutes: 30);
      expect(visible(const MetaFixture(timeMinutes: 30), profile), isTrue);
      expect(visible(const MetaFixture(timeMinutes: 31), profile), isFalse);
      expect(visible(const MetaFixture(timeMinutes: 5), profile), isTrue);
    });

    test('no budget means no limit', () {
      expect(visible(const MetaFixture(timeMinutes: 600), const Profile()), isTrue);
    });
  });

  group('calorie target', () {
    test('the default tolerance is 150 kcal either way', () {
      const profile = Profile(calorieTarget: 500);
      expect(profile.calorieTolerance, 150);
      expect(visible(const MetaFixture(caloriesPerServing: 650), profile), isTrue);
      expect(visible(const MetaFixture(caloriesPerServing: 350), profile), isTrue);
      expect(visible(const MetaFixture(caloriesPerServing: 651), profile), isFalse);
      expect(visible(const MetaFixture(caloriesPerServing: 349), profile), isFalse);
    });

    test('a custom tolerance is honoured', () {
      const profile = Profile(calorieTarget: 500, calorieTolerance: 50);
      expect(visible(const MetaFixture(caloriesPerServing: 550), profile), isTrue);
      expect(visible(const MetaFixture(caloriesPerServing: 551), profile), isFalse);
    });

    test('the per-dish override lifts only the calorie rule', () {
      const profile = Profile(calorieTarget: 400, avoidFlags: {'dairy'}, maxTimeMinutes: 30);
      const heavy = MetaFixture(caloriesPerServing: 900, timeMinutes: 20);
      expect(visible(heavy, profile), isFalse);
      expect(visible(heavy, profile, ignoreCalories: true), isTrue);
      // The override never lifts allergen or time rules.
      expect(
        visible(const MetaFixture(caloriesPerServing: 900, contains: {'dairy'}), profile, ignoreCalories: true),
        isFalse,
      );
      expect(
        visible(const MetaFixture(caloriesPerServing: 900, timeMinutes: 45), profile, ignoreCalories: true),
        isFalse,
      );
    });

    test('no calorie target means no calorie filter', () {
      expect(visible(const MetaFixture(caloriesPerServing: 5000), const Profile()), isTrue);
    });
  });

  group('the whole rule', () {
    test('all five rules must hold at once', () {
      const profile = Profile(
        avoidFlags: {'dairy'},
        avoidIngredients: {'cilantro'},
        requiredAttributes: {'halal'},
        maxTimeMinutes: 45,
        calorieTarget: 600,
      );
      const good = MetaFixture(
        attributes: {'halal'},
        timeMinutes: 40,
        caloriesPerServing: 620,
        ingredientIds: {'onion'},
      );
      expect(visible(good, profile), isTrue);
      expect(
        visible(
          const MetaFixture(attributes: {'halal'}, timeMinutes: 40, caloriesPerServing: 620, contains: {'dairy'}),
          profile,
        ),
        isFalse,
      );
      expect(
        visible(
          const MetaFixture(
            attributes: {'halal'},
            timeMinutes: 40,
            caloriesPerServing: 620,
            ingredientIds: {'cilantro'},
          ),
          profile,
        ),
        isFalse,
      );
      expect(visible(const MetaFixture(timeMinutes: 40, caloriesPerServing: 620), profile), isFalse);
      expect(
        visible(const MetaFixture(attributes: {'halal'}, timeMinutes: 50, caloriesPerServing: 620), profile),
        isFalse,
      );
      expect(
        visible(const MetaFixture(attributes: {'halal'}, timeMinutes: 40, caloriesPerServing: 900), profile),
        isFalse,
      );
    });

    test('every failing rule is listed', () {
      final result = filterFor(
        const Profile(avoidFlags: {'dairy'}, maxTimeMinutes: 10, calorieTarget: 300),
      ).evaluate(const MetaFixture(contains: {'dairy'}, timeMinutes: 30, caloriesPerServing: 800));
      expect(result.failures, {MatchFailure.avoidFlag, MatchFailure.timeBudget, MatchFailure.calorieTarget});
      expect(result.visible, isFalse);
    });

    test('isRecipeVisible is the same function without the compiled filter', () {
      const profile = Profile(avoidFlags: {'vegan'});
      expect(
        isRecipeVisible(const MetaFixture(contains: {'egg'}), profile, corpus.ontology, corpus.ingredients),
        isFalse,
      );
      expect(
        isRecipeVisible(const MetaFixture(contains: {'gluten'}), profile, corpus.ontology, corpus.ingredients),
        isTrue,
      );
    });

    test('filter() keeps order and only visible recipes', () {
      final filter = filterFor(const Profile(avoidFlags: {'dairy'}));
      const all = [
        MetaFixture(id: 'a'),
        MetaFixture(id: 'b', contains: {'dairy'}),
        MetaFixture(id: 'c', contains: {'gluten'}),
      ];
      expect(filter.filter(all).map((r) => r.id), ['a', 'c']);
    });

    test('isSafe only looks at allergens and avoided ingredients', () {
      final filter = filterFor(
        const Profile(avoidFlags: {'dairy'}, maxTimeMinutes: 10, calorieTarget: 200, requiredAttributes: {'keto'}),
      );
      expect(filter.isSafe(const MetaFixture(timeMinutes: 90, caloriesPerServing: 900)), isTrue);
      expect(filter.isSafe(const MetaFixture(contains: {'dairy'})), isFalse);
    });
  });

  group('against the shipped corpus', () {
    test('every recipe of a vegan profile is free of animal flags', () async {
      final filter = filterFor(const Profile(avoidFlags: {'vegan'}));
      final vegan = corpus.ontology.expandAvoidFlags(['vegan']);
      var checked = 0;
      for (final dish in corpus.dishes.values) {
        for (final recipe in await corpus.loadDish(dish.id)) {
          if (filter.isVisible(recipe)) {
            expect(recipe.contains.intersection(vegan), isEmpty, reason: recipe.id);
            checked++;
          }
        }
      }
      expect(checked, greaterThan(20));
    });

    test('a nut-allergic profile never sees a recipe containing nuts', () async {
      final filter = filterFor(const Profile(avoidFlags: {'tree-nuts', 'peanuts'}));
      for (final dish in corpus.dishes.values) {
        for (final recipe in await corpus.loadDish(dish.id)) {
          if (filter.isVisible(recipe)) {
            expect(
              recipe.contains.intersection({'tree-nuts', 'peanuts', 'almonds', 'walnuts', 'cashews'}),
              isEmpty,
              reason: recipe.id,
            );
          }
        }
      }
    });

    // The soul of the product: the same dish exists for every body. The shipped
    // corpus keeps a version of every dish for each of these profiles. Rarer
    // needs (low-FODMAP, mustard, celery, caffeine) are filled in by the
    // pipeline over time, see docs/asset-partitioning-strategy.md.
    const covered = <String, List<String>>{
      'vegan': ['vegan'],
      'vegetarian': ['vegetarian'],
      'pescatarian': ['pescatarian'],
      'halal': ['halal'],
      'kosher': ['kosher'],
      'no gluten': ['gluten'],
      'no dairy': ['dairy'],
      'no lactose': ['lactose-free'],
      'no eggs': ['egg'],
      'no nuts': ['tree-nuts', 'peanuts'],
      'no soy': ['soy'],
      'no sesame': ['sesame'],
      'no seafood': ['fish', 'shellfish', 'molluscs'],
      'no pork': ['pork'],
      'no alcohol': ['alcohol'],
    };
    for (final entry in covered.entries) {
      test('every dish has a version for: ${entry.key}', () async {
        final filter = filterFor(Profile(avoidFlags: entry.value.toSet()));
        final missing = <String>[];
        for (final dish in corpus.dishes.values) {
          if (!(await corpus.loadDish(dish.id)).any(filter.isVisible)) missing.add(dish.id);
        }
        expect(missing, isEmpty);
      });
    }
  });
}
