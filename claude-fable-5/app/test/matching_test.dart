import 'package:flutter_test/flutter_test.dart' hide Matcher;
import 'package:morphcook/logic/matching.dart';
import 'package:morphcook/models/profile.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Matcher matcher;

  setUpAll(() async {
    final corpus = await loadRealCorpus(all: false);
    matcher =
        Matcher(ontology: corpus.ontology, dictionary: corpus.dictionary);
  });

  group('expandAvoidFlags', () {
    test('compound flags expand to their atomic flags', () {
      final expanded =
          expandAvoidFlags({'vegan'}, matcher.ontology);
      expect(expanded, containsAll(['pork', 'beef', 'dairy', 'egg', 'honey']));
      expect(expanded, isNot(contains('vegan')));
    });

    test('atomic flags pass through, mixes combine', () {
      final expanded =
          expandAvoidFlags({'halal', 'peanuts'}, matcher.ontology);
      expect(expanded,
          containsAll(['pork', 'alcohol', 'gelatin-non-halal', 'peanuts']));
    });
  });

  group('visibility', () {
    test('recipe hidden when contains intersects avoid flags', () {
      final recipe = makeRecipe(contains: {'dairy', 'gluten'});
      expect(
          matcher.isVisible(
              recipe, const Profile(avoidFlags: {'dairy'})),
          isFalse);
      expect(
          matcher.isVisible(recipe, const Profile(avoidFlags: {'pork'})),
          isTrue);
    });

    test('compound avoidance hides matching recipes', () {
      final doener = makeRecipe(contains: {'lamb', 'dairy', 'gluten'});
      expect(
          matcher.isVisible(doener, const Profile(avoidFlags: {'vegan'})),
          isFalse);
      final veganDoener = makeRecipe(contains: {'gluten', 'soy'});
      expect(
          matcher.isVisible(
              veganDoener, const Profile(avoidFlags: {'vegan'})),
          isTrue);
    });

    test('specific ingredient avoidance hides exact matches', () {
      final recipe = makeRecipe(ingredientIds: ['apple', 'cilantro']);
      expect(
          matcher.isVisible(recipe,
              const Profile(avoidIngredients: {'cilantro'})),
          isFalse);
      expect(
          matcher.isVisible(
              recipe, const Profile(avoidIngredients: {'basil'})),
          isTrue);
    });

    test('parent avoidance propagates to descendants', () {
      // whole-milk is dairy > cow-milk > whole-milk in the dictionary.
      final recipe = makeRecipe(
          ingredientIds: ['whole-milk'], contains: {'dairy', 'high-fodmap'});
      expect(
          matcher.isVisible(
              recipe, const Profile(avoidIngredients: {'dairy'})),
          isFalse);
      expect(
          matcher.isVisible(
              recipe, const Profile(avoidIngredients: {'cow-milk'})),
          isFalse);
      expect(
          matcher.isVisible(
              recipe, const Profile(avoidIngredients: {'goat-milk'})),
          isTrue);
    });

    test('class and specific avoidance combine (either hides)', () {
      final recipe = makeRecipe(
          ingredientIds: ['apple'], contains: {'gluten'});
      const profile = Profile(
          avoidFlags: {'gluten'}, avoidIngredients: {'apple'});
      final reasons = matcher.reasons(recipe, profile);
      expect(reasons, contains(HiddenReason.avoidedFlag));
      expect(reasons, contains(HiddenReason.avoidedIngredient));
    });

    test('required attributes must all be present', () {
      final recipe = makeRecipe(attributes: {'halal', 'vegan'});
      expect(
          matcher.isVisible(recipe,
              const Profile(requiredAttributes: {'halal'})),
          isTrue);
      expect(
          matcher.isVisible(
              recipe,
              const Profile(
                  requiredAttributes: {'halal', 'gluten-free'})),
          isFalse);
    });

    test('time budget is a hard filter', () {
      final recipe = makeRecipe(timeMinutes: 45);
      expect(
          matcher.isVisible(recipe, const Profile(maxTimeMinutes: 45)),
          isTrue);
      expect(
          matcher.isVisible(recipe, const Profile(maxTimeMinutes: 44)),
          isFalse);
    });

    test('calorie target uses ± tolerance', () {
      final recipe = makeRecipe(calories: 700);
      const tolerance = Profile.calorieTolerance;
      expect(
          matcher.isVisible(
              recipe, Profile(calorieTarget: 700 - tolerance)),
          isTrue);
      expect(
          matcher.isVisible(
              recipe, Profile(calorieTarget: 700 - tolerance - 1)),
          isFalse);
    });

    test('per-dish calorie override reveals calorie-hidden recipes', () {
      final recipe = makeRecipe(calories: 900);
      const profile = Profile(calorieTarget: 500);
      expect(matcher.isVisible(recipe, profile), isFalse);
      expect(matcher.hiddenOnlyByCalories(recipe, profile), isTrue);
      expect(
          matcher.isVisible(recipe, profile, ignoreCalories: true), isTrue);
    });

    test('override does not reveal recipes hidden for other reasons', () {
      final recipe = makeRecipe(calories: 900, contains: {'pork'});
      const profile =
          Profile(calorieTarget: 500, avoidFlags: {'pork'});
      expect(matcher.hiddenOnlyByCalories(recipe, profile), isFalse);
      expect(
          matcher.isVisible(recipe, profile, ignoreCalories: true), isFalse);
    });

    test('empty profile sees everything', () {
      final recipe = makeRecipe(
          contains: {'pork', 'dairy', 'gluten'}, calories: 950);
      expect(matcher.isVisible(recipe, const Profile()), isTrue);
    });
  });
}
