import 'package:flutter_test/flutter_test.dart' hide Matcher;
import 'package:morphcook/core/matching.dart';
import 'package:morphcook/core/model/ingredient.dart';
import 'package:morphcook/core/model/localized.dart';
import 'package:morphcook/core/model/ontology.dart';
import 'package:morphcook/core/model/profile.dart';
import 'package:morphcook/core/model/recipe.dart';

/// The matching algorithm is a pure function and heavily tested (SPEC):
///
/// ```
/// visible(recipe, profile) :=
///     recipe.contains ∩ profile.avoid_flags = ∅
///     AND profile.avoid_ingredients ∩ recipe.ingredient_ids = ∅
///     AND profile.required_attributes ⊆ recipe.attributes
///     AND recipe.time_minutes ≤ profile.max_time_minutes
///     AND |recipe.calories_per_serving − profile.calorie_target| ≤ tolerance
/// ```
const ontology = Ontology(
  containsFlags: ['dairy', 'gluten', 'meat', 'egg', 'fish', 'nuts', 'soy'],
  compoundAvoidFlags: {
    'vegan': ['dairy', 'meat', 'egg', 'fish'],
    'vegetarian': ['meat', 'fish'],
    'dairy-free': ['dairy'],
    'nut-free': ['nuts'],
  },
  attributes: {
    'effort': ['easy', 'medium', 'hard'],
    'time_bucket': ['≤15', '≤30', '≤60', '>60'],
    'calorie_bucket': ['≤400', '≤600', '≤800', '>800'],
    'technique': ['one-pot', 'no-cook'],
  },
  dietOptions: ['classic', 'vegan', 'vegetarian', 'keto', 'halal'],
);

final ingredients = IngredientDictionary([
  IngredientNode(
    id: 'dairy',
    name: const LocalizedText({'en': 'dairy'}),
    aisle: 'dairy',
    children: [
      IngredientNode(
        id: 'milk',
        name: const LocalizedText({'en': 'milk'}),
        aisle: 'dairy',
        children: [
          IngredientNode(
            id: 'whole-milk',
            name: const LocalizedText({'en': 'whole milk'}),
            aisle: 'dairy',
          ),
        ],
      ),
    ],
  ),
  IngredientNode(
    id: 'garlic',
    name: const LocalizedText({'en': 'garlic'}),
    aisle: 'produce',
  ),
  IngredientNode(
    id: 'lamb',
    name: const LocalizedText({'en': 'lamb'}),
    aisle: 'meat',
  ),
  IngredientNode(
    id: 'tofu',
    name: const LocalizedText({'en': 'tofu'}),
    aisle: 'produce',
  ),
]);

const _title = LocalizedText({'en': 'dish'});

Recipe recipe({
  String id = 'r',
  Set<String> contains = const {},
  List<String> ingredientIds = const [],
  Set<String> attributes = const {},
  int timeMinutes = 30,
  int calories = 600,
  String effort = 'medium',
  String mealType = 'dinner',
}) =>
    Recipe(
      id: id,
      dishId: 'dish',
      title: _title,
      subtitle: _title,
      diet: 'classic',
      effort: effort,
      timeMinutes: timeMinutes,
      caloriesPerServing: calories,
      servings: 2,
      contains: contains,
      attributes: attributes,
      tags: const [],
      mealType: mealType,
      ingredients: [
        for (final iid in ingredientIds)
          IngredientLine(ingredientId: iid, amount: 1, unit: 'piece'),
      ],
      steps: const [CookStep(text: _title)],
      macros: const Macros(kcal: 600, proteinG: 20, carbsG: 60, fatG: 20),
    );

const profile = UserProfile(); // target 600 kcal, 60 min, medium effort

Matcher get matcher => Matcher(ontology: ontology, ingredients: ingredients);

