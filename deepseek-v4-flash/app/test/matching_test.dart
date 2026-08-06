import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/corpus.dart';
import 'package:morphcook/logic/matching.dart';
import 'package:morphcook/models/models.dart';

Recipe _recipe({
  required String id,
  String diet = 'classic',
  Set<String> contains = const {},
  List<String> attributes = const [],
  int time = 30,
  int calories = 500,
  List<IngredientRef>? ingredients,
}) {
  return Recipe(
    id: id,
    dishId: 'dish',
    title: {'en': id},
    summary: {'en': id},
    diet: diet,
    contains: contains,
    attributes: attributes,
    timeMinutes: time,
    calories: calories,
    protein: 0,
    carbs: 0,
    fat: 0,
    servings: 2,
    mealTypes: ['dinner'],
    tags: const [],
    ingredients: ingredients ?? const [],
    steps: const [],
  );
}

/// Minimal corpus with an ingredient tree:
///   dairy → cheese → parmesan
///   nuts-seeds → almonds
Corpus _corpus() {
  final corpus = Corpus();
  final parmesan = IngredientNode(
      id: 'parmesan',
      label: {'en': 'parmesan', 'de': 'parmesan'},
      children: const [],
      parentId: 'cheese',
      rootId: 'dairy');
  final cheese = IngredientNode(
      id: 'cheese',
      label: {'en': 'cheese', 'de': 'käse'},
      children: [parmesan],
      parentId: 'dairy',
      rootId: 'dairy');
  final dairy = IngredientNode(
      id: 'dairy',
      label: {'en': 'dairy', 'de': 'milchprodukte'},
      children: [cheese],
      rootId: 'dairy');
  final almonds = IngredientNode(
      id: 'almonds',
      label: {'en': 'almonds', 'de': 'mandeln'},
      children: const [],
      parentId: 'tree-nuts',
      rootId: 'nuts-seeds');
  final treeNuts = IngredientNode(
      id: 'tree-nuts',
      label: {'en': 'tree nuts', 'de': 'schalenfrüchte'},
      children: [almonds],
      parentId: 'nuts-seeds',
      rootId: 'nuts-seeds');
  final nuts = IngredientNode(
      id: 'nuts-seeds',
      label: {'en': 'nuts & seeds', 'de': 'nüsse & saat'},
      children: [treeNuts],
      rootId: 'nuts-seeds');

  for (final n in [dairy, nuts]) {
    corpus.ingredientRoots.add(n);
    void reg(IngredientNode node) {
      corpus.ingredientsById[node.id] = node;
      node.children.forEach(reg);
    }

    reg(n);
  }

  corpus.ontology = Ontology(
    containsFlags: ['dairy', 'gluten', 'pork', 'tree-nuts', 'egg'],
    compoundAvoids: {
      'vegan': CompoundAvoid(
          id: 'vegan',
          label: const {},
          expandsTo: const ['dairy', 'egg']),
      'vegetarian': CompoundAvoid(
          id: 'vegetarian',
          label: const {},
          expandsTo: const ['pork']),
    },
    attributes: {
      'grill': {},
      'roast': {},
    },
    dietOrder: const ['vegetarian', 'vegan'],
  );
  return corpus;
}

UserProfile _profile({Set<String>? flags, Set<String>? ings}) => UserProfile(
      avoidFlags: flags ?? {},
      avoidIngredients: ings ?? {},
    );

