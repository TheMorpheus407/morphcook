import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/matching/matching.dart';
import 'package:morphcook/matching/ranking.dart';
import 'package:morphcook/models/i18n_string.dart';
import 'package:morphcook/models/ingredient.dart';
import 'package:morphcook/models/ontology.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/recipe.dart';

Ontology _ontology() => Ontology.fromJson({
      'version': 1,
      'contains_flags': [
        {'id': 'pork', 'label': {'en': 'pork'}},
        {'id': 'beef', 'label': {'en': 'beef'}},
        {'id': 'dairy', 'label': {'en': 'dairy'}},
        {'id': 'gluten', 'label': {'en': 'gluten'}},
        {'id': 'egg', 'label': {'en': 'egg'}},
        {'id': 'fish', 'label': {'en': 'fish'}},
        {'id': 'shellfish', 'label': {'en': 'shellfish'}},
        {'id': 'poultry', 'label': {'en': 'poultry'}},
        {'id': 'lamb', 'label': {'en': 'lamb'}},
        {'id': 'honey', 'label': {'en': 'honey'}},
        {'id': 'gelatin-non-halal', 'label': {'en': 'gelatin'}},
        {'id': 'gelatin-non-kosher', 'label': {'en': 'gelatin'}},
        {'id': 'molluscs', 'label': {'en': 'molluscs'}},
        {'id': 'alcohol', 'label': {'en': 'alcohol'}},
        {'id': 'lactose', 'label': {'en': 'lactose'}},
      ],
      'compound_flags': {
        'vegan': {
          'label': {'en': 'vegan'},
          'expands_to': [
            'pork', 'beef', 'lamb', 'poultry', 'fish', 'shellfish', 'molluscs',
            'egg', 'dairy', 'lactose', 'gelatin-non-halal', 'gelatin-non-kosher',
            'honey',
          ],
        },
        'halal': {
          'label': {'en': 'halal'},
          'expands_to': ['pork', 'alcohol', 'gelatin-non-halal'],
        },
      },
      'attributes': {
        'effort': {
          'values': ['easy', 'medium', 'hard'],
          'labels': {
            'easy': {'en': 'easy'},
            'medium': {'en': 'medium'},
            'hard': {'en': 'hard'},
          },
        },
      },
      'techniques': [],
    });

IngredientTree _tree() => IngredientTree.fromJson({
      'version': 1,
      'tree': [
        {
          'id': 'dairy',
          'label': {'en': 'dairy'},
          'children': [
            {
              'id': 'cheese',
              'label': {'en': 'cheese'},
              'children': [
                {'id': 'parmesan', 'label': {'en': 'parmesan'}},
              ],
            },
          ],
        },
        {'id': 'tomato', 'label': {'en': 'tomato'}},
        {'id': 'cilantro', 'label': {'en': 'cilantro'}},
      ],
      'aisle_map': {
        'produce': ['tomato', 'cilantro'],
        'dairy': ['dairy', 'cheese', 'parmesan'],
      },
    });

Recipe _recipe({
  required String id,
  List<String> contains = const [],
  List<String> attributes = const [],
  List<String> ingredientIds = const [],
  int timeMinutes = 30,
  String effort = 'medium',
  int calories = 600,
}) =>
    Recipe(
      id: id,
      dishId: 'dish',
      name: const I18nString({'en': 'r'}),
      variantLabel: const I18nString({'en': 'v'}),
      dietLabel: 'omnivore',
      summary: const I18nString({'en': 's'}),
      contains: contains,
      attributes: attributes,
      techniqueTags: const [],
      timeMinutes: timeMinutes,
      activeMinutes: timeMinutes,
      effort: effort,
      servings: 2,
      caloriesPerServing: calories,
      proteinG: 30,
      carbsG: 40,
      fatG: 20,
      ingredients: [
        for (final iid in ingredientIds)
          RecipeIngredient(
            id: iid,
            qty: 1,
            unit: 'piece',
            name: I18nString({'en': iid}),
          ),
      ],
      steps: const [],
    );

