import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/src/domain/variant_switcher.dart';
import 'package:morphcook/src/models/profile.dart';
import 'package:morphcook/src/models/recipe.dart';

import 'support/fixtures.dart';

void main() {
  late Profile profile;

  setUp(() {
    profile = buildProfile(preferredEffort: 'easy');
  });

  VariantSwitcher switcherFor(List<Recipe> variants) => VariantSwitcher(
        variants: variants,
        profile: profile,
        ontology: buildOntology(),
      );

  group('dimensions', () {
    test('the diet, effort and calorie axes are present', () {
      final switcher = switcherFor(<Recipe>[buildRecipe()]);

      expect(
        switcher.dimensions,
        containsAll(<String>['diet', 'effort', 'calorie_level']),
      );
    });

    test('the default effort comes from the profile', () {
      final switcher = switcherFor(<Recipe>[buildRecipe(effort: 'easy')]);
      final selection = switcher.defaultSelection();

      expect(selection['effort'], 'easy');
    });
  });

  group('reachability', () {
    test('a diet with a recipe is reachable', () {
      final switcher = switcherFor(<Recipe>[
        buildRecipe(id: 'classic', diet: 'classic'),
        buildRecipe(id: 'vegan', diet: 'vegan'),
      ]);
      final selection = <String, String>{
        'diet': 'classic',
        'effort': 'easy',
        'calorie_level': '≤600',
      };

      expect(switcher.isReachable('diet', 'vegan', selection), isTrue);
    });

    test('an effort with no matching diet version is unreachable', () {
      final switcher = switcherFor(<Recipe>[
        buildRecipe(id: 'classic', diet: 'classic', effort: 'easy'),
        buildRecipe(id: 'vegan', diet: 'vegan', effort: 'easy'),
      ]);
      final selection = <String, String>{
        'diet': 'vegan',
        'effort': 'easy',
        'calorie_level': '≤600',
      };

      expect(switcher.isReachable('effort', 'hard', selection), isFalse);
      expect(switcher.conflictsFor('effort', 'hard', selection),
          containsPair('diet', 'vegan'));
    });

    test('the same effort is reachable in a diet that has it', () {
      final switcher = switcherFor(<Recipe>[
        buildRecipe(id: 'classic', diet: 'classic', effort: 'easy'),
        buildRecipe(id: 'vegan-hard', diet: 'vegan', effort: 'hard'),
      ]);
      final selection = <String, String>{
        'diet': 'vegan',
        'effort': 'hard',
        'calorie_level': '≤600',
      };

      expect(switcher.isReachable('effort', 'hard', selection), isTrue);
    });
  });

  group('options', () {
    test('the selected option is marked as selected', () {
      final switcher = switcherFor(<Recipe>[
        buildRecipe(id: 'classic', diet: 'classic'),
        buildRecipe(id: 'vegan', diet: 'vegan'),
      ]);
      final selection = <String, String>{
        'diet': 'vegan',
        'effort': 'easy',
        'calorie_level': '≤600',
      };

      final options = switcher.optionsFor('diet', selection);

      expect(options.where((option) => option.selected).single.valueId, 'vegan');
    });

    test('unreachable options are returned disabled, not hidden', () {
      final switcher = switcherFor(<Recipe>[
        buildRecipe(id: 'classic', diet: 'classic', effort: 'easy'),
        buildRecipe(id: 'vegan', diet: 'vegan', effort: 'easy'),
      ]);
      final selection = <String, String>{
        'diet': 'vegan',
        'effort': 'easy',
        'calorie_level': '≤600',
      };

      final options = switcher.optionsFor('effort', selection);

      expect(options.map((option) => option.valueId),
          containsAll(<String>['easy', 'medium', 'hard']));
      expect(options.firstWhere((option) => option.valueId == 'hard').enabled,
          isFalse);
    });
  });

  group('resolution', () {
    test('the selection resolves to a real recipe', () {
      final switcher = switcherFor(<Recipe>[
        buildRecipe(id: 'classic', diet: 'classic'),
        buildRecipe(id: 'vegan', diet: 'vegan'),
      ]);

      final resolved = switcher.resolve(<String, String>{
        'diet': 'vegan',
        'effort': 'easy',
        'calorie_level': '≤600',
      });

      expect(resolved?.id, 'vegan');
    });

    test('a selection with no recipe resolves to null', () {
      final switcher = switcherFor(<Recipe>[
        buildRecipe(id: 'classic', diet: 'classic'),
      ]);

      expect(
        switcher.resolve(<String, String>{'diet': 'keto'}),
        isNull,
      );
    });
  });

  group('selection', () {
    test('switching a diet keeps the selection pointing at a recipe', () {
      final switcher = switcherFor(<Recipe>[
        buildRecipe(id: 'classic', diet: 'classic', effort: 'easy'),
        buildRecipe(id: 'vegan', diet: 'vegan', effort: 'medium'),
      ]);
      final selection = <String, String>{
        'diet': 'classic',
        'effort': 'easy',
        'calorie_level': '≤600',
      };

      final next = switcher.select('diet', 'vegan', selection);

      expect(next['diet'], 'vegan');
      expect(next['effort'], 'medium');
      expect(switcher.resolve(next), isNotNull);
    });

    test('a blocked effort falls back to one that exists', () {
      final switcher = switcherFor(<Recipe>[
        buildRecipe(id: 'classic', diet: 'classic', effort: 'easy'),
        buildRecipe(id: 'vegan', diet: 'vegan', effort: 'hard'),
      ]);
      final selection = <String, String>{
        'diet': 'classic',
        'effort': 'easy',
        'calorie_level': '≤600',
      };

      final next = switcher.select('diet', 'vegan', selection);

      expect(next['effort'], 'hard');
    });
  });
}
