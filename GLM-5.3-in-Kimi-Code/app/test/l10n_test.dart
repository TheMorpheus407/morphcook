import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/l10n.dart';
import 'package:morphcook/logic/profile.dart';

void main() {
  group('L (l10n)', () {
    test('every key exists in every supported language', () {
      for (final entry in L.debugData.entries) {
        for (final lang in Lang.values) {
          expect(entry.value.containsKey(lang), isTrue,
              reason: 'key "${entry.key}" missing ${lang.name}');
        }
      }
    });

    test('t() returns the right language', () {
      expect(L.t(Lang.en, 'tabHome'), 'home');
      expect(L.t(Lang.de, 'tabHome'), 'start');
    });

    test('f() interpolates params', () {
      expect(
        L.f(Lang.en, 'hmVariants', {'n': '5'}),
        '5 ways to make it',
      );
    });

    test('unknown key returns the key itself (no crash)', () {
      expect(L.t(Lang.en, 'definitely-not-a-key'), 'definitely-not-a-key');
    });
  });

  group('Profile', () {
    test('json roundtrip', () {
      final p = Profile(
        name: 'mo',
        lang: Lang.de,
        avoidFlags: {'vegan'},
        avoidIngredients: {'cilantro'},
        requiredAttributes: {'halal'},
        maxTimeMinutes: 45,
        calorieTarget: 600,
        preferredEffort: 'medium',
        showVariantTags: false,
        reduceMotion: true,
        visualAlertEnabled: false,
        quickNextTapEnabled: true,
      );
      final restored = Profile.fromJson(p.toJson());
      expect(restored.name, 'mo');
      expect(restored.lang, Lang.de);
      expect(restored.avoidFlags, {'vegan'});
      expect(restored.avoidIngredients, {'cilantro'});
      expect(restored.requiredAttributes, {'halal'});
      expect(restored.maxTimeMinutes, 45);
      expect(restored.calorieTarget, 600);
      expect(restored.preferredEffort, 'medium');
      expect(restored.showVariantTags, isFalse);
      expect(restored.reduceMotion, isTrue);
      expect(restored.visualAlertEnabled, isFalse);
      expect(restored.quickNextTapEnabled, isTrue);
    });

    test('copyWith clear flags reset nullable fields', () {
      const p = Profile(calorieTarget: 600, maxTimeMinutes: 30);
      final cleared = p.copyWith(clearCalorieTarget: true, clearMaxTime: true);
      expect(cleared.calorieTarget, isNull);
      expect(cleared.maxTimeMinutes, isNull);
    });

    test('calorie tolerance is 150 per spec', () {
      expect(Profile.calorieTolerance, 150);
    });

    test('default profile', () {
      const p = Profile();
      expect(p.lang, Lang.en);
      expect(p.preferredEffort, 'easy');
      expect(p.reduceMotion, isNull); // null → follow system
      expect(p.visualAlertEnabled, isTrue);
      expect(p.quickNextTapEnabled, isFalse); // opt-in
    });
  });

  group('LangX', () {
    test('fromCode', () {
      expect(LangX.fromCode('de'), Lang.de);
      expect(LangX.fromCode('en'), Lang.en);
      expect(LangX.fromCode(null), Lang.en);
      expect(LangX.fromCode('fr'), Lang.en); // fallback
    });
  });
}
