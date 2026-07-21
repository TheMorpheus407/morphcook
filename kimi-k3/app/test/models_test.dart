import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/models/profile.dart';

import 'fixtures.dart';

void main() {
  group('IngredientDictionary', () {
    final dict = testDictionary();

    test('descendantsOf includes the node itself', () {
      expect(dict.descendantsOf('dairy'),
          containsAll(['dairy', 'cow-milk', 'whole-milk', 'cheese']));
      expect(dict.descendantsOf('whole-milk'), {'whole-milk'});
    });

    test('ancestorsOf walks up to the root', () {
      expect(dict.ancestorsOf('whole-milk'),
          containsAll(['whole-milk', 'cow-milk', 'dairy']));
    });

    test('isCoveredBy propagates downward only', () {
      expect(dict.isCoveredBy('whole-milk', 'dairy'), isTrue);
      expect(dict.isCoveredBy('dairy', 'whole-milk'), isFalse);
      expect(dict.isCoveredBy('apple', 'dairy'), isFalse);
    });

    test('search matches localized names in any language', () {
      expect(dict.search('apf', 'de').single.id, 'apple');
      expect(dict.search('milch', 'de').map((n) => n.id),
          contains('cow-milk'));
      expect(dict.search('zzz', 'en'), isEmpty);
    });
  });

  group('Ontology', () {
    final ontology = testOntology();

    test('compound flags expand; plain flags pass through', () {
      expect(ontology.expandAvoidFlags({'vegan'}),
          containsAll(['pork', 'dairy', 'egg', 'honey']));
      expect(ontology.expandAvoidFlags({'gluten'}), {'gluten'});
      expect(ontology.expandAvoidFlags({'vegan', 'gluten'}),
          containsAll(['pork', 'gluten']));
    });

    test('flagLabel falls back to the id', () {
      expect(ontology.flagLabel('nope'), {'en': 'nope'});
    });
  });

  group('UserProfile', () {
    test('json round-trip preserves every field', () {
      const profile = UserProfile(
        name: 'julia',
        lang: 'de',
        avoidFlags: {'vegan', 'nuts'},
        avoidIngredients: {'apples'},
        requiredAttributes: {'halal'},
        maxTimeMinutes: 45,
        calorieTarget: 550,
        preferredEffort: 'hard',
        showVariantTags: false,
        reduceMotion: true,
        visualAlertEnabled: false,
        quickNextTapEnabled: true,
      );
      final decoded = UserProfile.decode(profile.encode());
      expect(decoded.name, 'julia');
      expect(decoded.lang, 'de');
      expect(decoded.avoidFlags, {'vegan', 'nuts'});
      expect(decoded.avoidIngredients, {'apples'});
      expect(decoded.requiredAttributes, {'halal'});
      expect(decoded.maxTimeMinutes, 45);
      expect(decoded.calorieTarget, 550);
      expect(decoded.preferredEffort, 'hard');
      expect(decoded.showVariantTags, isFalse);
      expect(decoded.reduceMotion, isTrue);
      expect(decoded.visualAlertEnabled, isFalse);
      expect(decoded.quickNextTapEnabled, isTrue);
    });

    test('copyWith(reduceMotion:) supports null (system) again', () {
      const profile = UserProfile(reduceMotion: true);
      final cleared = profile.copyWith(reduceMotion: () => null);
      expect(cleared.reduceMotion, isNull);
      final set = cleared.copyWith(reduceMotion: () => false);
      expect(set.reduceMotion, isFalse);
    });
  });
}