void main() {
  group('isVisible', () {
    final ontology = _ontology();
    final tree = _tree();

    test('passes when nothing conflicts', () {
      final r = _recipe(id: 'r1', contains: ['gluten']);
      expect(
        isVisible(r, const Profile(), ontology: ontology, ingredients: tree),
        isTrue,
      );
    });

    test('rejects when avoid flag intersects contains', () {
      final r = _recipe(id: 'r1', contains: ['dairy']);
      final p = const Profile().copyWith(avoidFlags: {'dairy'});
      expect(isVisible(r, p, ontology: ontology, ingredients: tree), isFalse);
    });

    test('expands vegan to reject pork', () {
      final r = _recipe(id: 'r1', contains: ['pork']);
      final p = const Profile().copyWith(avoidFlags: {'vegan'});
      expect(isVisible(r, p, ontology: ontology, ingredients: tree), isFalse);
    });

    test('halal compound rejects alcohol and pork', () {
      final r = _recipe(id: 'r1', contains: ['alcohol']);
      final p = const Profile().copyWith(avoidFlags: {'halal'});
      expect(isVisible(r, p, ontology: ontology, ingredients: tree), isFalse);
    });

    test('specific avoidance excludes by ingredient id', () {
      final r = _recipe(id: 'r1', ingredientIds: ['tomato', 'cilantro']);
      final p = const Profile().copyWith(avoidIngredients: {'cilantro'});
      expect(isVisible(r, p, ontology: ontology, ingredients: tree), isFalse);
    });

    test('parent avoidance propagates to children (dairy → parmesan)', () {
      final r = _recipe(id: 'r1', ingredientIds: ['parmesan']);
      final p = const Profile().copyWith(avoidIngredients: {'dairy'});
      expect(isVisible(r, p, ontology: ontology, ingredients: tree), isFalse);
    });

    test('required attributes must be present', () {
      final r = _recipe(id: 'r1', attributes: ['halal-friendly']);
      final ok = const Profile().copyWith(requiredAttributes: {'halal-friendly'});
      final no = const Profile().copyWith(requiredAttributes: {'kosher-friendly'});
      expect(isVisible(r, ok, ontology: ontology, ingredients: tree), isTrue);
      expect(isVisible(r, no, ontology: ontology, ingredients: tree), isFalse);
    });

    test('time budget is enforced', () {
      final r = _recipe(id: 'r1', timeMinutes: 60);
      final p = const Profile().copyWith(maxTimeMinutes: 30);
      expect(isVisible(r, p, ontology: ontology, ingredients: tree), isFalse);
    });

    test('calorie target uses tolerance', () {
      final r = _recipe(id: 'r1', calories: 850);
      final tight = const Profile()
          .copyWith(calorieTarget: 600, calorieTolerance: 100);
      final loose = const Profile()
          .copyWith(calorieTarget: 600, calorieTolerance: 300);
      expect(
          isVisible(r, tight, ontology: ontology, ingredients: tree), isFalse);
      expect(
          isVisible(r, loose, ontology: ontology, ingredients: tree), isTrue);
    });

    test('ignoreCalorieFilter bypasses the calorie filter', () {
      final r = _recipe(id: 'r1', calories: 1200);
      final p = const Profile().copyWith(calorieTarget: 400, calorieTolerance: 100);
      expect(
          isVisible(r, p,
              ontology: ontology, ingredients: tree, ignoreCalorieFilter: true),
          isTrue);
    });
  });

  group('baseScore + rank', () {
    test('preferred-effort match boosts score', () {
      final easy = _recipe(id: 'a', effort: 'easy');
      final hard = _recipe(id: 'b', effort: 'hard');
      final p = const Profile().copyWith(preferredEffort: 'easy');
      expect(baseScore(easy, p), greaterThan(baseScore(hard, p)));
    });

    test('closer time scores higher', () {
      final close = _recipe(id: 'a', timeMinutes: 45);
      final far = _recipe(id: 'b', timeMinutes: 5);
      final p = const Profile().copyWith(maxTimeMinutes: 45);
      expect(baseScore(close, p), greaterThan(baseScore(far, p)));
    });

    test('morning + breakfast attribute gives +200 bonus', () {
      final r = _recipe(id: 'b', attributes: ['breakfast']);
      final morning = DateTime(2026, 6, 3, 8, 0); // Wed 08:00
      final evening = DateTime(2026, 6, 3, 18, 0); // Wed 18:00
      const profile = Profile();
      final morn = rank(r, profile, RankingContext(now: morning, lastCookedByRecipeId: const {}));
      final eve = rank(r, profile, RankingContext(now: evening, lastCookedByRecipeId: const {}));
      expect(morn - eve, greaterThanOrEqualTo(110));
    });

    test('evening + dinner gives +90 bonus', () {
      final r = _recipe(id: 'd', attributes: ['dinner']);
      final morning = DateTime(2026, 6, 3, 8, 0);
      final evening = DateTime(2026, 6, 3, 18, 0);
      const profile = Profile();
      final morn = rank(r, profile, RankingContext(now: morning, lastCookedByRecipeId: const {}));
      final eve = rank(r, profile, RankingContext(now: evening, lastCookedByRecipeId: const {}));
      expect(eve - morn, equals(90));
    });

    test('weekend boosts medium/hard recipes by +90', () {
      final r = _recipe(id: 'h', effort: 'hard');
      final weekday = DateTime(2026, 6, 3, 8, 0); // Wed
      final saturday = DateTime(2026, 6, 6, 8, 0); // Sat
      const profile = Profile();
      final wk = rank(r, profile, RankingContext(now: weekday, lastCookedByRecipeId: const {}));
      final st = rank(r, profile, RankingContext(now: saturday, lastCookedByRecipeId: const {}));
      expect(st - wk, equals(90));
    });

    test('staleness bonus of +50 after ≥30 days', () {
      final r = _recipe(id: 's', effort: 'easy');
      final now = DateTime(2026, 6, 3, 12, 0);
      final stale = now.subtract(const Duration(days: 31));
      final fresh = now.subtract(const Duration(days: 5));
      const profile = Profile();
      final st = rank(r, profile, RankingContext(now: now, lastCookedByRecipeId: {r.id: stale}));
      final fr = rank(r, profile, RankingContext(now: now, lastCookedByRecipeId: {r.id: fresh}));
      expect(st - fr, equals(50));
    });

    test('never-cooked recipe does not get staleness bonus', () {
      final r = _recipe(id: 'n', effort: 'easy');
      final now = DateTime(2026, 6, 3, 12, 0);
      const profile = Profile();
      final never = rank(r, profile, RankingContext(now: now, lastCookedByRecipeId: const {}));
      final base = baseScore(r, profile);
      expect(never - base, equals(0));
    });
  });
}
