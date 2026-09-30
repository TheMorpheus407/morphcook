import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/models/profile.dart';

void main() {
  const full = Profile(
    name: 'Sam',
    lang: 'de',
    avoidFlags: {'dairy', 'nuts'},
    avoidIngredients: {'apple', 'cilantro'},
    requiredAttributes: {'halal'},
    maxTimeMinutes: 45,
    calorieTarget: 600,
    calorieTolerance: 100,
    preferredEffort: 'hard',
    showVariantTags: false,
    reduceMotion: true,
  );

  group('Profile JSON', () {
    test('round trips every field with the names of the spec', () {
      final json = full.toJson();
      expect(
        json.keys,
        containsAll([
          'name',
          'lang',
          'avoid_flags',
          'avoid_ingredients',
          'required_attributes',
          'max_time_minutes',
          'calorie_target',
          'preferred_effort',
          'show_variant_tags',
          'reduceMotion',
        ]),
      );
      expect(Profile.fromJson(jsonDecode(jsonEncode(json)) as Map<String, dynamic>), full);
    });

    test('an empty map gives the defaults', () {
      final profile = Profile.fromJson(const <String, dynamic>{});
      expect(profile, const Profile());
      expect(profile.preferredEffort, 'medium');
      expect(profile.calorieTolerance, Profile.defaultCalorieTolerance);
      expect(profile.hasCalorieTarget, isFalse);
      expect(profile.reduceMotion, isNull, reason: 'follow the system setting');
    });

    test('sets are written sorted, so a backup of the same profile is identical', () {
      expect(const Profile(avoidFlags: {'nuts', 'dairy', 'egg'}).toJson()['avoid_flags'], ['dairy', 'egg', 'nuts']);
    });

    test('reduceMotion reads both spellings', () {
      expect(Profile.fromJson(const {'reduceMotion': true}).reduceMotion, isTrue);
      expect(Profile.fromJson(const {'reduce_motion': false}).reduceMotion, isFalse);
    });

    test('copyWith can clear the nullable limits', () {
      final cleared = full.copyWith(maxTimeMinutes: null, calorieTarget: null, reduceMotion: null);
      expect(cleared.maxTimeMinutes, isNull);
      expect(cleared.calorieTarget, isNull);
      expect(cleared.reduceMotion, isNull);
      expect(full.copyWith(name: 'Alex').maxTimeMinutes, 45, reason: 'untouched fields stay');
    });
  });

  group('the reserved B2B block', () {
    const licensed = {
      'organization': 'acme-health',
      'seat': {
        'cohort': 'q4',
        'entitlements': ['team-plans'],
      },
    };

    test('is absent for everybody who has none, in memory and in JSON', () {
      expect(const Profile().b2b, isNull);
      expect(const Profile().toJson().containsKey('b2b'), isFalse);
    });

    test('is kept as it is through JSON', () {
      final profile = full.copyWith(b2b: licensed);
      final json = jsonDecode(jsonEncode(profile.toJson())) as Map<String, dynamic>;
      expect(json['b2b'], licensed);
      expect(Profile.fromJson(json).b2b, licensed);
      expect(Profile.fromJson(json), profile);
    });

    test('survives changes to other fields and can be cleared', () {
      final profile = full.copyWith(b2b: licensed);
      expect(profile.copyWith(name: 'Alex').b2b, licensed);
      expect(profile.copyWith(b2b: null).b2b, isNull);
    });

    test('takes part in equality, deeply', () {
      final a = full.copyWith(
        b2b: {
          'seat': {'cohort': 'q4'},
        },
      );
      final b = full.copyWith(
        b2b: {
          'seat': {'cohort': 'q4'},
        },
      );
      final c = full.copyWith(
        b2b: {
          'seat': {'cohort': 'q1'},
        },
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a, isNot(full));
    });
  });
}