void main() {
  group('visible() — flag avoidance', () {
    test('compound avoids expand to raw contains flags', () {
      final matcher = RecipeMatcher(_corpus());
      final r = _recipe(id: 'a', contains: {'dairy'});
      expect(matcher.visible(r, _profile(flags: {'vegan'})), isFalse);
      expect(matcher.visible(r, _profile(flags: {'vegetarian'})), isTrue);
    });

    test('empty profile sees everything', () {
      final matcher = RecipeMatcher(_corpus());
      expect(matcher.visible(_recipe(id: 'a', contains: {'pork'}), _profile()),
          isTrue);
    });
  });

  group('visible() — specific ingredient avoidance propagates down the tree',
      () {
    test('recipe with leaf conflicts with parent avoidance', () {
      final matcher = RecipeMatcher(_corpus());
      final r = _recipe(
          id: 'a', ingredients: [IngredientRef(id: 'almonds', amount: 1, unit: 'g')]);
      expect(matcher.visible(r, _profile(ings: {'tree-nuts'})), isFalse);
    });

    test('avoiding a leaf does not hide a recipe that lists only the parent',
        () {
      final matcher = RecipeMatcher(_corpus());
      final r = _recipe(
          id: 'a', ingredients: [IngredientRef(id: 'dairy', amount: 1, unit: 'cup')]);
      expect(matcher.visible(r, _profile(ings: {'parmesan'})), isTrue);
    });

    test('avoiding parmesan does not hide a dairy recipe without it', () {
      final matcher = RecipeMatcher(_corpus());
      final r = _recipe(
          id: 'a', ingredients: [IngredientRef(id: 'cheese', amount: 1, unit: 'cup')]);
      expect(matcher.visible(r, _profile(ings: {'parmesan'})), isTrue);
    });

    test('exact leaf match hides', () {
      final matcher = RecipeMatcher(_corpus());
      final r = _recipe(
          id: 'a', ingredients: [IngredientRef(id: 'parmesan', amount: 1, unit: 'g')]);
      expect(matcher.visible(r, _profile(ings: {'parmesan'})), isFalse);
    });
  });

  group('visible() — attributes, time, calories', () {
    test('required attributes must all be present', () {
      final matcher = RecipeMatcher(_corpus());
      final r = _recipe(id: 'a', attributes: ['grill']);
      final p = UserProfile(requiredAttributes: {'grill', 'roast'});
      expect(matcher.visible(r, p), isFalse);
      final p2 = UserProfile(requiredAttributes: {'grill'});
      expect(matcher.visible(r, p2), isTrue);
    });

    test('time budget', () {
      final matcher = RecipeMatcher(_corpus());
      final r = _recipe(id: 'a', time: 45);
      expect(matcher.visible(r, UserProfile(maxTimeMinutes: 30)), isFalse);
      expect(matcher.visible(r, UserProfile(maxTimeMinutes: 45)), isTrue);
    });

    test('calorie tolerance ±150', () {
      final matcher = RecipeMatcher(_corpus());
      final r = _recipe(id: 'a', calories: 500);
      expect(matcher.visible(r, UserProfile(calorieTarget: 349)), isFalse);
      expect(matcher.visible(r, UserProfile(calorieTarget: 350)), isTrue);
      expect(matcher.visible(r, UserProfile(calorieTarget: 650)), isTrue);
      expect(matcher.visible(r, UserProfile(calorieTarget: 651)), isFalse);
    });
  });

  group('rankScore', () {
    test('required attribute match dominates', () {
      final matcher = RecipeMatcher(_corpus());
      final p = UserProfile(requiredAttributes: {'grill'}, preferredEffort: 'easy');
      final hits = _recipe(id: 'a', attributes: ['grill'], time: 60);
      final misses = _recipe(id: 'b', attributes: ['roast'], time: 10);
      expect(
        matcher.rankScore(hits, p),
        greaterThan(matcher.rankScore(misses, p)),
      );
    });

    test('effort match beats time closeness alone', () {
      final matcher = RecipeMatcher(_corpus());
      final p = UserProfile(preferredEffort: 'easy', maxTimeMinutes: 60);
      final easy = _recipe(id: 'a', attributes: ['easy'], time: 55);
      final medium = _recipe(id: 'b', attributes: ['medium'], time: 5);
      expect(
        matcher.rankScore(easy, p),
        greaterThan(matcher.rankScore(medium, p)),
      );
    });

    test('closer time ranks higher', () {
      final matcher = RecipeMatcher(_corpus());
      final p = UserProfile(maxTimeMinutes: 60);
      final fast = _recipe(id: 'a', time: 10);
      final slow = _recipe(id: 'b', time: 59);
      expect(
        matcher.rankScore(fast, p),
        greaterThan(matcher.rankScore(slow, p)),
      );
    });
  });

  group('bestForDish', () {
    test('picks the visible best', () {
      final corpus = _corpus();
      final matcher = RecipeMatcher(corpus);
      final p = UserProfile(avoidFlags: {'vegan'});
      final veganOk = _recipe(id: 'v', diet: 'vegan', attributes: ['easy']);
      final dairyBad = _recipe(id: 'd', diet: 'classic', contains: {'dairy'});
      corpus.recipesInPartition['core'] = [veganOk, dairyBad];
      final dish = Dish(
        id: 'dish',
        canonicalName: const {'en': 'dish'},
        heroText: const {},
        capCaption: const {},
        stripeColor: const Color(0xFF000000),
        variantIds: const ['v', 'd'],
        partitionId: 'core',
        secondaryPartitions: const [],
        cuisineTags: const [],
      );
      expect(matcher.bestForDish(dish, p)?.id, 'v');
    });
  });

  group('VariantGeometry', () {
    test('combos exist / missing combos are distinguishable', () {
      final recipes = [
        _recipe(id: '1', diet: 'classic', attributes: ['easy', '≤400']),
        _recipe(id: '2', diet: 'vegan', attributes: ['hard', '>800']),
      ];
      final g = VariantGeometry(
          dish: Dish(
            id: 'd',
            canonicalName: const {'en': 'd'},
            heroText: const {},
            capCaption: const {},
            stripeColor: const Color(0xFF000000),
            variantIds: const [],
            partitionId: 'core',
            secondaryPartitions: const [],
            cuisineTags: const [],
          ),
          variants: recipes);
      expect(g.comboExists('classic', 'easy', '≤400'), isTrue);
      expect(g.comboExists('vegan', 'easy', '≤400'), isFalse);
      expect(g.comboExists('vegan', 'hard', '>800'), isTrue);
    });

    test('settle relaxes effort/bucket to a reachable combo', () {
      final recipes = [
        _recipe(id: '1', diet: 'classic', attributes: ['easy', '≤400']),
        _recipe(id: '2', diet: 'vegan', attributes: ['hard', '>800']),
      ];
      final g = VariantGeometry(
          dish: Dish(
            id: 'd',
            canonicalName: const {'en': 'd'},
            heroText: const {},
            capCaption: const {},
            stripeColor: const Color(0xFF000000),
            variantIds: const [],
            partitionId: 'core',
            secondaryPartitions: const [],
            cuisineTags: const [],
          ),
          variants: recipes);
      final r = g.settle(
        diet: 'vegan',
        effort: 'easy',
        bucket: '≤400',
        profile: UserProfile(),
      );
      expect(r.diet, 'vegan');
      expect(g.comboExists(r.diet, r.effort, r.bucket), isTrue);
    });
  });

  group('homeScore — staleness', () {
    test('stale (>30 days) recipes get promoted over fresh ones', () {
      final matcher = RecipeMatcher(_corpus());
      final now = DateTime(2026, 8, 5);
      final stale = _recipe(id: 'old', time: 60);
      final fresh = _recipe(id: 'new', time: 10);
      final ctx = RankingContext(
        now: now,
        lastCookedByRecipe: {
          'old': now.subtract(const Duration(days: 40)),
          'new': now.subtract(const Duration(days: 2)),
        },
      );
      final p = UserProfile();
      final staleScore = homeScore(stale, ctx, p, matcher);
      final freshScore = homeScore(fresh, ctx, p, matcher);
      expect(staleScore, greaterThan(freshScore));
    });

    test('breakfast gets a morning bonus', () {
      final matcher = RecipeMatcher(_corpus());
      final now = DateTime(2026, 8, 5, 8);
      final breakfast = Recipe(
        id: 'bf',
        dishId: 'dish',
        title: const {'en': 'bf'},
        summary: const {'en': 'bf'},
        diet: 'classic',
        contains: const {},
        attributes: const [],
        timeMinutes: 30,
        calories: 500,
        protein: 0,
        carbs: 0,
        fat: 0,
        servings: 2,
        mealTypes: ['breakfast'],
        tags: const [],
        ingredients: const [],
        steps: const [],
      );
      final dinner = _recipe(id: 'din', time: 30);
      final ctx = RankingContext(now: now);
      expect(homeScore(breakfast, ctx, UserProfile(), matcher),
          greaterThan(homeScore(dinner, ctx, UserProfile(), matcher)));
    });
  });
}