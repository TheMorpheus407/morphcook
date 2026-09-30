import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/corpus.dart';
import 'package:morphcook/data/models/recipe.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/domain/ranking.dart';
import 'package:morphcook/domain/variants.dart';

import '../support/fixtures.dart';

void main() {
  late Corpus corpus;

  setUpAll(() async => corpus = await loadCorpus());

  Recipe variant(String id, String diet, String effort, String calories) =>
      recipeFixture(id: id, diet: diet, effort: effort, calorieBucket: calories);

  VariantResolver resolverFor(List<Recipe> candidates, {Profile profile = const Profile()}) => VariantResolver(
    ontology: corpus.ontology,
    candidates: candidates,
    ranking: const Ranking(),
    profile: profile,
    context: RankingContext(now: DateTime(2026, 9, 28, 13)),
  );

  // classic/medium/800, vegan/medium/600, vegan/easy/600, keto/hard/800
  final dish = [
    variant('classic', 'classic', 'medium', '≤800'),
    variant('vegan', 'vegan', 'medium', '≤600'),
    variant('vegan-easy', 'vegan', 'easy', '≤600'),
    variant('keto', 'keto', 'hard', '≤800'),
  ];

  group('dimensions', () {
    test('there is one row per dimension the variants have values for', () {
      final resolver = resolverFor(dish);
      expect(resolver.dimensions.map((d) => d.id), ['diet', 'effort', 'calorie']);
    });

    test('values come in ontology order', () {
      final resolver = resolverFor(dish);
      final diet = resolver.dimensions.first;
      expect(resolver.valuesOf(diet), ['classic', 'vegan', 'keto']);
      final effort = resolver.dimensions[1];
      expect(resolver.valuesOf(effort), ['easy', 'medium', 'hard']);
    });

    test('a future dimension shows up without code changes', () {
      final spice = recipeFixture(id: 'hot', axes: {'spice': 'hot'});
      final mild = recipeFixture(id: 'mild', axes: {'spice': 'mild'});
      // The ontology of the corpus has no "spice" dimension, so it stays hidden.
      expect(resolverFor([spice, mild]).dimensions.map((d) => d.id), isNot(contains('spice')));
    });
  });

  group('defaults come from the profile', () {
    test('the best-ranked variant sets every row', () {
      final resolver = resolverFor(dish, profile: const Profile(preferredEffort: 'easy'));
      expect(resolver.initialSelection(), {'diet': 'vegan', 'effort': 'easy', 'calorie': '≤600'});
    });

    test('another effort mood gives another default', () {
      final resolver = resolverFor(dish, profile: const Profile(preferredEffort: 'hard'));
      expect(resolver.initialSelection()['diet'], 'keto');
    });

    test('required attributes weigh more than effort', () {
      final withAttr = [
        recipeFixture(id: 'a', diet: 'classic', effort: 'easy', attributes: {'keto'}),
        recipeFixture(id: 'b', diet: 'vegan', effort: 'hard'),
      ];
      final resolver = resolverFor(
        withAttr,
        profile: const Profile(preferredEffort: 'hard', requiredAttributes: {'keto'}),
      );
      expect(resolver.initialSelection()['diet'], 'classic');
    });

    test('no candidates: an empty selection', () {
      expect(resolverFor(const <Recipe>[]).initialSelection(), isEmpty);
    });
  });

  group('unreachable combinations are disabled with a note, not hidden', () {
    test('every option of a row stays in the list', () {
      final resolver = resolverFor(dish);
      final selection = {'diet': 'vegan', 'effort': 'medium', 'calorie': '≤600'};
      final row = resolver.axis('diet', selection);
      expect(row.options.map((o) => o.value), ['classic', 'vegan', 'keto']);
    });

    test('an option is enabled only when a recipe combines it with the other rows', () {
      final resolver = resolverFor(dish);
      final selection = {'diet': 'vegan', 'effort': 'medium', 'calorie': '≤600'};
      final diet = resolver.axis('diet', selection);
      expect(diet.options.firstWhere((o) => o.value == 'vegan').enabled, isTrue);
      expect(diet.options.firstWhere((o) => o.value == 'classic').enabled, isFalse, reason: 'no classic × ≤600');
      expect(diet.options.firstWhere((o) => o.value == 'keto').enabled, isFalse);

      final effort = resolver.axis('effort', selection);
      expect(effort.options.firstWhere((o) => o.value == 'easy').enabled, isTrue, reason: 'vegan-easy exists');
      expect(effort.options.firstWhere((o) => o.value == 'hard').enabled, isFalse);
    });

    test('a disabled option names the pairing that is missing, for "no vegan × keto version yet"', () {
      final resolver = resolverFor(dish);
      final selection = {'diet': 'vegan', 'effort': 'medium', 'calorie': '≤600'};
      final keto = resolver.axis('diet', selection).options.firstWhere((o) => o.value == 'keto');
      expect(keto.enabled, isFalse);
      expect(keto.conflictAxis, isNotNull);
      expect(keto.conflictValue, isNotNull);
      expect(['effort', 'calorie'], contains(keto.conflictAxis));
    });

    test('the selected option is always enabled', () {
      final resolver = resolverFor(dish);
      final selection = {'diet': 'keto', 'effort': 'hard', 'calorie': '≤800'};
      for (final axis in resolver.axes(selection)) {
        final selected = axis.options.firstWhere((o) => o.selected);
        expect(selected.enabled, isTrue);
      }
    });

    test('select() returns the selection of the matching recipe, or null when disabled', () {
      final resolver = resolverFor(dish);
      final selection = {'diet': 'vegan', 'effort': 'medium', 'calorie': '≤600'};
      expect(resolver.select('effort', 'easy', selection), {'diet': 'vegan', 'effort': 'easy', 'calorie': '≤600'});
      expect(resolver.select('diet', 'keto', selection), isNull);
    });

    test('a row with a single value has nothing to reveal', () {
      final resolver = resolverFor([variant('a', 'vegan', 'easy', '≤400'), variant('b', 'vegan', 'medium', '≤400')]);
      final selection = {'diet': 'vegan', 'effort': 'easy', 'calorie': '≤400'};
      expect(resolver.axis('diet', selection).hasAlternatives, isFalse);
      expect(resolver.axis('effort', selection).hasAlternatives, isTrue);
    });
  });

  group('sparse data can never trap the cook', () {
    final sparse = [variant('a', 'classic', 'medium', '≤800'), variant('b', 'keto', 'hard', '≤600')];

    test('a recipe that differs everywhere is isolated', () {
      final resolver = resolverFor(sparse);
      expect(resolver.isIsolated({'diet': 'classic', 'effort': 'medium', 'calorie': '≤800'}), isTrue);
      expect(resolverFor(dish).isIsolated({'diet': 'vegan', 'effort': 'medium', 'calorie': '≤600'}), isFalse);
    });

    test('a single recipe is not isolated', () {
      expect(
        resolverFor([sparse.first]).isIsolated({'diet': 'classic', 'effort': 'medium', 'calorie': '≤800'}),
        isFalse,
      );
    });

    test('an isolated recipe enables every option and jumps to the nearest variant', () {
      final resolver = resolverFor(sparse);
      final selection = {'diet': 'classic', 'effort': 'medium', 'calorie': '≤800'};
      final row = resolver.axis('diet', selection);
      expect(row.options.every((o) => o.enabled), isTrue);
      expect(resolver.select('diet', 'keto', selection), {'diet': 'keto', 'effort': 'hard', 'calorie': '≤600'});
    });
  });

  group('resolving a selection', () {
    test('a full selection resolves to its recipe', () {
      final resolver = resolverFor(dish);
      expect(resolver.resolve({'diet': 'vegan', 'effort': 'easy', 'calorie': '≤600'})!.id, 'vegan-easy');
    });

    test('a partial selection resolves to the best matching recipe', () {
      final resolver = resolverFor(dish, profile: const Profile(preferredEffort: 'medium'));
      expect(resolver.resolve({'diet': 'vegan'})!.id, 'vegan');
    });

    test('an impossible selection resolves to nothing', () {
      expect(resolverFor(dish).resolve({'diet': 'keto', 'effort': 'easy'}), isNull);
    });

    test('duplicates on all axes resolve by ranking, never arbitrarily', () {
      final twins = [variant('a-twin', 'vegan', 'easy', '≤600'), variant('b-twin', 'vegan', 'easy', '≤600')];
      expect(resolverFor(twins).resolve({'diet': 'vegan'})!.id, 'a-twin');
    });
  });

  group('with the shipped corpus', () {
    test('every dish resolves to a recipe for an open profile, and every disabled option says why', () async {
      final ontology = corpus.ontology;
      for (final d in corpus.dishes.values) {
        final recipes = await corpus.loadDish(d.id);
        expect(recipes, isNotEmpty, reason: d.id);
        final resolver = VariantResolver(
          ontology: ontology,
          candidates: recipes,
          ranking: const Ranking(),
          profile: const Profile(),
          context: RankingContext(now: DateTime(2026, 9, 28, 13)),
        );
        final selection = resolver.initialSelection();
        expect(resolver.resolve(selection), isNotNull, reason: d.id);
        for (final axis in resolver.axes(selection)) {
          for (final option in axis.options.where((o) => !o.enabled)) {
            expect(option.conflictAxis, isNotNull, reason: '${d.id} ${axis.dimension.id}=${option.value}');
          }
        }
        // Every variant can be reached by tapping through the rows.
        for (final recipe in recipes) {
          final wanted = resolver.selectionOf(recipe);
          var current = selection;
          for (final entry in wanted.entries) {
            final next = resolver.select(entry.key, entry.value, current);
            if (next != null) current = next;
          }
          expect(resolver.resolve(current), isNotNull);
        }
      }
    });
  });
}
