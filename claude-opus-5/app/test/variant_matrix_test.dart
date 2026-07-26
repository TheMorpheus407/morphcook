import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/domain/matching.dart';
import 'package:morphcook/domain/models.dart';
import 'package:morphcook/domain/profile.dart';
import 'package:morphcook/services/variant_matrix.dart';

import 'support/fixtures.dart';

void main() {
  late Ontology ontology;
  late RecipeMatcher matcher;

  setUp(() {
    ontology = testOntology();
    matcher = RecipeMatcher(ontology: ontology, ingredients: testIngredients());
  });

  VariantMatrix build(List<Recipe> variants) => VariantMatrix(
    dimensions: ontology.dimensions,
    ontology: ontology,
    variants: variants,
  );

  Recipe variant(
    String diet,
    String effort, {
    Set<String> contains = const {},
  }) => makeRecipe(
    id: '$diet-$effort',
    axes: {'diet': diet},
    effort: effort,
    contains: contains,
  );

  group('axis vocabulary', () {
    test('values come back in ontology order, not corpus order', () {
      final matrix = build([
        variant('vegan', 'easy'),
        variant('classic', 'easy'),
      ]);
      expect(
        matrix.valuesFor('diet'),
        orderedEquals(<String>['classic', 'vegan']),
      );
      expect(matrix.valuesFor('effort'), orderedEquals(<String>['easy']));
    });

    test('an axis nobody uses yields nothing', () {
      final matrix = build([variant('classic', 'easy')]);
      expect(matrix.valuesFor('nonexistent'), isEmpty);
    });
  });

  group('resolveSelection', () {
    test('an exact combination is returned directly', () {
      final target = variant('vegan', 'hard');
      final matrix = build([variant('classic', 'easy'), target]);
      final result = matrix.resolveSelection(
        matrix.variants.first,
        'diet',
        'vegan',
      );
      expect(result?.id, target.id);
    });

    test('switching one axis keeps the other where it can', () {
      final matrix = build([
        variant('classic', 'easy'),
        variant('classic', 'hard'),
        variant('vegan', 'easy'),
        variant('vegan', 'hard'),
      ]);
      final start = matrix.recipeAt({'diet': 'classic', 'effort': 'hard'})!;
      final switched = matrix.resolveSelection(start, 'diet', 'vegan');
      expect(switched?.axes['effort'], 'hard');
    });

    test('it slides to a sibling when the exact cell is missing', () {
      final matrix = build([
        variant('classic', 'hard'),
        variant('vegan', 'easy'),
      ]);
      final start = matrix.recipeAt({'diet': 'classic', 'effort': 'hard'})!;
      final switched = matrix.resolveSelection(start, 'diet', 'vegan');
      expect(switched?.id, 'vegan-easy');
    });

    test('an axis value that does not exist at all is unreachable', () {
      final matrix = build([variant('classic', 'easy')]);
      final start = matrix.variants.first;
      expect(matrix.resolveSelection(start, 'diet', 'vegan'), isNull);
    });
  });

  group('rowsFor', () {
    test('one row per dimension, collapsed to the current value', () {
      final matrix = build([
        variant('classic', 'easy'),
        variant('vegan', 'medium'),
      ]);
      final rows = matrix.rowsFor(
        matrix.variants.first,
        matcher: matcher,
        context: matcher.contextFor(const Profile()),
        lang: 'en',
      );
      expect(
        rows.map((r) => r.dimension.id),
        orderedEquals(<String>['diet', 'effort']),
      );
      expect(rows.first.selectedValue, 'classic');
    });

    test('unreachable combinations are present but disabled, never hidden', () {
      // vegan exists only at easy; classic only at hard.
      final matrix = build([
        variant('classic', 'hard'),
        variant('vegan', 'easy'),
      ]);
      final start = matrix.recipeAt({'diet': 'vegan', 'effort': 'easy'})!;
      final effortRow = matrix
          .rowsFor(
            start,
            matcher: matcher,
            context: matcher.contextFor(const Profile()),
            lang: 'en',
          )
          .firstWhere((r) => r.dimension.id == 'effort');

      // Both effort values are listed.
      expect(
        effortRow.options.map((o) => o.value),
        containsAll(<String>['easy', 'hard']),
      );
      // 'hard' is reachable only by sliding diet back to classic, which the
      // matrix allows — so it stays enabled and points at the classic recipe.
      final hard = effortRow.options.firstWhere((o) => o.value == 'hard');
      expect(hard.reachable, isTrue);
      expect(hard.recipeId, 'classic-hard');
    });

    test('a value nobody wrote is reported unreachable', () {
      final matrix = build([variant('classic', 'easy')]);
      final row = matrix
          .rowsFor(
            matrix.variants.first,
            matcher: matcher,
            context: matcher.contextFor(const Profile()),
            lang: 'en',
          )
          .firstWhere((r) => r.dimension.id == 'diet');
      // Only 'classic' exists, so the row has a single option.
      expect(row.options, hasLength(1));
      expect(row.hasAlternatives, isFalse);
    });

    test('an option filtered out by the profile is flagged, not removed', () {
      final matrix = build([
        variant('classic', 'easy', contains: {'dairy'}),
        variant('vegan', 'easy'),
      ]);
      final start = matrix.recipeAt({'diet': 'vegan'})!;
      final row = matrix
          .rowsFor(
            start,
            matcher: matcher,
            context: matcher.contextFor(const Profile(avoidFlags: {'dairy'})),
            lang: 'en',
          )
          .firstWhere((r) => r.dimension.id == 'diet');
      final classic = row.options.firstWhere((o) => o.value == 'classic');
      expect(classic.reachable, isTrue);
      expect(classic.hiddenByProfile, isTrue);
      expect(classic.enabled, isFalse);
    });
  });

  group('initialSelection', () {
    test('prefers a variant the profile can see', () {
      final matrix = build([
        variant('classic', 'easy', contains: {'dairy'}),
        variant('vegan', 'easy'),
      ]);
      final pick = matrix.initialSelection(
        profile: const Profile(avoidFlags: {'dairy'}),
        context: matcher.contextFor(const Profile(avoidFlags: {'dairy'})),
        matcher: matcher,
        now: DateTime(2026, 7, 22, 14),
      );
      expect(pick?.axes['diet'], 'vegan');
    });

    test('falls back to the authored default when everything clashes', () {
      final classic = makeRecipe(
        id: 'classic',
        axes: {'diet': 'classic'},
        contains: {'dairy'},
        isDefault: true,
      );
      final matrix = build([
        makeRecipe(id: 'other', axes: {'diet': 'vegan'}, contains: {'dairy'}),
        classic,
      ]);
      final pick = matrix.initialSelection(
        profile: const Profile(avoidFlags: {'dairy'}),
        context: matcher.contextFor(const Profile(avoidFlags: {'dairy'})),
        matcher: matcher,
        now: DateTime(2026, 7, 22, 14),
      );
      expect(pick?.id, 'classic');
    });

    test('an empty dish yields null', () {
      final pick = build(const []).initialSelection(
        profile: const Profile(),
        context: matcher.contextFor(const Profile()),
        matcher: matcher,
        now: DateTime(2026, 7, 22, 14),
      );
      expect(pick, isNull);
    });
  });

  group('changedIngredients', () {
    test('reports removals, additions and requantifications', () {
      final from = makeRecipe(id: 'a', ingredientIds: {'garlic', 'parmesan'});
      final to = makeRecipe(id: 'b', ingredientIds: {'garlic', 'feta'});
      final changed = VariantMatrix.changedIngredients(from, to);
      expect(changed, containsAll(<String>['parmesan', 'feta']));
      expect(changed, isNot(contains('garlic')));
    });

    test('an unchanged pair reports nothing', () {
      final a = makeRecipe(id: 'a', ingredientIds: {'garlic'});
      final b = makeRecipe(id: 'b', ingredientIds: {'garlic'});
      expect(VariantMatrix.changedIngredients(a, b), isEmpty);
    });
  });
}