void main() {
  group('isVisible — hard filters', () {
    test('a clean profile sees a clean recipe', () {
      expect(matcher.isVisible(recipe(), profile), true);
    });

    test('class avoid-flag intersection hides the recipe', () {
      final r = recipe(contains: {'dairy'});
      expect(matcher.isVisible(r, profile.copyWith(avoidFlags: {'dairy'})), false);
      // …but not when the profile avoids something else
      expect(matcher.isVisible(r, profile.copyWith(avoidFlags: {'nuts'})), true);
    });

    test('compound avoid-flags expand before matching', () {
      final r = recipe(contains: {'dairy'});
      // "vegan" expands to dairy/meat/egg/fish — one member is enough to hide.
      expect(matcher.isVisible(r, profile.copyWith(avoidFlags: {'vegan'})), false);
      final meat = recipe(contains: {'meat'});
      expect(matcher.isVisible(meat, profile.copyWith(avoidFlags: {'vegan'})), false);
      expect(matcher.isVisible(meat, profile.copyWith(avoidFlags: {'vegetarian'})), false);
      expect(matcher.isVisible(meat, profile.copyWith(avoidFlags: {'dairy-free'})), true);
    });

    test('specific avoid-ingredients hide the recipe', () {
      final r = recipe(ingredientIds: ['garlic']);
      expect(matcher.isVisible(r, profile.copyWith(avoidIngredients: {'garlic'})), false);
      expect(matcher.isVisible(r, profile.copyWith(avoidIngredients: {'tofu'})), true);
    });

    test('parent-level ingredient avoidance propagates to descendants', () {
      final r = recipe(ingredientIds: ['whole-milk']);
      // avoiding "dairy" (or "milk") excludes whole-milk recipes
      expect(matcher.isVisible(r, profile.copyWith(avoidIngredients: {'dairy'})), false);
      expect(matcher.isVisible(r, profile.copyWith(avoidIngredients: {'milk'})), false);
      expect(matcher.isVisible(r, profile.copyWith(avoidIngredients: {'garlic'})), true);
    });

    test('required attributes must all be present', () {
      final r = recipe(attributes: {'halal', 'one-pot'});
      expect(matcher.isVisible(r, profile.copyWith(requiredAttributes: {'halal'})), true);
      expect(
        matcher.isVisible(r, profile.copyWith(requiredAttributes: {'halal', 'one-pot'})),
        true,
      );
      expect(
        matcher.isVisible(r, profile.copyWith(requiredAttributes: {'halal', 'no-cook'})),
        false,
      );
    });

    test('time budget is a hard filter', () {
      final r = recipe(timeMinutes: 45);
      expect(matcher.isVisible(r, profile.copyWith(maxTimeMinutes: 45)), true);
      expect(matcher.isVisible(r, profile.copyWith(maxTimeMinutes: 44)), false);
    });

    test('calorie target is a hard filter with ±150 kcal tolerance', () {
      final r = recipe(calories: 600);
      expect(matcher.isVisible(r, profile.copyWith(calorieTarget: 600)), true);
      expect(matcher.isVisible(r, profile.copyWith(calorieTarget: 750)), true); // +150
      expect(matcher.isVisible(r, profile.copyWith(calorieTarget: 450)), true); // −150
      expect(matcher.isVisible(r, profile.copyWith(calorieTarget: 751)), false);
      expect(matcher.isVisible(r, profile.copyWith(calorieTarget: 449)), false);
    });

    test('ignoreCalorieTarget lifts only the calorie filter', () {
      final r = recipe(calories: 2000, contains: {'dairy'});
      final p = profile.copyWith(calorieTarget: 600, avoidFlags: {'dairy'});
      expect(matcher.isVisible(r, p), false);
      expect(matcher.isVisible(r, p, ignoreCalorieTarget: true), false);
      final clean = recipe(calories: 2000);
      expect(matcher.isVisible(clean, p, ignoreCalorieTarget: true), true);
    });

    test('all filters combine — one failure is enough to hide', () {
      final r = recipe(
        contains: {'nuts'},
        ingredientIds: ['garlic'],
        attributes: {'halal'},
        timeMinutes: 90,
        calories: 100,
      );
      final strict = profile.copyWith(
        avoidFlags: {'nut-free'},
        avoidIngredients: {'garlic'},
        requiredAttributes: {'halal'},
        maxTimeMinutes: 60,
        calorieTarget: 600,
      );
      expect(matcher.isVisible(r, strict), false);
      // relax each filter one at a time — still hidden until all pass
      expect(matcher.isVisible(r, strict.copyWith(avoidFlags: {})), false);
      expect(matcher.isVisible(r, strict.copyWith(avoidIngredients: {})), false);
      expect(matcher.isVisible(r, strict.copyWith(requiredAttributes: {})), false);
      expect(matcher.isVisible(r, strict.copyWith(maxTimeMinutes: 120)), false);
      expect(matcher.isVisible(r, strict.copyWith(calorieTarget: 100)), false);
      // relaxing every filter at once finally shows the recipe
      expect(
        matcher.isVisible(
          r,
          strict.copyWith(
            avoidFlags: {},
            avoidIngredients: {},
            requiredAttributes: {},
            maxTimeMinutes: 120,
            calorieTarget: 100,
          ),
        ),
        true,
      );
    });
  });

  group('visibleVariants', () {
    test('keeps only visible recipes, in order', () {
      final rs = [
        recipe(id: 'a', contains: {'dairy'}),
        recipe(id: 'b'),
        recipe(id: 'c', timeMinutes: 90),
      ];
      final visible = matcher.visibleVariants(rs, profile.copyWith(avoidFlags: {'dairy'}));
      expect(visible.map((r) => r.id), ['b']);
    });
  });

  group('score — lexicographic variant scoring', () {
    test('required-attribute matches dominate everything else', () {
      final withHalal = recipe(id: 'a', attributes: {'halal'}, timeMinutes: 60, calories: 900);
      final without = recipe(id: 'b', timeMinutes: 10, calories: 600, effort: 'medium');
      final p = profile.copyWith(requiredAttributes: {'halal'});
      expect(matcher.score(withHalal, p).compareTo(matcher.score(without, p)), 1);
    });

    test('effort match beats time and calorie closeness', () {
      final effortHit = recipe(id: 'a', effort: 'medium', timeMinutes: 60, calories: 900);
      final effortMiss = recipe(id: 'b', effort: 'easy', timeMinutes: 10, calories: 600);
      expect(
        matcher.score(effortHit, profile).compareTo(matcher.score(effortMiss, profile)),
        1,
      );
    });

    test('time closeness beats calorie closeness', () {
      final quick = recipe(id: 'a', timeMinutes: 10, calories: 900);
      final slow = recipe(id: 'b', timeMinutes: 50, calories: 600);
      expect(matcher.score(quick, profile).compareTo(matcher.score(slow, profile)), 1);
    });

    test('calorie closeness breaks the final tie', () {
      final near = recipe(id: 'a', timeMinutes: 30, calories: 650);
      final far = recipe(id: 'b', timeMinutes: 30, calories: 750);
      expect(matcher.score(near, profile).compareTo(matcher.score(far, profile)), 1);
    });

    test('VariantScore compares field by field', () {
      const a = VariantScore(
        requiredMatches: 1,
        effortMatch: 0,
        timeCloseness: 0,
        calorieCloseness: 0,
      );
      const b = VariantScore(
        requiredMatches: 0,
        effortMatch: 1,
        timeCloseness: 99,
        calorieCloseness: 99,
      );
      expect(a.compareTo(b), 1);
      expect(b.compareTo(a), -1);
      expect(a.compareTo(a), 0);
    });
  });

  group('pickBest', () {
    test('returns null when no variant is visible', () {
      final rs = [recipe(id: 'a', contains: {'dairy'})];
      expect(
        matcher.pickBest(rs, profile.copyWith(avoidFlags: {'dairy'})),
        isNull,
      );
    });

    test('picks the highest-scoring visible variant', () {
      final rs = [
        recipe(id: 'classic', effort: 'hard', timeMinutes: 55, calories: 700),
        recipe(id: 'easy', effort: 'medium', timeMinutes: 20, calories: 620),
      ];
      // profile prefers medium effort → "easy" wins on effortMatch
      expect(matcher.pickBest(rs, profile)?.id, 'easy');
    });

    test('ties break on recipe id for determinism', () {
      final rs = [recipe(id: 'b'), recipe(id: 'a')];
      expect(matcher.pickBest(rs, profile)?.id, 'a');
    });

    test('respects ignoreCalorieTarget like visibility does', () {
      final rs = [recipe(id: 'light', calories: 100)];
      expect(matcher.pickBest(rs, profile), isNull);
      expect(matcher.pickBest(rs, profile, ignoreCalorieTarget: true)?.id, 'light');
    });
  });

  group('timeAwareBonus', () {
    final breakfast = recipe(mealType: 'breakfast');
    final dinner = recipe(mealType: 'dinner');
    final lunch = recipe(mealType: 'lunch');

    test('morning context (5am–11am): breakfast +200', () {
      expect(matcher.timeAwareBonus(breakfast, DateTime(2026, 10, 7, 5)), 200);
      expect(matcher.timeAwareBonus(breakfast, DateTime(2026, 10, 7, 10, 59)), 200);
      expect(matcher.timeAwareBonus(breakfast, DateTime(2026, 10, 7, 11)), 0);
      expect(matcher.timeAwareBonus(breakfast, DateTime(2026, 10, 7, 4, 59)), 0);
      expect(matcher.timeAwareBonus(dinner, DateTime(2026, 10, 7, 8)), 0);
      expect(matcher.timeAwareBonus(lunch, DateTime(2026, 10, 7, 8)), 0);
    });

    test('evening context (5pm–9pm): dinner +90', () {
      expect(matcher.timeAwareBonus(dinner, DateTime(2026, 10, 7, 17)), 90);
      expect(matcher.timeAwareBonus(dinner, DateTime(2026, 10, 7, 20, 59)), 90);
      expect(matcher.timeAwareBonus(dinner, DateTime(2026, 10, 7, 21)), 0);
      expect(matcher.timeAwareBonus(dinner, DateTime(2026, 10, 7, 16, 59)), 0);
      expect(matcher.timeAwareBonus(breakfast, DateTime(2026, 10, 7, 18)), 0);
    });

    test('weekend: medium and hard effort +90, easy gets nothing', () {
      // 2026-10-10 is a Saturday, 2026-10-12 a Monday.
      final sat = DateTime(2026, 10, 10, 12);
      final sun = DateTime(2026, 10, 11, 12);
      final mon = DateTime(2026, 10, 12, 12);
      for (final day in [sat, sun]) {
        expect(matcher.timeAwareBonus(recipe(mealType: 'lunch', effort: 'medium'), day), 90);
        expect(matcher.timeAwareBonus(recipe(mealType: 'lunch', effort: 'hard'), day), 90);
        expect(matcher.timeAwareBonus(recipe(mealType: 'lunch', effort: 'easy'), day), 0);
      }
      expect(matcher.timeAwareBonus(recipe(mealType: 'lunch', effort: 'medium'), mon), 0);
      expect(matcher.timeAwareBonus(recipe(mealType: 'lunch', effort: 'hard'), mon), 0);
    });

    test('bonuses stack: weekend dinner in the evening', () {
      final satDinner = recipe(mealType: 'dinner', effort: 'hard');
      expect(matcher.timeAwareBonus(satDinner, DateTime(2026, 10, 10, 18)), 180);
    });
  });

  group('stalenessBonus', () {
    final r = recipe(id: 'r');
    final now = DateTime(2026, 10, 7, 12);

    test('never cooked → no bonus', () {
      expect(matcher.stalenessBonus(r, {}, now), 0);
    });

    test('cooked 30+ days ago → +50', () {
      expect(
        matcher.stalenessBonus(r, {'r': now.subtract(const Duration(days: 30))}, now),
        50,
      );
      expect(
        matcher.stalenessBonus(r, {'r': now.subtract(const Duration(days: 90))}, now),
        50,
      );
    });

    test('cooked recently → no bonus', () {
      expect(
        matcher.stalenessBonus(r, {'r': now.subtract(const Duration(days: 29))}, now),
        0,
      );
      expect(matcher.stalenessBonus(r, {'r': now}, now), 0);
    });

    test('only the most recent cook date matters per recipe', () {
      // lastCookedByRecipe is pre-aggregated by the caller; other recipes'
      // dates must not leak in.
      expect(
        matcher.stalenessBonus(r, {'other': now.subtract(const Duration(days: 365))}, now),
        0,
      );
    });
  });

  group('rank', () {
    test('invisible recipes are excluded', () {
      final rs = [recipe(id: 'hidden', contains: {'dairy'}), recipe(id: 'shown')];
      final ranked = matcher.rank(rs, profile.copyWith(avoidFlags: {'dairy'}));
      expect(ranked.map((r) => r.id), ['shown']);
    });

    test('higher base score ranks first', () {
      final rs = [
        recipe(id: 'effort-miss', effort: 'hard'),
        recipe(id: 'effort-hit', effort: 'medium'),
      ];
      final ranked = matcher.rank(rs, profile);
      expect(ranked.first.id, 'effort-hit');
    });

    test('time-aware bonus reorders equal base scores', () {
      final rs = [
        recipe(id: 'dinner', mealType: 'dinner', effort: 'easy'),
        recipe(id: 'lunch', mealType: 'lunch', effort: 'easy'),
      ];
      final evening = DateTime(2026, 10, 7, 18); // Wednesday evening
      final ranked = matcher.rank(rs, profile, now: evening);
      expect(ranked.first.id, 'dinner');
    });

    test('staleness bonus reorders equal base scores', () {
      final rs = [recipe(id: 'fresh'), recipe(id: 'stale')];
      final now = DateTime(2026, 10, 7, 12);
      final ranked = matcher.rank(
        rs,
        profile,
        now: now,
        lastCookedByRecipe: {'stale': now.subtract(const Duration(days: 45))},
      );
      expect(ranked.first.id, 'stale');
    });

    test('ties break on recipe id for determinism', () {
      final rs = [recipe(id: 'b'), recipe(id: 'a'), recipe(id: 'c')];
      final ranked = matcher.rank(rs, profile, now: DateTime(2026, 10, 12, 12));
      expect(ranked.map((r) => r.id), ['a', 'b', 'c']);
    });

    test('bonuses apply after the base ranking', () {
      // The effort hit outranks the effort miss by base score; even a +200
      // breakfast bonus on the miss cannot cross the effort boundary unless
      // the base scores are equal — assert the combined ordering is stable.
      final rs = [
        recipe(id: 'miss-breakfast', mealType: 'breakfast', effort: 'hard'),
        recipe(id: 'hit-lunch', mealType: 'lunch', effort: 'medium'),
      ];
      final morning = DateTime(2026, 10, 7, 8); // Wednesday morning
      final ranked = matcher.rank(rs, profile, now: morning);
      // base: hit (effortMatch=1) > miss (effortMatch=0); bonus adds 200 to
      // the miss but the lexicographic base still dominates.
      expect(ranked.first.id, 'hit-lunch');
    });
  });

  group('calorieTolerance constant', () {
    test('is 150 kcal as specified', () {
      expect(calorieTolerance, 150);
    });
  });
}
